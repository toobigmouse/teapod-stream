#include "flutter_window.h"

#include <optional>
#include <fstream>
#include <chrono>
#include <ctime>

#include "flutter/generated_plugin_registrant.h"

// Debug log helper — writes to <exe_dir>/logs/debug.log
static void FlutterDebugLog(const char* msg) {
  try {
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring ws(exePath);
    size_t pos = ws.find_last_of(L"\\/");
    std::wstring dir = (pos != std::wstring::npos) ? ws.substr(0, pos) : L".";
    std::wstring logPath = dir + L"\\logs\\debug.log";

    auto now = std::chrono::system_clock::now();
    auto t = std::chrono::system_clock::to_time_t(now);
    char timeBuf[64];
    struct tm tmBuf;
    localtime_s(&tmBuf, &t);
    strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%dT%H:%M:%S", &tmBuf);

    std::ofstream ofs(logPath, std::ios::app);
    ofs << timeBuf << " [FLUTTER_WIN] " << msg << "\n";
  } catch (...) {}
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  FlutterDebugLog("FlutterWindow::OnCreate() START");
  if (!Win32Window::OnCreate()) {
    FlutterDebugLog("FlutterWindow::OnCreate() Win32Window::OnCreate() FAILED");
    return false;
  }

  RECT frame = GetClientArea();
  char buf[128];
  sprintf_s(buf, sizeof(buf), "FlutterWindow::OnCreate() frame=%ldx%ld", frame.right, frame.bottom);
  FlutterDebugLog(buf);

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    FlutterDebugLog("FlutterWindow::OnCreate() FlutterViewController FAILED");
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    FlutterDebugLog("First frame callback -- calling Show()");
    this->Show();
    HWND hwnd = this->GetHandle();
    HWND childHwnd = flutter_controller_->view()->GetNativeWindow();
    if (hwnd) {
      SetForegroundWindow(hwnd);
      if (childHwnd) {
        SetFocus(childHwnd);
      }
      FlutterDebugLog("Show + SetForegroundWindow + SetFocus done");
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  FlutterDebugLog("FlutterWindow::OnCreate() END");
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                               WPARAM const wparam,
                               LPARAM const lparam) noexcept {
  // Log interesting messages
  if (message == WM_CLOSE || message == WM_DESTROY || message == WM_QUIT ||
      message == WM_APP + 1 || message == WM_APP + 2 ||
      message == WM_ACTIVATE || message == WM_SETFOCUS) {
    char buf[128];
    sprintf_s(buf, sizeof(buf), "FlutterWindow::MessageHandler msg=0x%04X wp=%llu lp=%llu",
            message, (unsigned long long)wparam, (unsigned long long)lparam);
    FlutterDebugLog(buf);
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                       lparam);
    if (result) {
      if (message == WM_CLOSE) {
        char buf[128];
        sprintf_s(buf, sizeof(buf), "FLUTTER consumed WM_CLOSE! result=%lld - our C++ handler NEVER runs!",
                (long long)*result);
        FlutterDebugLog(buf);
      }
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_APP + 1: {
      // Custom message from Dart to set hide-on-close flag.
      // wparam: 0 = exit on close, 1 = hide on close
      char buf[128];
      sprintf_s(buf, sizeof(buf), "WM_APP+1 received: wparam=%llu -> calling SetHideOnClose(%d)",
              (unsigned long long)wparam, (int)(wparam == 1));
      FlutterDebugLog(buf);
      SetHideOnClose(wparam == 1);
      return 0;
    }

    case WM_APP + 2: {
      // Custom message from Dart to force close (tray "Exit").
      FlutterDebugLog("WM_APP+2 received → calling SetForceClose()");
      SetForceClose();
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
