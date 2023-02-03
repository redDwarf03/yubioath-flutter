import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_util_platform_interface.dart';

/// An implementation of [PlatformUtilPlatform] that uses method channels.
class MethodChannelPlatformUtil extends PlatformUtilPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('platform_util');

  @override
  Future<bool?> canPlaceWindowTo(Map<String, dynamic> arguments) async {
    return await methodChannel.invokeMethod<bool>('canPlaceWindowTo', arguments);
  }
}
