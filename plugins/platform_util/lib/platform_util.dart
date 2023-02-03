
import 'platform_util_platform_interface.dart';

class PlatformUtil {

  Future<bool?> canPlaceWindowTo(double? x, double? y, double? width, double? height) async {
    final Map<String, dynamic> arguments = {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    }..removeWhere((key, value) => value == null);

    return PlatformUtilPlatform.instance.canPlaceWindowTo(arguments);
  }
}

final platformUtil = PlatformUtil();