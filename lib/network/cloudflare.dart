import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/pages/webview.dart';
import 'package:venera/utils/ext.dart';

import 'cookie_jar.dart';

class CloudflareException implements DioException {
  final String url;

  const CloudflareException(this.url);

  @override
  String toString() {
    return "CloudflareException: $url";
  }

  static CloudflareException? fromString(String message) {
    var match = RegExp(r"CloudflareException: (.+)").firstMatch(message);
    if (match == null) return null;
    return CloudflareException(match.group(1)!);
  }

  @override
  DioException copyWith(
      {RequestOptions? requestOptions,
      Response<dynamic>? response,
      DioExceptionType? type,
      Object? error,
      StackTrace? stackTrace,
      String? message}) {
    return this;
  }

  @override
  Object? get error => this;

  @override
  String? get message => toString();

  @override
  RequestOptions get requestOptions => RequestOptions();

  @override
  Response? get response => null;

  @override
  StackTrace get stackTrace => StackTrace.empty;

  @override
  DioExceptionType get type => DioExceptionType.badResponse;
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if(options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = appdata.implicitData['ua'] ?? webUA;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 403) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 403) {
      var err = _check(response);
      if (err != null) {
        handler.reject(err);
        return;
      }
    }
    handler.next(response);
  }

  CloudflareException? _check(Response response) {
    if (response.headers['cf-mitigated']?.firstOrNull == "challenge") {
      return CloudflareException(response.requestOptions.uri.toString());
    }
    return null;
  }
}

void passCloudflare(CloudflareException e, void Function() onFinished) async {
  var url = e.url;
  var uri = Uri.parse(url);

  void saveCookies(Map<String, String> cookies) {
    var domain = uri.host;
    var splits = domain.split('.');
    if (splits.length > 1) {
      domain = ".${splits[splits.length - 2]}.${splits[splits.length - 1]}";
    }
    SingleInstanceCookieJar.instance!.saveFromResponse(
      uri,
      List<io.Cookie>.generate(cookies.length, (index) {
        var cookie = io.Cookie(
            cookies.keys.elementAt(index), cookies.values.elementAt(index));
        cookie.domain = domain;
        return cookie;
      }),
    );
  }

  // windows version of package `flutter_inappwebview` cannot get some cookies
  // Using DesktopWebview instead
  if (App.isLinux || App.isWindows) {
    var webview = DesktopWebview(
      initialUrl: url,
      onTitleChange: (title, controller) async {
        var res = await controller.evaluateJavascript(
            "document.head.innerHTML.includes('#challenge-success-text')");
        if (res == 'false') {
          var ua = controller.userAgent;
          if (ua != null) {
            appdata.implicitData['ua'] = ua;
            appdata.writeImplicitData();
          }
          var cookiesMap = await controller.getCookies(url);
          if(cookiesMap['cf_clearance'] == null) {
            return;
          }
          saveCookies(cookiesMap);
          controller.close();
          onFinished();
        }
      },
    );
    webview.open();
  } else {
    await App.rootContext.to(
      () => AppWebview(
        initialUrl: url,
        singlePage: true,
        onLoadStop: (controller) async {
          var res = await controller.platform.evaluateJavascript(
              source:
                  "document.head.innerHTML.includes('#challenge-success-text')");
          if (res == false) {
            var ua = await controller.getUA();
            if (ua != null) {
              appdata.implicitData['ua'] = ua;
              appdata.writeImplicitData();
            }
            var cookies = await controller.getCookies(url) ?? [];
            if(cookies.firstWhereOrNull((element) => element.name == 'cf_clearance') == null) {
              return;
            }
            SingleInstanceCookieJar.instance?.saveFromResponse(uri, cookies);
            App.rootPop();
          }
        },
        onStarted: (controller) async {
          var ua = await controller.getUA();
          if (ua != null) {
            appdata.implicitData['ua'] = ua;
            appdata.writeImplicitData();
          }
          var cookies = await controller.getCookies(url) ?? [];
          SingleInstanceCookieJar.instance?.saveFromResponse(uri, cookies);
        },
      ),
    );
    onFinished();
  }
}
