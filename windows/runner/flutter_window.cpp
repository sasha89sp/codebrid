#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr wchar_t kWindowChannelName[] = L"codebridge/window_controls";
constexpr int kTitleBarHeightPx = 38;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() = default;

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;

  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    LONG style = ::GetWindowLongW(hwnd, GWL_STYLE);
    style &= ~WS_CAPTION;
    style |= (WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    ::SetWindowLongW(hwnd, GWL_STYLE, style);
    ::SetWindowPos(
        hwnd, nullptr, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) return false;

  RegisterPlugins(flutter_controller_->engine());

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "codebridge/window_controls",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (hwnd == nullptr) {
          result->Success(flutter::EncodableValue(false));
          return;
        }
        const std::string& method = call.method_name();
        if (method == "minimize") {
          ::ShowWindow(hwnd, SW_MINIMIZE);
          result->Success(flutter::EncodableValue(true));
        } else if (method == "toggleMaximize") {
          WINDOWPLACEMENT wp{};
          wp.length = sizeof(WINDOWPLACEMENT);
          if (::GetWindowPlacement(hwnd, &wp) && wp.showCmd == SW_MAXIMIZE) {
            ::ShowWindow(hwnd, SW_RESTORE);
          } else {
            ::ShowWindow(hwnd, SW_MAXIMIZE);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "isMaximized") {
          WINDOWPLACEMENT wp{};
          wp.length = sizeof(WINDOWPLACEMENT);
          bool maximized = false;
          if (::GetWindowPlacement(hwnd, &wp)) {
            maximized = (wp.showCmd == SW_MAXIMIZE);
          }
          result->Success(flutter::EncodableValue(maximized));
        } else if (method == "close") {
          ::PostMessageW(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
          result->Success(flutter::EncodableValue(true));
        } else if (method == "startDrag") {
          ::ReleaseCapture();
          ::SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND window, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCALCSIZE && wparam == TRUE) {
    // Allow full client area without standard Windows non-client title bar while keeping resize borders.
    return 0;
  }

  if (message == WM_NCHITTEST) {
    POINT pt{
        static_cast<SHORT>(LOWORD(lparam)),
        static_cast<SHORT>(HIWORD(lparam)),
    };
    ::ScreenToClient(window, &pt);

    RECT client_rect{};
    ::GetClientRect(window, &client_rect);
    const int border_x = ::GetSystemMetrics(SM_CXSIZEFRAME) +
                         ::GetSystemMetrics(SM_CXPADDEDBORDER);
    const int border_y = ::GetSystemMetrics(SM_CYSIZEFRAME) +
                         ::GetSystemMetrics(SM_CXPADDEDBORDER);

    const bool left = pt.x < border_x;
    const bool right = pt.x >= (client_rect.right - border_x);
    const bool top = pt.y < border_y;
    const bool bottom = pt.y >= (client_rect.bottom - border_y);

    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(window, message, wparam, lparam);
    if (result) return *result;
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }
  return Win32Window::MessageHandler(window, message, wparam, lparam);
}
