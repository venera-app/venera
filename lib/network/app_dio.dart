import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:rhttp/rhttp.dart' as rhttp;
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/cache.dart';
import 'package:venera/utils/ext.dart';

import '../foundation/app.dart';
import 'cloudflare.dart';
import 'cookie_jar.dart';

export 'package:dio/dio.dart';

class MyLogInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Log.error("Network",
        "${err.requestOptions.method} ${err.requestOptions.path}\n$err\n${err.response?.data.toString()}");
    switch (err.type) {
      case DioExceptionType.badResponse:
        var statusCode = err.response?.statusCode;
        if (statusCode != null) {
          err = err.copyWith(
              message: "Invalid Status Code: $statusCode. "
                  "${_getStatusCodeInfo(statusCode)}");
        }
      case DioExceptionType.connectionTimeout:
        err = err.copyWith(message: "Connection Timeout");
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(
            message: "Receive Timeout: "
                "This indicates that the server is too busy to respond");
      case DioExceptionType.unknown:
        if (err.toString().contains("Connection terminated during handshake")) {
          err = err.copyWith(
              message: "Connection terminated during handshake: "
                  "This may be caused by the firewall blocking the connection "
                  "or your requests are too frequent.");
        } else if (err.toString().contains("Connection reset by peer")) {
          err = err.copyWith(
              message: "Connection reset by peer: "
                  "The error is unrelated to app, please check your network.");
        }
      default:
        {}
    }
    handler.next(err);
  }

  static const errorMessages = <int, String>{
    400: "The Request is invalid.",
    401: "The Request is unauthorized.",
    403: "No permission to access the resource. Check your account or network.",
    404: "Not found.",
    429: "Too many requests. Please try again later.",
  };

  String _getStatusCodeInfo(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return "This is server-side error, please try again later. "
          "Do not report this issue.";
    } else {
      return errorMessages[statusCode] ?? "";
    }
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    var headers = response.headers.map.map((key, value) => MapEntry(
        key.toLowerCase(), value.length == 1 ? value.first : value.toString()));
    headers.remove("cookie");
    String content;
    if (response.data is List<int>) {
      try {
        content = utf8.decode(response.data, allowMalformed: false);
      } catch (e) {
        content = "<Bytes>\nlength:${response.data.length}";
      }
    } else {
      content = response.data.toString();
    }
    Log.addLog(
        (response.statusCode != null && response.statusCode! < 400)
            ? LogLevel.info
            : LogLevel.error,
        "Network",
        "Response ${response.realUri.toString()} ${response.statusCode}\n"
            "headers:\n$headers\n$content");
    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Log.info("Network", "${options.method} ${options.uri}\n"
        "headers:\n${options.headers}\n"
        "data:\n${options.data}");
    options.connectTimeout = const Duration(seconds: 15);
    options.receiveTimeout = const Duration(seconds: 15);
    options.sendTimeout = const Duration(seconds: 15);
    handler.next(options);
  }
}

class AppDio with DioMixin {
  String? _proxy = proxy;
  static bool get ignoreCertificateErrors => appdata.settings['ignoreCertificateErrors'] == true;

