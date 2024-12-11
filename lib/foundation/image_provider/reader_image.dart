import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'reader_image.dart' as image_provider;

class ReaderImageProvider
    extends BaseImageProvider<image_provider.ReaderImageProvider> {
  /// Image provider for normal image.
  const ReaderImageProvider(this.imageKey, this.sourceKey, this.cid, this.eid);

  final String imageKey;

  final String? sourceKey;

  final String cid;

  final String eid;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    if (imageKey.startsWith('file://')) {
      var file = File(imageKey);
      if (await file.exists()) {
        return file.readAsBytes();
      }
      throw "Error: File not found.";
    }

    await for (var event
        in ImageDownloader.loadComicImage(imageKey, sourceKey, cid, eid)) {
      chunkEvents.add(ImageChunkEvent(
        cumulativeBytesLoaded: event.currentBytes,
        expectedTotalBytes: event.totalBytes,
      ));
      if (event.imageBytes != null) {
        return event.imageBytes!;
      }
    }
    throw "Error: Empty response body.";
  }

  @override
  Future<ReaderImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "$imageKey@$sourceKey@$cid@$eid";
}
