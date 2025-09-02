import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/cfb.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/modes/ofb.dart';
import 'package:uuid/uuid.dart';
import 'package:venera/components/js_ui.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/js_pool.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/network/cookie_jar.dart';
import 'package:venera/network/proxy.dart';
import 'package:venera/utils/init.dart';

import 'comic_source/comic_source.dart';
import 'consts.dart';
import 'log.dart';

class JavaScriptRuntimeException implements Exception {
  final String message;

  JavaScriptRuntimeException(this.message);

  @override
  String toString() {
    return "JSException: $message";
  }
}

class JsEngine with _JSEngineApi, JsUiApi, Init {
  factory JsEngine() => _cache ?? (_cache = JsEngine._create());

  static JsEngine? _cache;

  JsEngine._create();

  FlutterQjs? _engine;

  bool _closed = true;

  Dio? _dio;

  static void reset() {
    _cache = null;
    _cache?.dispose();
    JsEngine().init();
  }

  void resetDio() {
    _dio = AppDio(BaseOptions(
        responseType: ResponseType.plain, validateStatus: (status) => true));
  }

  static Uint8List? _jsInitCache;

  static void cacheJsInit(Uint8List jsInit) {
    _jsInitCache = jsInit;
  }

  @override
  @protected
  Future<void> doInit() async {
    if (!_closed) {
      return;
    }
    try {
      if (App.isInitialized) {
        _cookieJar ??= await SingleInstanceCookieJar.createInstance();
      }
      _dio ??= AppDio(BaseOptions(
          responseType: ResponseType.plain, validateStatus: (status) => true));
      _closed = false;
      _engine = FlutterQjs();
      _engine!.dispatch();
      var setGlobalFunc =
          _engine!.evaluate("(key, value) => { this[key] = value; }");
      (setGlobalFunc as JSInvokable)(["sendMessage", _messageReceiver]);
      setGlobalFunc(["appVersion", App.version]);
      setGlobalFunc.free();
      Uint8List jsInit;
      if (_jsInitCache != null) {
        jsInit = _jsInitCache!;
      } else {
        var buffer = await rootBundle.load("assets/init.js");
        jsInit = buffer.buffer.asUint8List();
      }
      _engine!
          .evaluate(utf8.decode(jsInit), name: "<init>");
    } catch (e, s) {
      Log.error('JS Engine', 'JS Engine Init Error:\n$e\n$s');
    }
  }

  Object? _messageReceiver(dynamic message) {
    try {
      if (message is Map<dynamic, dynamic>) {
        if (message["method"] == null) return null;
        String method = message["method"] as String;
        switch (method) {
          case "log":
            String level = message["level"];
            Log.addLog(
                switch (level) {
                  "error" => LogLevel.error,
                  "warning" => LogLevel.warning,
                  "info" => LogLevel.info,
                  _ => LogLevel.warning
                },
                message["title"],
                message["content"].toString());
          case 'load_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            return ComicSource.find(key)?.data[dataKey];
          case 'save_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            if (dataKey == 'setting') {
              throw "setting is not allowed to be saved";
            }
            var data = message["data"];
            var source = ComicSource.find(key)!;
            source.data[dataKey] = data;
            source.saveData();
          case 'delete_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            var source = ComicSource.find(key);
            source?.data.remove(dataKey);
            source?.saveData();
          case 'http':
            return _http(Map.from(message));
          case 'html':
            return handleHtmlCallback(Map.from(message));
          case 'convert':
            return _convert(Map.from(message));
          case "random":
            return _random(
              message["min"] ?? 0,
              message["max"] ?? 1,
              message["type"],
            );
          case "cookie":
            return handleCookieCallback(Map.from(message));
          case "uuid":
            return const Uuid().v1();
          case "load_setting":
            String key = message["key"];
            String settingKey = message["setting_key"];
            var source = ComicSource.find(key)!;
            return source.data["settings"]?[settingKey] ??
                source.settings?[settingKey]!['default'] ??
                (throw "Setting not found: $settingKey");
          case "isLogged":
            return ComicSource.find(message["key"])!.isLogged;
          // temporary solution for [setTimeout] function
          // TODO: implement [setTimeout] in quickjs project
          case "delay":
            return Future.delayed(Duration(milliseconds: message["time"]));
          case "UI":
            return handleUIMessage(Map.from(message));
          case "getLocale":
            return "${App.locale.languageCode}_${App.locale.countryCode}";
          case "getPlatform":
            return Platform.operatingSystem;
          case "setClipboard":
            return Clipboard.setData(ClipboardData(text: message["text"]));
          case "getClipboard":
            return Future.sync(() async {
              var res = await Clipboard.getData(Clipboard.kTextPlain);
              return res?.text;
            });
          case "compute":
            final func = message["function"];
            final args = message["args"];
            if (func is JSInvokable) {
              func.free();
              throw "Function must be a string";
            }
            if (func is! String) {
              throw "Function must be a string";
            }
            if (args != null && args is! List) {
              throw "Args must be a list";
            }
            return JSPool().execute(func, args ?? []);
        }
      }
      return null;
    } catch (e, s) {
      Log.error("Failed to handle message: $message\n$e\n$s", "JsEngine");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _http(Map<String, dynamic> req) async {
    Response? response;
    String? error;

    try {
      var headers = Map<String, dynamic>.from(req["headers"] ?? {});
      if (headers["user-agent"] == null && headers["User-Agent"] == null) {
        headers["User-Agent"] = webUA;
      }
      var dio = _dio;
      if (headers['http_client'] == "dart:io") {
        dio = Dio(BaseOptions(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ));
        var proxy = await getProxy();
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            return HttpClient()
              ..findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
          },
        );
        dio.interceptors
            .add(CookieManagerSql(SingleInstanceCookieJar.instance!));
        dio.interceptors.add(LogInterceptor());
      }
      response = await dio!.request(req["url"],
          data: req["data"],
          options: Options(
              method: req['http_method'],
              responseType: req["bytes"] == true
                  ? ResponseType.bytes
                  : ResponseType.plain,
              headers: headers));
    } catch (e) {
      error = e.toString();
    }

