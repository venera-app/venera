import 'dart:async' show Future;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'cached_image.dart' as image_provider;

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const CachedImageProvider(this.url, {
    this.headers,
    this.sourceKey,
    this.cid,
    this.fallbackToLocalCover = false,
  });

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  final String? cid;

  // Use local cover if network image fails to load.
  final bool fallbackToLocalCover;

  static int loadingCount = 0;

  static const _kMaxLoadingCount = 8;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    while(loadingCount > _kMaxLoadingCount) {
      await Future.delayed(const Duration(milliseconds: 100));
      checkStop();
    }
    loadingCount++;
    try {
      if(url.startsWith("file://")) {
        var file = File(url.substring(7));
        return file.readAsBytes();
      }
      await for (var progress in ImageDownloader.loadThumbnail(url, sourceKey, cid)) {
        checkStop();
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
    catch(e) {
      if (fallbackToLocalCover && sourceKey != null && cid != null) {
        final localComic = LocalManager().find(
          cid!,
          ComicType.fromKey(sourceKey!),
        );
        if (localComic != null) {
          var file = localComic.coverFile;
          if (await file.exists()) {
            var data = await file.readAsBytes();
            if (data.isNotEmpty) {
              return data;
            }
          }
        }
      }
      rethrow;
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
