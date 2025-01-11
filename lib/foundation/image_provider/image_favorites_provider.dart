import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/network/images.dart';
import '../history.dart';
import 'base_image_provider.dart';
import 'image_favorites_provider.dart' as image_provider;

class ImageFavoritesProvider
    extends BaseImageProvider<image_provider.ImageFavoritesProvider> {
  /// Image provider for imageFavorites
  const ImageFavoritesProvider(this.imageFavorite);

  final ImageFavorite imageFavorite;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    String imageKey = imageFavorite.imageKey;
    String sourceKey = imageFavorite.sourceKey;
    String cid = imageFavorite.id;
    String eid = imageFavorite.eid;
    if (imageKey == "") {
      throw "Error: imageFavorites no imageKey";
    }
    await for (var progress
        in ImageDownloader.loadComicImage(imageKey, sourceKey, cid, eid)) {
      chunkEvents.add(ImageChunkEvent(
        cumulativeBytesLoaded: progress.currentBytes,
        expectedTotalBytes: progress.totalBytes,
      ));
      if (progress.imageBytes != null) {
        return progress.imageBytes!;
      }
    }
    throw "Error: Empty response body.";
  }

  @override
  Future<ImageFavoritesProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  static String getImageKey(ImageFavorite temp) {
    return "${temp.imageKey}@${temp.sourceKey}@${temp.id}@${temp.eid}";
  }

  // 和 reader_image 的一样
  @override
  String get key => getImageKey(imageFavorite);
}