    Map<String, String> headers = {};

    response?.headers
        .forEach((name, values) => headers[name] = values.join(','));

    dynamic body = response?.data;
    if (body is! Uint8List && body is List<int>) {
      body = Uint8List.fromList(body);
    }

    return {
      "status": response?.statusCode,
      "headers": headers,
      "body": body,
      "error": error,
    };
  }

  dynamic runCode(String js, [String? name]) {
    return _engine!.evaluate(js, name: name);
  }

  void dispose() {
    _cache = null;
    _closed = true;
    _engine?.close();
    _engine?.port.close();
  }
}

mixin class _JSEngineApi {
  CookieJarSql? _cookieJar;

  final _documents = <int, DocumentWrapper>{};

  Object? handleHtmlCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "parse":
        if (_documents.length > 8) {
          var shouldDelete = _documents.keys.first;
          Log.warning(
            "JS Engine",
            "Too many documents, deleting the oldest: $shouldDelete\n"
                "Current documents: ${_documents.keys}",
          );
          _documents.remove(shouldDelete);
        }
        _documents[data["key"]] = DocumentWrapper.parse(data["data"]);
        return null;
      case "querySelector":
        var key = data["key"];
        return _documents[key]!.querySelector(data["query"]);
      case "querySelectorAll":
        var key = data["key"];
        return _documents[key]!.querySelectorAll(data["query"]);
      case "getText":
        return _documents[data["doc"]]!.elementGetText(data["key"]);
      case "getAttributes":
        var res = _documents[data["doc"]]!.elementGetAttributes(data["key"]);
        return res;
      case "dom_querySelector":
        var doc = _documents[data["doc"]]!;
        return doc.elementQuerySelector(data["key"], data["query"]);
      case "dom_querySelectorAll":
        var doc = _documents[data["doc"]]!;
        return doc.elementQuerySelectorAll(data["key"], data["query"]);
      case "getChildren":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetChildren(data["key"]);
      case "getNodes":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetNodes(data["key"]);
      case "getInnerHTML":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetInnerHTML(data["key"]);
      case "getParent":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetParent(data["key"]);
      case "node_text":
        return _documents[data["doc"]]!.nodeGetText(data["key"]);
      case "node_type":
        return _documents[data["doc"]]!.nodeType(data["key"]);
      case "node_to_element":
        return _documents[data["doc"]]!.nodeToElement(data["key"]);
      case "dispose":
        var docKey = data["key"];
        _documents.remove(docKey);
        return null;
      case "getClassNames":
        return _documents[data["doc"]]!.getClassNames(data["key"]);
      case "getId":
        return _documents[data["doc"]]!.getId(data["key"]);
      case "getLocalName":
        return _documents[data["doc"]]!.getLocalName(data["key"]);
      case "getElementById":
        return _documents[data["key"]]!.getElementById(data["id"]);
      case "getPreviousSibling":
        return _documents[data["doc"]]!.getPreviousSibling(data["key"]);
      case "getNextSibling":
        return _documents[data["doc"]]!.getNextSibling(data["key"]);
    }
    return null;
  }

  dynamic handleCookieCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "set":
        _cookieJar!.saveFromResponse(
            Uri.parse(data["url"]),
            (data["cookies"] as List).map((e) {
              var c = Cookie(e["name"], e["value"]);
              if (e['domain'] != null) {
                c.domain = e['domain'];
              }
              return c;
            }).toList());
        return null;
      case "get":
        var cookies = _cookieJar!.loadForRequest(Uri.parse(data["url"]));
        return cookies
            .map((e) => {
                  "name": e.name,
                  "value": e.value,
                  "domain": e.domain,
                  "path": e.path,
                  "expires": e.expires,
                  "max-age": e.maxAge,
                  "secure": e.secure,
                  "httpOnly": e.httpOnly,
                  "session": e.expires == null,
                })
            .toList();
      case "delete":
        clearCookies([data["url"]]);
        return null;
    }
  }

  void clearCookies(List<String> domains) async {
    for (var domain in domains) {
      var uri = Uri.tryParse(domain);
      if (uri == null) continue;
      _cookieJar!.deleteUri(uri);
    }
  }

  Object? _convert(Map<String, dynamic> data) {
    String type = data["type"];
    var value = data["value"];
    bool isEncode = data["isEncode"];
    try {
      switch (type) {
        case "utf8":
          return isEncode ? utf8.encode(value) : utf8.decode(value);
        case "gbk":
          final codec = const GbkCodec();
          return isEncode
              ? Uint8List.fromList(codec.encode(value))
              : codec.decode(value);
        case "base64":
          return isEncode ? base64Encode(value) : base64Decode(value);
        case "md5":
          return Uint8List.fromList(md5.convert(value).bytes);
        case "sha1":
          return Uint8List.fromList(sha1.convert(value).bytes);
        case "sha256":
          return Uint8List.fromList(sha256.convert(value).bytes);
        case "sha512":
          return Uint8List.fromList(sha512.convert(value).bytes);
        case "hmac":
          var key = data["key"];
          var hash = data["hash"];
          var hmac = Hmac(
              switch (hash) {
                "md5" => md5,
                "sha1" => sha1,
                "sha256" => sha256,
                "sha512" => sha512,
                _ => throw "Unsupported hash: $hash"
              },
              key);
          if (data['isString'] == true) {
            return hmac.convert(value).toString();
          } else {
            return Uint8List.fromList(hmac.convert(value).bytes);
          }
        case "aes-ecb":
          if (!isEncode) {
            var key = data["key"];
            var cipher = ECBBlockCipher(AESEngine());
            cipher.init(
              false,
              KeyParameter(key),
            );
            var offset = 0;
            var result = Uint8List(value.length);
            while (offset < value.length) {
              offset += cipher.processBlock(
                value,
                offset,
                result,
                offset,
              );
            }
            return result;
          }
          return null;
        case "aes-cbc":
          if (!isEncode) {
            var key = data["key"];
            var iv = data["iv"];
            var cipher = CBCBlockCipher(AESEngine());
            cipher.init(false, ParametersWithIV(KeyParameter(key), iv));
            var offset = 0;
            var result = Uint8List(value.length);
            while (offset < value.length) {
              offset += cipher.processBlock(
                value,
                offset,
                result,
                offset,
              );
            }
            return result;
          }
          return null;
        case "aes-cfb":
          if (!isEncode) {
            var key = data["key"];
            var blockSize = data["blockSize"];
            var cipher = CFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            var offset = 0;
            var result = Uint8List(value.length);
            while (offset < value.length) {
              offset += cipher.processBlock(
                value,
                offset,
                result,
                offset,
              );
            }
            return result;
          }
          return null;
        case "aes-ofb":
          if (!isEncode) {
            var key = data["key"];
            var blockSize = data["blockSize"];
            var cipher = OFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            var offset = 0;
            var result = Uint8List(value.length);
            while (offset < value.length) {
              offset += cipher.processBlock(
                value,
                offset,
                result,
                offset,
              );
            }
            return result;
          }
          return null;
        case "rsa":
          if (!isEncode) {
            var key = data["key"];
            final cipher = PKCS1Encoding(RSAEngine());
            cipher.init(false,
                PrivateKeyParameter<RSAPrivateKey>(_parsePrivateKey(key)));
            return _processInBlocks(cipher, value);
          }
          return null;
        default:
          return value;
      }
    } catch (e, s) {
      Log.error("JS Engine", "Failed to convert $type: $e", s);
      return null;
    }
  }

  RSAPrivateKey _parsePrivateKey(String privateKeyString) {
    List<int> privateKeyDER = base64Decode(privateKeyString);
    var asn1Parser = ASN1Parser(privateKeyDER as Uint8List);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    final privateKey = topLevelSeq.elements![2];

    asn1Parser = ASN1Parser(privateKey.valueBytes!);
    final pkSeq = asn1Parser.nextObject() as ASN1Sequence;

    final modulus = pkSeq.elements![1] as ASN1Integer;
    final privateExponent = pkSeq.elements![3] as ASN1Integer;
    final p = pkSeq.elements![4] as ASN1Integer;
    final q = pkSeq.elements![5] as ASN1Integer;

    return RSAPrivateKey(
        modulus.integer!, privateExponent.integer!, p.integer!, q.integer!);
  }

  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks = input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final output = Uint8List(numBlocks * engine.outputBlockSize);

    var inputOffset = 0;
    var outputOffset = 0;
    while (inputOffset < input.length) {
      final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - inputOffset;

      outputOffset += engine.processBlock(
          input, inputOffset, chunkSize, output, outputOffset);

      inputOffset += chunkSize;
    }

    return (output.length == outputOffset)
        ? output
        : output.sublist(0, outputOffset);
  }

  num _random(num min, num max, String type) {
    if (type == "double") {
      return min + (max - min) * math.Random().nextDouble();
    }
    return (min + (max - min) * math.Random().nextDouble()).toInt();
  }
}

