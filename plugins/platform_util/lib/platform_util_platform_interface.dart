import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'platform_util_method_channel.dart';

abstract class PlatformUtilPlatform extends PlatformInterface {
  /// Constructs a PlatformUtilPlatform.
  PlatformUtilPlatform() : super(token: _token);

  static final Object _token = Object();

  static PlatformUtilPlatform _instance = MethodChannelPlatformUtil();

  /// The default instance of [PlatformUtilPlatform] to use.
  ///
  /// Defaults to [MethodChannelPlatformUtil].
  static PlatformUtilPlatform get instance => _instance;

  static set instance(PlatformUtilPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool?> canPlaceWindowTo(Map<String, dynamic> arguments) {
    throw UnimplementedError('canPlaceWindowTo() has not been implemented.');
  }
}
