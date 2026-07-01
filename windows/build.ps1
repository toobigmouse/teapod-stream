<#
.SYNOPSIS
    TeapodStream Windows MSIX build script.

.DESCRIPTION
    Builds Flutter Windows release, creates MSIX package, signs it.
    Supports x64 and arm64 architectures.

.PARAMETER Architecture
    Target architecture: x64 or arm64. Default: x64

.PARAMETER SkipBuild
    Skip Flutter build step (use existing build output).

.PARAMETER SkipSign
    Skip code signing step.

.PARAMETER CertificatePath
    Path to PFX certificate file. If not provided, generates self-signed certificate.

.PARAMETER CertificatePassword
    Password for the PFX file. Required if CertificatePath is provided.

.PARAMETER OutputDir
    Output directory for MSIX file. Default: build\msix

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Architecture arm64
    .\build.ps1 -CertificatePath "cert.pfx" -CertificatePassword "password"
#>

param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [switch]$SkipBuild,
    [switch]$SkipSign,

    [string]$CertificatePath = "",
    [string]$CertificatePassword = "",

    [string]$OutputDir = "build\msix"
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AppName = "TeapodStream"
$Publisher = "CN=TeapodStream"
$PackagingDir = Join-Path $PSScriptRoot "packaging"
$ImagesDir = Join-Path $PackagingDir "images"
$AppxManifest = Join-Path $PackagingDir "AppxManifest.xml"
$BuildDir = Join-Path $ProjectRoot "build\windows\$Architecture\runner\Release"
$MsixOutput = Join-Path $ProjectRoot $OutputDir

# --- Helper Functions ---
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "    [FAIL] $Message" -ForegroundColor Red
    exit 1
}

