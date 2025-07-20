#pragma comment(lib, "winhttp.lib")
#include "flutter_window.h"
#include <optional>
#include <winhttp.h>
#include <Windows.h>
#include <winbase.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"
#include <thread>

#define _CRT_SECURE_NO_WARNINGS

std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& mouseEvents = nullptr;

std::atomic<bool> mainThreadAlive(true);
std::atomic<std::chrono::steady_clock::time_point> lastHeartbeat(std::chrono::steady_clock::now());
std::thread* monitorThread = nullptr;

char* wideCharToMultiByte(wchar_t* pWCStrKey)
{
    size_t pSize = WideCharToMultiByte(CP_OEMCP, 0, pWCStrKey, wcslen(pWCStrKey), NULL, 0, NULL, NULL);
    char* pCStrKey = new char[pSize + 1];
    WideCharToMultiByte(CP_OEMCP, 0, pWCStrKey, wcslen(pWCStrKey), pCStrKey, pSize, NULL, NULL);
    pCStrKey[pSize] = '\0';
    GlobalFree(pWCStrKey);
    return pCStrKey;
}

char* getProxy() {
    _WINHTTP_CURRENT_USER_IE_PROXY_CONFIG net;
    WinHttpGetIEProxyConfigForCurrentUser(&net);
    if (net.lpszProxy == nullptr) {
        GlobalFree(net.lpszAutoConfigUrl);
        GlobalFree(net.lpszProxyBypass);
        return nullptr;
    }
    else {
        GlobalFree(net.lpszAutoConfigUrl);
        GlobalFree(net.lpszProxyBypass);
        return wideCharToMultiByte(net.lpszProxy);
    }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void monitorUIThread() {
    const auto timeout = std::chrono::seconds(5);

    while (mainThreadAlive.load()) {
        auto now = std::chrono::steady_clock::now();
        auto duration = now - lastHeartbeat.load();

        if (duration > timeout) {
            std::cerr << "The UI thread is dead. Terminate the application.";
            std::exit(0);
        }

        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  const flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(), "venera/method_channel",
      &flutter::StandardMethodCodec::GetInstance()
  );
  channel.SetMethodCallHandler(
    [](const flutter::MethodCall<>& call,const std::unique_ptr<flutter::MethodResult<>>& result) {
      if(call.method_name() == "getProxy"){
        const auto res = getProxy();
        if (res != nullptr){
          std::string s = res;
          result->Success(s);
          }
        else
          result->Success(flutter::EncodableValue("No Proxy"));
        delete(res);
        return;
      }
#ifdef NDEBUG
      else if (call.method_name() == "heartBeat") {

          if (monitorThread == nullptr) {
              monitorThread = new std::thread{ monitorUIThread };
          }
          lastHeartbeat = std::chrono::steady_clock::now();
          result->Success();
          return;
      }
#endif
      result->Success(); // Default response for unhandled method calls
  });

  flutter::EventChannel<> channel2(
    flutter_controller_->engine()->messenger(), "venera/mouse",
    &flutter::StandardMethodCodec::GetInstance()
  );

  auto eventHandler = std::make_unique<
    flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
    [](
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events){
        mouseEvents = std::move(events);
        return nullptr;
    },
    [](const flutter::EncodableValue* arguments)
      -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        mouseEvents = nullptr;
        return nullptr;
    }
  );

  channel2.SetStreamHandler(std::move(eventHandler));

  const flutter::MethodChannel<> channel3(
    flutter_controller_->engine()->messenger(), "venera/clipboard",
    &flutter::StandardMethodCodec::GetInstance()
  );
  channel3.SetMethodCallHandler(
    [](const flutter::MethodCall<>& call,const std::unique_ptr<flutter::MethodResult<>>& result) {
      if(call.method_name() == "writeImageToClipboard"){
          flutter::EncodableMap arguments = std::get<flutter::EncodableMap>(*call.arguments());
          std::vector<uint8_t> data = std::get<std::vector<uint8_t>>(arguments["data"]);
          std::int32_t width = std::get<std::int32_t>(arguments["width"]);
          std::int32_t height = std::get<std::int32_t>(arguments["height"]);

          // convert rgba to bgra
          for (int i = 0; i < data.size()/4; i++) {
              uint8_t temp = data[i * 4];
              data[i * 4] = data[i * 4 + 2];
              data[i * 4 + 2] = temp;
          }
          
          auto bitmap = CreateBitmap((int)width, (int)height, 1, 32, data.data());

          if (!bitmap) {
              result->Error("0", "Invalid Image Data");
              return;
          }

          if (OpenClipboard(NULL))
          {
              EmptyClipboard();
              SetClipboardData(CF_BITMAP, bitmap);
              CloseClipboard();
              result->Success();
          }
          else {
              result->Error("Failed to open clipboard");
          }

          DeleteObject(bitmap);
      }
  });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
  if (monitorThread != nullptr) {
      mainThreadAlive = false;
      monitorThread->join();
  }
}

void mouse_side_button_listener(unsigned int input)
{
    if(mouseEvents != nullptr)
    {
        mouseEvents->Success(static_cast<int>(input));
    }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
    UINT button = GET_XBUTTON_WPARAM(wparam);
    if (button == XBUTTON1 && message == 528)
    {
        mouse_side_button_listener(0);
    }
    else if (button == XBUTTON2 && message == 528)
    {
        mouse_side_button_listener(1);
    }
    if (flutter_controller_) {
        std::optional<LRESULT> result =
            flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
        if (result) {
          return *result;
        }
    }

    switch (message) {
      case WM_FONTCHANGE:
          flutter_controller_->engine()->ReloadSystemFonts();
          break;
    }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
