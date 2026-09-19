import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Descobre se o app está rodando em uma Android TV.
class DeviceMode {
  DeviceMode._();

  static bool? _ehTv;

  static Future<bool> ehAndroidTv() async {
    final salvo = _ehTv;
    if (salvo != null) return salvo;

    var resultado = false;
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final recursos = info.systemFeatures;
        resultado = recursos.contains('android.software.leanback') ||
            recursos.contains('android.hardware.type.television');
      }
    } catch (_) {
      resultado = false;
    }
    _ehTv = resultado;
    return resultado;
  }
}