function Get-ProjectVersion {
    $pubspec = Get-Content (Join-Path $ProjectRoot "pubspec.yaml") -Raw
    if ($pubspec -match 'version:\s+(\d+\.\d+\.\d+)\+(\d+)') {
        $Version = $Matches[1]
        $BuildNumber = $Matches[2]
        return @{ Version = $Version; BuildNumber = $BuildNumber }
    }
    Write-Fail "Could not parse version from pubspec.yaml"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Convert-IcoToPng {
    param(
        [string]$IcoPath,
        [string]$PngPath,
        [int]$Size
    )

    # Use Python/Pillow for reliable ICO to PNG conversion
    $pythonScript = @"
from PIL import Image
import sys

ico_path = r'$IcoPath'
png_path = r'$PngPath'
size = $Size

icon = Image.open(ico_path)
resized = icon.resize((size, size), Image.Resampling.LANCZOS)
if resized.mode != 'RGBA':
    resized = resized.convert('RGBA')
resized.save(png_path)
"@

    $pythonScript | python -
    if ($LASTEXITCODE -ne 0) {
        throw "Python/Pillow icon generation failed"
    }
}

# --- Main Script ---
Write-Host "============================================" -ForegroundColor White
Write-Host "  TeapodStream MSIX Builder" -ForegroundColor White
Write-Host "  Architecture: $Architecture" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White

# Step 1: Get version
Write-Step "Reading version from pubspec.yaml..."
$versionInfo = Get-ProjectVersion
$Version = $versionInfo.Version
$BuildNumber = $versionInfo.BuildNumber
# Convert x.y.z to x.y.z.0 for MSIX (4-part version required)
$MsixVersion = "$Version.0"
Write-Success "Version: $Version (build $BuildNumber, MSIX: $MsixVersion)"

# Step 2: Generate icons if missing
Write-Step "Checking MSIX icons..."
Ensure-Directory $ImagesDir

$icoPath = Join-Path $ProjectRoot "windows\runner\resources\app_icon.ico"
if (-not (Test-Path $icoPath)) {
    Write-Fail "app_icon.ico not found at: $icoPath"
}

$requiredIcons = @(
    @{ Name = "Square44x44Logo.png"; Size = 44 },
    @{ Name = "Square71x71Logo.png"; Size = 71 },
    @{ Name = "Square150x150Logo.png"; Size = 150 },
    @{ Name = "Square310x310Logo.png"; Size = 310 },
    @{ Name = "Square310x310Logo.targetsize-240_scale-100.png"; Size = 310 },
    @{ Name = "StoreLogo.png"; Size = 50 },
    @{ Name = "Wide310x150Logo.png"; Size = 310 },
    @{ Name = "SplashScreen.png"; Size = 620 }
)

$iconsGenerated = 0
foreach ($icon in $requiredIcons) {
    $pngPath = Join-Path $ImagesDir $icon.Name
    if (-not (Test-Path $pngPath)) {
        Write-Host "    Generating $($icon.Name) ($($icon.Size)x$($icon.Size))..."
        try {
            # For splash screen, use wider aspect ratio
            if ($icon.Name -eq "SplashScreen.png") {
                Convert-IcoToPng -IcoPath $icoPath -PngPath $pngPath -Size $icon.Size
            } else {
                Convert-IcoToPng -IcoPath $icoPath -PngPath $pngPath -Size $icon.Size
            }
            $iconsGenerated++
        } catch {
            Write-Warn "Could not generate $($icon.Name): $($_.Exception.Message)"
        }
    } else {
        Write-Host "    $($icon.Name) already exists"
    }
}

if ($iconsGenerated -gt 0) {
    Write-Success "Generated $iconsGenerated icons"
} else {
    Write-Success "All icons already present"
}

# Step 3: Flutter build
if (-not $SkipBuild) {
    Write-Step "Building Flutter Windows release ($Architecture)..."

    $flutterArgs = @(
        "build", "windows", "--release",
        "--target-platform", "windows-$Architecture"
    )

    Push-Location $ProjectRoot
    try {
        & flutter @flutterArgs
        if ($LASTEXITCODE -ne 0) { Write-Fail "Flutter build failed" }
    } finally {
        Pop-Location
    }
    Write-Success "Flutter build completed"
} else {
    Write-Step "Skipping Flutter build (--SkipBuild)"
    if (-not (Test-Path $BuildDir)) {
        Write-Fail "Build directory not found: $BuildDir"
    }
}

# Step 4: Update AppxManifest version
Write-Step "Updating AppxManifest.xml version..."
$manifestContent = Get-Content $AppxManifest -Raw
$manifestContent = $manifestContent -replace '(<Identity[^>]*Version=")[\d.]+(")', "`${1}$MsixVersion`${2}"
Set-Content -Path $AppxManifest -Value $manifestContent -Encoding UTF8
Write-Success "Version set to $MsixVersion in AppxManifest.xml"

# Step 5: Ensure output directory
Ensure-Directory $MsixOutput

# Step 6: Create MSIX
Write-Step "Creating MSIX package..."

$msixFile = Join-Path $MsixOutput "$AppName-$Architecture-$Version.msix"

# Create temporary staging directory
$stagingDir = Join-Path $MsixOutput "staging_$Architecture"
Ensure-Directory $stagingDir

# Copy build output to staging
Write-Host "    Copying build files to staging..."
Copy-Item -Path "$BuildDir\*" -Destination $stagingDir -Recurse -Force

# Copy AppxManifest.xml to staging
Copy-Item -Path $AppxManifest -Destination $stagingDir -Force

# Create images directory in staging
$stagingImages = Join-Path $stagingDir "images"
Ensure-Directory $stagingImages
Copy-Item -Path "$ImagesDir\*" -Destination $stagingImages -Recurse -Force

# Create MSIX using makeappx
$makeappx = "MakeAppx.exe"
$makeappxPath = $null

# Try Windows SDK paths
$sdkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64",
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64",
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22061.0\x64",
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64",
    "${env:ProgramFiles}\Windows Kits\10\bin\10.0.26100.0\x64",
    "${env:ProgramFiles}\Windows Kits\10\bin\10.0.22621.0\x64",
    "${env:ProgramFiles}\Windows Kits\10\bin\10.0.22061.0\x64",
    "${env:ProgramFiles}\Windows Kits\10\bin\10.0.19041.0\x64"
)

foreach ($path in $sdkPaths) {
    $testPath = Join-Path $path $makeappx
    if (Test-Path $testPath) {
        $makeappxPath = $testPath
        break
    }
}

if (-not $makeappxPath) {
    # Try PATH
    $makeappxPath = (Get-Command $makeappx -ErrorAction SilentlyContinue).Source
}

