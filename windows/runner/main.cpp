#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

// The app_links plugin (used internally by supabase_flutter) forwards a
// second-instance OAuth URL to the first running Flutter window.
#include "app_links/app_links_plugin_c_api.h"

#include "flutter_window.h"
#include "utils.h"

namespace {

// Register only in the current user's profile, without administrator access.
// The callback is delivered as a single, quoted command-line argument.
// MSIX deployments should additionally declare this protocol in the package
// manifest; this registration targets the unpackaged Flutter Windows runner.
// Compatible with app_links 6.x (and newer versions retaining SendAppLink).
// The convenience SendAppLinkToInstance() API was only added in v7.2.0,
// so it cannot be called with older plugin headers.
bool ForwardAuthLinkToExistingWindow(const wchar_t* command_line) {
  // Do not suppress ordinary launches or forward unrelated command lines.
  if (command_line == nullptr ||
      wcsstr(command_line, L"pohantoonai://auth-callback") == nullptr) {
    return false;
  }

  // Flutter's default Win32 window class and our exact runner window title.
  const HWND existing = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW",
                                    L"pohantoonai");
  if (existing == nullptr) {
    return false;
  }

  // app_links' Windows C API sends the OAuth callback to the first instance.
  // Never print the callback URI: it may contain a one-time auth code.
  SendAppLink(existing);
  if (IsIconic(existing)) {
    ShowWindow(existing, SW_RESTORE);
  }
  SetForegroundWindow(existing);
  return true;
}

void RegisterPohantoonAuthProtocol() {
  wchar_t exe_path[MAX_PATH] = {};
  DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    OutputDebugStringW(L"PohantoonAI: Cannot locate executable for OAuth protocol.\n");
    return;
  }

  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER,
                      L"Software\\Classes\\pohantoonai",
                      0, nullptr, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE |
                      KEY_CREATE_SUB_KEY, nullptr, &key,
                      nullptr) != ERROR_SUCCESS) {
    OutputDebugStringW(L"PohantoonAI: OAuth protocol registration failed.\n");
    return;
  }

  const std::wstring display = L"URL:Pohantoon AI Authentication";
  RegSetValueExW(key, nullptr, 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(display.c_str()),
                 static_cast<DWORD>((display.size() + 1) * sizeof(wchar_t)));

  const wchar_t empty[] = L"";
  RegSetValueExW(key, L"URL Protocol", 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(empty),
                 sizeof(empty));

  HKEY cmd_key = nullptr;
  if (RegCreateKeyExW(key, L"shell\\open\\command", 0, nullptr,
                      REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr,
                      &cmd_key, nullptr) == ERROR_SUCCESS) {
    const std::wstring command =
        L"\"" + std::wstring(exe_path) + L"\" \"%1\"";
    RegSetValueExW(cmd_key, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(command.c_str()),
                   static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(cmd_key);
  } else {
    OutputDebugStringW(L"PohantoonAI: OAuth command registration failed.\n");
  }
  RegCloseKey(key);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // When the browser calls pohantoonai://auth-callback, Windows starts a
  // second executable. Forward the OAuth link to the already running app.
  // supabase_flutter's app_links observer then exchanges the auth code.
  if (ForwardAuthLinkToExistingWindow(command_line)) {
    return EXIT_SUCCESS;
  }
  RegisterPohantoonAuthProtocol();

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
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"pohantoonai", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
