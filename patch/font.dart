import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';

void main() async {
  const harmonySansLink = "https://developer.huawei.com/images/download/general/HarmonyOS-Sans.zip";

  var dio = Dio();
  await dio.download(harmonySansLink, "HarmonyOS-Sans.zip");
  await extractFileToDisk("HarmonyOS-Sans.zip", "./assets/");
  File("HarmonyOS-Sans.zip").deleteSync();

  var pubspec = await File("pubspec.yaml").readAsString();
  pubspec = pubspec.replaceFirst("# fonts:",
"""  fonts:
  - family: HarmonyOS Sans
    fonts:
      - asset: assets/HarmonyOS Sans/HarmonyOS_Sans_SC/HarmonyOS_Sans_SC_Regular.ttf
""");
  await File("pubspec.yaml").writeAsString(pubspec);

  var mainDart = await File("lib/main.dart").readAsString();
  mainDart = mainDart.replaceFirst("Noto Sans CJK", "HarmonyOS Sans");
  await File("lib/main.dart").writeAsString(mainDart);

  print("Successfully patched font.");
}