#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <fstream>
#include <chrono>
#include <ctime>

#include "flutter_window.h"
#include "utils.h"

static void MainDebugLog(const char* msg) {
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
    ofs << timeBuf << " [MAIN] " << msg << "\n";
  } catch (...) {}
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  MainDebugLog("wWinMain START");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Fixed-size window: full work area height (screen minus taskbar),
  // phone-like aspect ratio.
  RECT workArea;
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);
  int workW = workArea.right - workArea.left;
  int workH = workArea.bottom - workArea.top;
  int winH = workH;
  int winW = static_cast<int>(winH * 0.55);
  if (winW < 360) winW = 360;
  if (winW > 560) winW = 560;
  int left = workArea.left + (workW - winW) / 2;
  int top = workArea.top + (workH - winH) / 2;
  MainDebugLog("Fixed size window computed");

  Win32Window::Point origin(left, top);
  Win32Window::Size size(winW, winH);
  if (!window.Create(L"teapodstream", origin, size)) {
    MainDebugLog("window.Create FAILED");
    return EXIT_FAILURE;
  }

  // Remove resize border and maximize button
  HWND hwnd = window.GetHandle();
  if (hwnd) {
    LONG_PTR style = ::GetWindowLongPtrW(hwnd, GWL_STYLE);
    style &= ~WS_THICKFRAME & ~WS_MAXIMIZEBOX;
    ::SetWindowLongPtrW(hwnd, GWL_STYLE, style);
    ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
  }

  MainDebugLog("window.Create OK - calling SetQuitOnClose(true)");
  window.SetQuitOnClose(true);

  MainDebugLog("Entering message loop");
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  MainDebugLog("Message loop exited — CoUninitialize");
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
