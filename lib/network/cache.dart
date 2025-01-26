import 'dart:typed_data';
import 'package:venera/network/app_dio.dart';

class NetworkCache {
  final Uri uri;

  final Map<String, dynamic> requestHeaders;

  final Map<String, List<String>> responseHeaders;

  final Object? data;

  final DateTime time;

  final int size;

  const NetworkCache({
    required this.uri,
    required this.requestHeaders,
    required this.responseHeaders,
    required this.data,
    required this.time,
    required this.size,
  });
}

class NetworkCacheManager implements Interceptor {
  NetworkCacheManager._();

  static final NetworkCacheManager instance = NetworkCacheManager._();

  factory NetworkCacheManager() => instance;

  final Map<Uri, NetworkCache> _cache = {};

  int size = 0;

  NetworkCache? getCache(Uri uri) {
    return _cache[uri];
  }

  static const _maxCacheSize = 10 * 1024 * 1024;

  void setCache(NetworkCache cache) {
    if (_cache.containsKey(cache.uri)) {
      size -= _cache[cache.uri]!.size;
    }
    while (size > _maxCacheSize) {
      size -= _cache.values.first.size;
      _cache.remove(_cache.keys.first);
    }
    _cache[cache.uri] = cache;
    size += cache.size;
  }

  void removeCache(Uri uri) {
    var cache = _cache[uri];
    if (cache != null) {
      size -= cache.size;
    }
    _cache.remove(uri);
  }

  void clear() {
    _cache.clear();
    size = 0;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.method != "GET") {
      return handler.next(err);
    }
    return handler.next(err);
  }

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.method != "GET") {
      return handler.next(options);
    }
    var cache = getCache(options.uri);
    if (cache == null ||
        !compareHeaders(options.headers, cache.requestHeaders)) {
      if (options.headers['cache-time'] != null) {
        options.headers.remove('cache-time');
      }
      return handler.next(options);
    } else {
      if (options.headers['cache-time'] == 'no') {
        options.headers.remove('cache-time');
        removeCache(options.uri);
        return handler.next(options);
      }
    }
    var time = DateTime.now();
    var diff = time.difference(cache.time);
    if (options.headers['cache-time'] == 'long' &&
        diff < const Duration(hours: 6)) {
      return handler.resolve(Response(
        requestOptions: options,
        data: cache.data,
        headers: Headers.fromMap(cache.responseHeaders)
          ..set('venera-cache', 'true'),
        statusCode: 200,
      ));
    } else if (diff < const Duration(seconds: 5)) {
      return handler.resolve(Response(
        requestOptions: options,
        data: cache.data,
        headers: Headers.fromMap(cache.responseHeaders)
          ..set('venera-cache', 'true'),
        statusCode: 200,
      ));
    } else if (diff < const Duration(hours: 2)) {
      var o = options.copyWith(
        method: "HEAD",
      );
      var dio = AppDio();
      var response = await dio.fetch(o);
      if (response.statusCode == 200 &&
          compareHeaders(cache.responseHeaders, response.headers.map)) {
        return handler.resolve(Response(
          requestOptions: options,
          data: cache.data,
          headers: Headers.fromMap(cache.responseHeaders)
            ..set('venera-cache', 'true'),
          statusCode: 200,
        ));
      }
    }
    removeCache(options.uri);
    handler.next(options);
  }

  static bool compareHeaders(Map<String, dynamic> a, Map<String, dynamic> b) {
    a = Map.from(a);
    b = Map.from(b);
    const shouldIgnore = [
      'cache-time',
      'prevent-parallel',
      'date',
      'x-varnish',
      'cf-ray',
      'connection',
      'vary',
      'content-encoding',
      'report-to',
      'server-timing',
      'token',
      'set-cookie',
      'cf-cache-status',
      'cf-request-id',
      'cf-ray',
      'authorization',
    ];
    for (var key in shouldIgnore) {
      a.remove(key);
      b.remove(key);
    }
    if (a.length != b.length) {
      return false;
    }
    for (var key in a.keys) {
      if (a[key] is List && b[key] is List) {
        if (a[key].length != b[key].length) {
          return false;
        }
        for (var i = 0; i < a[key].length; i++) {
          if (a[key][i] != b[key][i]) {
            return false;
          }
        }
      } else if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method != "GET") {
      return handler.next(response);
    }
    if (response.statusCode != null && response.statusCode! >= 400) {
      return handler.next(response);
    }
    var size = _calculateSize(response.data);
    if (size != null && size < 1024 * 1024 && size > 0) {
      var cache = NetworkCache(
        uri: response.requestOptions.uri,
        requestHeaders: response.requestOptions.headers,
        responseHeaders: Map.from(response.headers.map),
        data: response.data,
        time: DateTime.now(),
        size: size,
      );
      setCache(cache);
    }
    handler.next(response);
  }

  static int? _calculateSize(Object? data) {
    if (data == null) {
      return 0;
    }
    if (data is List<int>) {
      return data.length;
    }
    if (data is Uint8List) {
      return data.length;
    }
    if (data is String) {
      if (data.trim().isEmpty) {
        return 0;
      }
      if (data.length < 512 && data.contains("IP address")) {
        return 0;
      }
      return data.length * 4;
    }
    if (data is Map) {
      return data.toString().length * 4;
    }
    return null;
  }
}
