import 'dart:async' show Future, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'local_comic_image.dart' as image_provider;

class LocalComicImageProvider
    extends BaseImageProvider<image_provider.LocalComicImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const LocalComicImageProvider(this.comic);

  final LocalComic comic;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    File? file = comic.coverFile;
    if(! await file.exists()) {
      file = null;
      var dir = Directory(comic.directory);
      if (! await dir.exists()) {
        throw "Error: Comic not found.";
      }
      Directory? firstDir;
      await for (var entity in dir.list()) {
        if(entity is File) {
          if(["jpg", "jpeg", "png", "webp", "gif", "jpe", "jpeg"].contains(entity.extension)) {
            file = entity;
            break;
          }
        } else if(entity is Directory) {
          firstDir ??= entity;
        }
      }
      if(file == null && firstDir != null) {
        await for (var entity in firstDir.list()) {
          if(entity is File) {
            if(["jpg", "jpeg", "png", "webp", "gif", "jpe", "jpeg"].contains(entity.extension)) {
              file = entity;
              break;
            }
          }
        }
      }
    }
    if(file == null) {
      throw "Error: Cover not found.";
    }
    var data = await file.readAsBytes();
    if(data.isEmpty) {
      throw "Exception: Empty file(${file.path}).";
    }
    return data;
  }

  @override
  Future<LocalComicImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "local${comic.id}${comic.comicType.value}";
}
