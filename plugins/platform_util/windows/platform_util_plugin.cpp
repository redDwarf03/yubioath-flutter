#include "platform_util_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <io.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>


namespace platform_util {
	namespace {

		template <typename T, typename U>
		T GetValueOrDefault(const flutter::EncodableMap& arguments, U&& property_name, T&& default) noexcept {
			auto i = arguments.find(flutter::EncodableValue(std::forward<U>(property_name)));
			if (i != arguments.end() && std::holds_alternative<T>(i->second)) {
				return std::get<T>(i->second);
			}

			return default;
		}

		RECT GetRectFromArgs(const flutter::EncodableMap& args) {
			auto x = GetValueOrDefault<double>(args, "x", 0.0);
			auto y = GetValueOrDefault<double>(args, "y", 0.0);
			auto width = GetValueOrDefault<double>(args, "width", 0.0);
			auto height = GetValueOrDefault<double>(args, "height", 0.0);
			return { (long)x, (long)y, (long)x + (long)width, (long)y + (long)height };
		}


		flutter::EncodableMap EncodeRect(const RECT& r) {
			using flutter::EncodableMap;
			using flutter::EncodableValue;

			auto doubleEncodable = [](int i) { return EncodableValue(static_cast<double>(i)); };
			auto stringEncodable = [](std::string_view sv) { return EncodableValue(std::string(sv)); };

			EncodableMap encoded;
			encoded[stringEncodable("left")] = doubleEncodable(r.left);
			encoded[stringEncodable("top")] = doubleEncodable(r.top);
			encoded[stringEncodable("width")] = doubleEncodable(r.right - r.left);
			encoded[stringEncodable("height")] = doubleEncodable(r.bottom - r.top);
			return encoded;
		}

		flutter::EncodableMap GetWindowBoundingRect(HWND window) {
			RECT windowRect;
			if (0 != GetWindowRect(window, &windowRect)) {
				return EncodeRect(windowRect);
			}
			return {};
		}

		bool SetWindowRect(HWND window, const flutter::EncodableMap& args) {
			RECT rect{ GetRectFromArgs(args) };
			
			SetWindowPos(
				window,
				HWND_TOP,
				rect.left,
				rect.top,
				rect.right - rect.left,
				rect.bottom - rect.top,
				SWP_NOSENDCHANGING);

			
			// find best position for the window if it is off screen
			HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONULL);
			if (monitor == nullptr) {
				// the window was missplaced
				// place it on nearest monitor
				monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
				if (monitor == nullptr) {
					// there should be a primary monitor
					monitor = MonitorFromWindow(window, MONITOR_DEFAULTTOPRIMARY);
				}

				// place the window to top-left corner
				MONITORINFO monitorInfo;
				monitorInfo.cbSize = sizeof(MONITORINFO);
				GetMonitorInfo(monitor, &monitorInfo);
				SetWindowPos(
					window,
					HWND_TOP,
					monitorInfo.rcMonitor.left,
					monitorInfo.rcMonitor.top,
					rect.right - rect.left,
					rect.bottom - rect.top,
					SWP_NOSENDCHANGING);
			}
			return true;
		}

	} // namespace

	// static
	void PlatformUtilPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		auto channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), "platform_util",
				&flutter::StandardMethodCodec::GetInstance());

		auto plugin = std::make_unique<PlatformUtilPlugin>(registrar);

		channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
			plugin_pointer->HandleMethodCall(call, std::move(result));
		});

		registrar->AddPlugin(std::move(plugin));
	}

	PlatformUtilPlugin::PlatformUtilPlugin(flutter::PluginRegistrarWindows* registrar) 
	: registrar(registrar)
	, native_window() {}

	PlatformUtilPlugin::~PlatformUtilPlugin() {}

	void PlatformUtilPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		const flutter::EncodableMap& args = std::get<flutter::EncodableMap>(*method_call.arguments());
		if (method_call.method_name().compare("init") == 0) {
			native_window = ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
			result->Success(true);
		} else if (method_call.method_name().compare("getWindowRect") == 0) {
			result->Success(flutter::EncodableValue(GetWindowBoundingRect(native_window)));
		} else if (method_call.method_name().compare("setWindowRect") == 0) {
			result->Success(flutter::EncodableValue(SetWindowRect(native_window, args)));
		} else {
			result->NotImplemented();
		}
	}
}  // namespace platform_util
