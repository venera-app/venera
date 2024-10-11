import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/utils/ext.dart';

import '../foundation/app.dart';

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
    options.connectTimeout = const Duration(seconds: 15);
    options.receiveTimeout = const Duration(seconds: 15);
    options.sendTimeout = const Duration(seconds: 15);
    handler.next(options);
  }
}

class AppDio with DioMixin {
  String? _proxy = proxy;

  AppDio([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    interceptors.add(MyLogInterceptor());
    httpClientAdapter = IOHttpClientAdapter(createHttpClient: createHttpClient);
  }

  static HttpClient createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    client.findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
    client.idleTimeout = const Duration(seconds: 100);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (host.contains("cdn")) return true;
      final ipv4RegExp = RegExp(
          r'^((25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3})$');
      if (ipv4RegExp.hasMatch(host)) {
        return true;
      }
      return false;
    };
    return client;
  }

  static String? proxy;

  static Future<String?> getProxy() async {
    if ((appdata.settings['proxy'] as String).removeAllBlank == "direct") return null;
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

  @override
  Future<Response<T>> request<T> (
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    proxy = await getProxy();
    if(_proxy != proxy) {
      _proxy = proxy;
      (httpClientAdapter as IOHttpClientAdapter).close();
      httpClientAdapter = IOHttpClientAdapter(createHttpClient: createHttpClient);
    }
    return super.request(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}
