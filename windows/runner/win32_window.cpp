#include "win32_window.h"

#include <algorithm>

Win32Window::Win32Window() = default;
Win32Window::~Win32Window() = default;

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                         const Size& size) {
  if (!RegisterWindowClass()) return false;

  RECT window_rect = {static_cast<LONG>(origin.x), static_cast<LONG>(origin.y),
                      static_cast<LONG>(origin.x + size.width),
                      static_cast<LONG>(origin.y + size.height)};
  ::AdjustWindowRect(&window_rect, WS_OVERLAPPEDWINDOW, FALSE);

  window_handle_ = ::CreateWindowW(
      kWindowClassName, title.c_str(), WS_OVERLAPPEDWINDOW,
      window_rect.left, window_rect.top,
      window_rect.right - window_rect.left,
      window_rect.bottom - window_rect.top,
      nullptr, nullptr, ::GetModuleHandle(nullptr), this);

  if (!window_handle_) return false;
  if (!OnCreate()) return false;
  ::ShowWindow(window_handle_, SW_SHOWNORMAL);
  ::UpdateWindow(window_handle_);
  return true;
}

bool Win32Window::Show() {
  return ::ShowWindow(window_handle_, SW_SHOWNORMAL) != 0;
}

HWND Win32Window::GetHandle() { return window_handle_; }

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() { return true; }
void Win32Window::OnDestroy() {}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  ::SetParent(content, window_handle_);
  RECT frame = GetClientArea();
  ::MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
               frame.bottom - frame.top, TRUE);
  ::SetFocus(content);
}

RECT Win32Window::GetClientArea() {
  RECT client_area;
  ::GetClientRect(window_handle_, &client_area);
  return client_area;
}

bool Win32Window::RegisterWindowClass() {
  WNDCLASSW window_class{};
  window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kWindowClassName;
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = Win32Window::WndProc;
  window_class.hInstance = ::GetModuleHandle(nullptr);
  return ::RegisterClassW(&window_class) != 0 || ::GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    auto* that = static_cast<Win32Window*>(create_struct->lpCreateParams);
    ::SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(that));
    that->window_handle_ = window;
  }
  auto* that = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(window, GWLP_USERDATA));
  if (that) return that->HandleMessage(window, message, wparam, lparam);
  return ::DefWindowProc(window, message, wparam, lparam);
}

LRESULT Win32Window::HandleMessage(HWND const window, UINT const message,
                                   WPARAM const wparam,
                                   LPARAM const lparam) noexcept {
  switch (message) {
    case WM_SIZE:
      if (child_content_) {
        RECT frame = GetClientArea();
        ::MoveWindow(child_content_, frame.left, frame.top,
                     frame.right - frame.left, frame.bottom - frame.top, TRUE);
      }
      return 0;
    case WM_DESTROY:
      OnDestroy();
      if (quit_on_close_) ::PostQuitMessage(0);
      return 0;
  }
  return MessageHandler(window, message, wparam, lparam);
}

LRESULT Win32Window::MessageHandler(HWND const window, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  return ::DefWindowProc(window, message, wparam, lparam);
}
