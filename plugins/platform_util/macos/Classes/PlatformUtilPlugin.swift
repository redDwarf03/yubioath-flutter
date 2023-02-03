import Cocoa
import FlutterMacOS

public class PlatformUtilPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "platform_util", binaryMessenger: registrar.messenger)
        let instance = PlatformUtilPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args: [String: Any] = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "canPlaceWindowTo":
            result(canPlaceWindowTo(args))
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func canPlaceWindowTo(_ args: [String: Any]) -> Bool {
        let x = CGFloat(truncating: args["x"] as? NSNumber ?? 0)
        let y = CGFloat(truncating: args["y"] as? NSNumber ?? 0)
        let width = CGFloat(truncating: args["width"] as? NSNumber ?? 0)
        let height = CGFloat(truncating: args["height"] as? NSNumber ?? 0)
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let maxDisplays : UInt32 = 5
        var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(maxDisplays))
        var matchingDisplayCount : UInt32 = 0
        return (CGError.success == CGGetDisplaysWithRect(rect, maxDisplays, &displays, &matchingDisplayCount)) && (matchingDisplayCount > 0)
    }
}