if (-not $makeappxPath) {
    Write-Fail @"
MakeAppx.exe not found. Install Windows SDK:
  https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

Or add MakeAppx.exe to PATH.
"@
}

Write-Host "    Using MakeAppx: $makeappxPath"
& "$makeappxPath" pack /d $stagingDir /p $msixFile /o
if ($LASTEXITCODE -ne 0) { Write-Fail "MakeAppx pack failed" }
Write-Success "MSIX created: $msixFile"

# Step 7: Sign MSIX
if (-not $SkipSign) {
    Write-Step "Signing MSIX package..."

    $signtool = "SignTool.exe"
    $signtoolPath = $null

    foreach ($path in $sdkPaths) {
        $testPath = Join-Path $path $signtool
        if (Test-Path $testPath) {
            $signtoolPath = $testPath
            break
        }
    }

    if (-not $signtoolPath) {
        $signtoolPath = (Get-Command $signtool -ErrorAction SilentlyContinue).Source
    }

    if (-not $signtoolPath) {
        Write-Warn "SignTool.exe not found. Skipping signing."
    } else {
        $certPath = $CertificatePath
        $certPass = $CertificatePassword

        # Generate self-signed certificate if not provided
        if (-not $certPath) {
            Write-Host "    Generating self-signed certificate..."
            $selfCert = New-SelfSignedCertificate `
                -Type CodeSigningCert `
                -Subject $Publisher `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -NotAfter (Get-Date).AddYears(5) `
                -FriendlyName "TeapodStream Code Signing"

            $certThumbprint = $selfCert.Thumbprint
            Write-Success "Certificate created: $certThumbprint"

            # Export to temp PFX
            $certPath = Join-Path $MsixOutput "teapodstream_dev.pfx"
            $certPassword = ConvertTo-SecureString -String "teapodstream" -Force -AsPlainText
            Export-PfxCertificate `
                -Cert "Cert:\CurrentUser\My\$certThumbprint" `
                -FilePath $certPath `
                -Password $certPassword | Out-Null

            Write-Success "Certificate exported: $certPath"
            $certPass = "teapodstream"
        }

        # Sign the MSIX
        Write-Host "    Signing with SignTool..."
        if ($certPass) {
            $securePass = ConvertTo-SecureString -String $certPass -Force -AsPlainText
            & $signtoolPath sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
                /f $certPath /p $certPass $msixFile
        } else {
            & $signtoolPath sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
                /f $certPath $msixFile
        }

        if ($LASTEXITCODE -ne 0) { Write-Fail "SignTool sign failed" }
        Write-Success "MSIX signed successfully"
    }
} else {
    Write-Step "Skipping signing (--SkipSign)"
}

# Step 8: Cleanup staging
Write-Step "Cleaning up staging directory..."
Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Success "Cleanup completed"

# Summary
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Architecture: $Architecture"
Write-Host "  Version:      $Version (build $BuildNumber)"
Write-Host "  Output:       $msixFile"
Write-Host "  Installer:    .appinstaller (see below)"
Write-Host "============================================" -ForegroundColor Green

# Step 9: Generate .appinstaller
Write-Step "Generating .appinstaller XML..."

$appInstallerXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<AppInstaller
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  Version="$MsixVersion">

  <UpdateSettings>
    <OnLaunch HoursBetweenUpdateChecks="4" />
    <AutomaticBackgroundTask />
    <ForceApplicationShutdown>false</ForceApplicationShutdown>
  </UpdateSettings>

  <MainBundle
    Name="TeapodStream"
    Publisher="CN=TeapodStream"
    Uri="https://github.com/YOUR_ORG/teapod-stream/releases/download/v$Version/TeapodStream-$Architecture-$Version.msix" />

</AppInstaller>
"@

$appInstallerPath = Join-Path $MsixOutput "TeapodStream-$Architecture.appinstaller"
Set-Content -Path $appInstallerPath -Value $appInstallerXml -Encoding UTF8
Write-Success "AppInstaller: $appInstallerPath"

Write-Host "`n  NOTE: Update the URI in .appinstaller to your actual release URL." -ForegroundColor Yellow
Write-Host "  Install: Double-click the .msix file" -ForegroundColor White
Write-Host "  Auto-update: Place .appinstaller on a web server" -ForegroundColor White