class DocumentWrapper {
  final dom.Document doc;

  DocumentWrapper.parse(String doc) : doc = html.parse(doc);

  var elements = <dom.Element>[];

  var nodes = <dom.Node>[];

  int? querySelector(String query) {
    var element = doc.querySelector(query);
    if (element == null) return null;
    elements.add(element);
    return elements.length - 1;
  }

  List<int> querySelectorAll(String query) {
    var res = doc.querySelectorAll(query);
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  String? elementGetText(int key) {
    return elements[key].text;
  }

  Map<String, String> elementGetAttributes(int key) {
    return elements[key].attributes.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        );
  }

  String? elementGetInnerHTML(int key) {
    return elements[key].innerHtml;
  }

  int? elementGetParent(int key) {
    var res = elements[key].parent;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  int? elementQuerySelector(int key, String query) {
    var res = elements[key].querySelector(query);
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  List<int> elementQuerySelectorAll(int key, String query) {
    var res = elements[key].querySelectorAll(query);
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  List<int> elementGetChildren(int key) {
    var res = elements[key].children;
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  List<int> elementGetNodes(int key) {
    var res = elements[key].nodes;
    var keys = <int>[];
    for (var node in res) {
      nodes.add(node);
      keys.add(nodes.length - 1);
    }
    return keys;
  }

  String? nodeGetText(int key) {
    return nodes[key].text;
  }

  String nodeType(int key) {
    return switch (nodes[key].nodeType) {
      dom.Node.ELEMENT_NODE => "element",
      dom.Node.TEXT_NODE => "text",
      dom.Node.COMMENT_NODE => "comment",
      dom.Node.DOCUMENT_NODE => "document",
      _ => "unknown"
    };
  }

  int? nodeToElement(int key) {
    if (nodes[key] is dom.Element) {
      elements.add(nodes[key] as dom.Element);
      return elements.length - 1;
    }
    return null;
  }

  List<String> getClassNames(int key) {
    return (elements[key]).classes.toList();
  }

  String? getId(int key) {
    return (elements[key]).id;
  }

  String? getLocalName(int key) {
    return (elements[key]).localName;
  }

  int? getElementById(String id) {
    var element = doc.getElementById(id);
    if (element == null) return null;
    elements.add(element);
    return elements.length - 1;
  }

  int? getPreviousSibling(int key) {
    var res = elements[key].previousElementSibling;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  int? getNextSibling(int key) {
    var res = elements[key].nextElementSibling;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }
}

class JSAutoFreeFunction {
  final JSInvokable func;

  /// Automatically free the function when it's not used anymore
  JSAutoFreeFunction(this.func) {
    func.dup();
    finalizer.attach(this, func);
  }

  dynamic call(List<dynamic> args) {
    return func(args);
  }

  static final finalizer = Finalizer<JSInvokable>((func) {
    func.destroy();
  });
}