  AppDio([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    httpClientAdapter = RHttpAdapter(rhttp.ClientSettings(
      proxySettings: proxy == null
          ? const rhttp.ProxySettings.noProxy()
          : rhttp.ProxySettings.proxy(proxy!),
      tlsSettings: rhttp.TlsSettings(
        verifyCertificates: !ignoreCertificateErrors,
      ),
    ));
    interceptors.add(CookieManagerSql(SingleInstanceCookieJar.instance!));
    interceptors.add(NetworkCacheManager());
    interceptors.add(CloudflareInterceptor());
    interceptors.add(MyLogInterceptor());
  }

  static String? proxy;

  static Future<String?> getProxy() async {
    if ((appdata.settings['proxy'] as String).removeAllBlank == "direct") {
      return null;
    }
    if (appdata.settings['proxy'] != "system") return appdata.settings['proxy'];

    String res;
    if (!App.isLinux) {
      const channel = MethodChannel("venera/method_channel");
      try {
        res = await channel.invokeMethod("getProxy");
      } catch (e) {
        return null;
      }
    } else {
      res = "No Proxy";
    }
    if (res == "No Proxy") return null;

    if (res.contains(";")) {
      var proxies = res.split(";");
      for (String proxy in proxies) {
        proxy = proxy.removeAllBlank;
        if (proxy.startsWith('https=')) {
          return proxy.substring(6);
        }
      }
    }

    final RegExp regex = RegExp(
      r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$',
      caseSensitive: false,
      multiLine: false,
    );
    if (!regex.hasMatch(res)) {
      return null;
    }

    return res;
  }

  static final Map<String, bool> _requests = {};

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (options?.headers?['prevent-parallel'] == 'true') {
      while (_requests.containsKey(path)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      _requests[path] = true;
      options!.headers!.remove('prevent-parallel');
    }
    proxy = await getProxy();
    if (_proxy != proxy) {
      Log.info("Network", "Proxy changed to $proxy");
      _proxy = proxy;
      httpClientAdapter = RHttpAdapter(rhttp.ClientSettings(
        proxySettings: proxy == null
            ? const rhttp.ProxySettings.noProxy()
            : rhttp.ProxySettings.proxy(proxy!),
        tlsSettings: rhttp.TlsSettings(
          verifyCertificates: !ignoreCertificateErrors,
        ),
      ));
    }
    try {
      return super.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } finally {
      if (_requests.containsKey(path)) {
        _requests.remove(path);
      }
    }
  }
}

class RHttpAdapter implements HttpClientAdapter {
  rhttp.ClientSettings settings;

  RHttpAdapter([this.settings = const rhttp.ClientSettings()]) {
    settings = settings.copyWith(
      redirectSettings: const rhttp.RedirectSettings.limited(5),
      timeoutSettings: const rhttp.TimeoutSettings(
        connectTimeout: Duration(seconds: 15),
        keepAliveTimeout: Duration(seconds: 60),
        keepAlivePing: Duration(seconds: 30),
      ),
      throwOnStatusCode: false,
      tlsSettings: rhttp.TlsSettings(
        verifyCertificates: !AppDio.ignoreCertificateErrors,
      ),
    );
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var res = await rhttp.Rhttp.request(
      method: switch (options.method) {
        'GET' => rhttp.HttpMethod.get,
        'POST' => rhttp.HttpMethod.post,
        'PUT' => rhttp.HttpMethod.put,
        'PATCH' => rhttp.HttpMethod.patch,
        'DELETE' => rhttp.HttpMethod.delete,
        'HEAD' => rhttp.HttpMethod.head,
        'OPTIONS' => rhttp.HttpMethod.options,
        'TRACE' => rhttp.HttpMethod.trace,
        'CONNECT' => rhttp.HttpMethod.connect,
        _ => throw ArgumentError('Unsupported method: ${options.method}'),
      },
      url: options.uri.toString(),
      settings: settings,
      expectBody: rhttp.HttpExpectBody.stream,
      body: requestStream == null ? null : rhttp.HttpBody.stream(requestStream),
      headers: rhttp.HttpHeaders.rawMap(
        Map.fromEntries(
          options.headers.entries.map(
            (e) => MapEntry(e.key, e.value.toString().trim()),
          ),
        ),
      ),
    );
    if (res is! rhttp.HttpStreamResponse) {
      throw Exception("Invalid response type: ${res.runtimeType}");
    }
    var headers = <String, List<String>>{};
    for (var entry in res.headers) {
      var key = entry.$1.toLowerCase();
      headers[key] ??= [];
      headers[key]!.add(entry.$2);
    }
    return ResponseBody(
      res.body,
      res.statusCode,
      statusMessage: null,
      isRedirect: false,
      headers: headers,
    );
  }
}
