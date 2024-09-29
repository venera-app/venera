import 'dart:async' show Future, StreamController;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/network/app_dio.dart';
import 'base_image_provider.dart';
import 'cached_image.dart' as image_provider;

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  const CachedImageProvider(this.url, {this.headers, this.sourceKey});

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    final cacheKey = "$url@$sourceKey";
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      return await cache.readAsBytes();
    }

    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey!);
      configs = comicSource!.getThumbnailLoadingConfig?.call(url) ?? {};
    }
    configs['headers'] ??= {
      'user-agent': webUA,
    };

    var dio = AppDio(BaseOptions(
      headers: configs['headers'],
      method: configs['method'] ?? 'GET',
      responseType: ResponseType.stream,
    ));

    var req = await dio.request<ResponseBody>(configs['url'] ?? url,
        data: configs['data']);
    var stream = req.data?.stream ?? (throw "Error: Empty response body.");
    int? expectedBytes = req.data!.contentLength;
    if (expectedBytes == -1) {
      expectedBytes = null;
    }
    var buffer = <int>[];
    await for (var data in stream) {
      buffer.addAll(data);
      if (expectedBytes != null) {
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: buffer.length,
          expectedTotalBytes: expectedBytes,
        ));
      }
    }

    if(configs['onResponse'] != null) {
      buffer = configs['onResponse'](buffer);
    }

    await CacheManager().writeCache(cacheKey, buffer);
    return Uint8List.fromList(buffer);
  }

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => url;
}
