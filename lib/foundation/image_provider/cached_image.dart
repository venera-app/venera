import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'cached_image.dart' as image_provider;

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const CachedImageProvider(this.url, {this.headers, this.sourceKey, this.cid});

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  final String? cid;

  static int loadingCount = 0;

  static const _kMaxLoadingCount = 8;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    while(loadingCount > _kMaxLoadingCount) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    loadingCount++;
    try {
      if(url.startsWith("file://")) {
        var file = File(url.substring(7));
        return file.readAsBytes();
      }
      await for (var progress in ImageDownloader.loadThumbnail(url, sourceKey, cid)) {
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: progress.currentBytes,
          expectedTotalBytes: progress.totalBytes,
        ));
        if(progress.imageBytes != null) {
          return progress.imageBytes!;
        }
      }
      throw "Error: Empty response body.";
    }
    finally {
      loadingCount--;
    }
  }

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => url + (sourceKey ?? "") + (cid ?? "");
}
