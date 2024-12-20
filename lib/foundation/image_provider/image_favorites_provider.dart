import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/network/images.dart';
import '../history.dart';
import 'base_image_provider.dart';
import 'image_favorites_provider.dart' as image_provider;

class ImageFavoritesProvider
    extends BaseImageProvider<image_provider.ImageFavoritesProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const ImageFavoritesProvider(this.imageFavorite);

  final ImageFavorite imageFavorite;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    String? imageKey = imageFavorite.otherInfo["imageKey"];
    List<String> ids = imageFavorite.id.split('-');
    String sourceKey = ids[0];
    String cid = ids[1];
    String eid = imageFavorite.ep.toString();
    if (imageKey == null) {
      throw "Error: imageFavorits no imageKey";
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

  @override
  String get key =>
      "imageFavorite${imageFavorite.id}${imageFavorite.ep}${imageFavorite.page}";
}
