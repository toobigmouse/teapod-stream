/// On Windows, we detect the window close via the GLFW close callback
/// in the C++ runner (win32_window.cpp). When close is requested,
/// the runner calls back into Dart via a MethodChannel, and we decide
/// whether to hide to tray or actually close.
///
/// For now, this is a no-op placeholder — the actual interception
/// happens through AppWindow.hide() in TrayManager.
void initCloseInterceptor({required bool Function() onCloseRequested}) {
  // No-op: close interception handled via AppWindow.hide() in TrayManager
}

void disposeCloseInterceptor() {}
