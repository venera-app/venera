import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';

Future<void> writeImageToClipboard(Uint8List imageBytes) async {
  const channel = MethodChannel("venera/clipboard");
  if (Platform.isWindows) {
    var image = await instantiateImageCodec(imageBytes);
    var frame = await image.getNextFrame();
    var data = await frame.image.toByteData(format: ImageByteFormat.rawRgba);
    await channel.invokeMethod("writeImageToClipboard", {
      "width": frame.image.width,
      "height": frame.image.height,
      "data": Uint8List.view(data!.buffer)
    });
    image.dispose();
  } else {
    // TODO: Implement for other platforms
    throw UnsupportedError("Clipboard image is not supported on this platform");
  }
}
