import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/utils/image.dart';
import 'package:venera/utils/io.dart';
import 'package:zip_flutter/zip_flutter.dart';

typedef DecodeImage = Future<Image> Function(Uint8List data);

Future<void> _createPdfFromComic({
  required LocalComic comic,
  required String savePath,
  required String localPath,
  required DecodeImage decodeImage,
}) async {
  var images = <String>[];

  var baseDir = comic.directory.contains('/') || comic.directory.contains('\\')
      ? comic.directory
      : FilePath.join(localPath, comic.directory);

  // add cover
  images.add(FilePath.join(baseDir, comic.cover));

  bool multiChapters = comic.chapters != null;

  void reorderFiles(List<FileSystemEntity> files) {
    files.removeWhere(
        (element) => element is! File || element.path.startsWith('cover'));
    files.sort((a, b) {
      var aName = (a as File).basenameWithoutExt;
      var bName = (b as File).basenameWithoutExt;
      var aNumber = int.tryParse(aName);
      var bNumber = int.tryParse(bName);
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return a.name.compareTo(b.name);
    });
  }

  if (!multiChapters) {
    var files = Directory(baseDir).listSync();
    reorderFiles(files);

    for (var file in files) {
      images.add(file.path);
    }
  } else {
    for (var chapter in comic.downloadedChapters) {
      var files = Directory(FilePath.join(baseDir, chapter)).listSync();
      reorderFiles(files);
      for (var file in files) {
        images.add(file.path);
      }
    }
  }

  var generator = PdfGenerator(
    title: comic.title,
    author: comic.subtitle,
    imagePaths: images,
    outputPath: savePath,
    decodeImage: decodeImage,
  );
  await generator.generate();
}

Future<Isolate> _runIsolate(
    LocalComic comic, String savePath, SendPort sendPort) {
  var localPath = LocalManager().path;
  return Isolate.spawn<SendPort>(
    (sendPort) => overrideIO(
      () async {
        if (App.isAndroid) {
          await SAFTaskWorker().init();
        }
        var receivePort = ReceivePort();
        sendPort.send(receivePort.sendPort);

        Completer<Image>? completer;

        Future<Image> decodeImage(Uint8List data) async {
          if (completer != null) {
            throw Exception('Another image is being decoded');
          }
          sendPort.send(data);
          completer = Completer();
          return completer!.future;
        }

        receivePort.listen((message) {
          if (message is Image) {
            if (completer == null) {
              throw Exception('No image is being decoded');
            }
            completer!.complete(message);
            completer = null;
          }
        });

        await _createPdfFromComic(
          comic: comic,
          savePath: savePath,
          localPath: localPath,
          decodeImage: decodeImage,
        );

        sendPort.send(null);
      },
    ),
    sendPort,
  );
}

Future<File> createPdfFromComicIsolate(LocalComic comic, String savePath) async {
  var receivePort = ReceivePort();
  SendPort? sendPort;
  Isolate? isolate;
  var completer = Completer<void>();
  receivePort.listen((message) {
    if (message is SendPort) {
      sendPort = message;
    } else if (message is Uint8List) {
      Image.decodeImage(message).then((image) {
        sendPort!.send(image);
      });
    } else if (message == null) {
      receivePort.close();
      completer.complete();
      isolate!.kill();
    }
  });
  isolate = await _runIsolate(comic, savePath, receivePort.sendPort);
  await completer.future;
  return File(savePath);
}

class PdfGenerator {
  final String title;
  final String author;
  final List<String> imagePaths;
  final String outputPath;
  final DecodeImage decodeImage;

  // PDF文件的对象ID计数器
  int _objectId = 1;

  // 存储每个对象在PDF中的字节位置
  final Map<int, int> _objectOffsets = {};

  static const double a4Width = 595.0; // points
  static const double a4Height = 842.0; // points

  PdfGenerator({
    required this.title,
    required this.author,
    required this.imagePaths,
    required this.outputPath,
    required this.decodeImage,
  });

  Future<void> generate() async {
    var file = File(outputPath);
    final output = file.openWrite();

    int length = 0;

    void write(String str) {
      var data = utf8.encode(str);
      output.add(data);
      length += data.length;
    }

    void writeData(Uint8List data) {
      output.add(data);
      length += data.length;
    }

    int getCurrentLength() {
      return length;
    }

    // 1. 写入PDF头部
    write('%PDF-1.7\n%\xFF\xFF\xFF\xFF\n\n');

    // 2. 写入Catalog对象
    _objectOffsets[_objectId] = getCurrentLength();
    write('$_objectId 0 obj\n');
    write('<<\n');
    write('/Type /Catalog\n');
    write('/Pages ${_objectId + 1} 0 R\n');
    write('>>\nendobj\n\n');

    final catalogId = _objectId++;

    // 3. 写入Pages对象
    _objectOffsets[_objectId] = getCurrentLength();
    write('$_objectId 0 obj\n');
    write('<<\n');
    write('/Type /Pages\n');
    write('/Kids [');
    final pageIds = <int>[];
    for (var i = 0; i < imagePaths.length; i++) {
      pageIds.add(_objectId + 1 + i * 3);
      write('${_objectId + 1 + i * 3} 0 R ');
    }
    write(']\n');
    write('/Count ${imagePaths.length}\n');
    write('>>\nendobj\n\n');

    final pagesId = _objectId++;

    // 4. 为每个图片创建Page和Image对象
    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final image = await _getImage(imagePath);

      // 写入Page对象
      _objectOffsets[_objectId] = getCurrentLength();
      write('$_objectId 0 obj\n');
      write('<<\n');
      write('/Type /Page\n');
      write('/Parent $pagesId 0 R\n');
      write('/Resources <<\n');
      write('/XObject << /Im${i + 1} ${_objectId + 1} 0 R >>\n');
      write('>>\n');
      write('/MediaBox [0 0 $a4Width $a4Height]\n');
      write('/Contents ${_objectId + 2} 0 R\n');
      write('>>\nendobj\n\n');

      _objectId++;

      // 写入Image对象
      _objectOffsets[_objectId] = getCurrentLength();
      write('$_objectId 0 obj\n');
      write('<<\n');
      write('/Type /XObject\n');
      write('/Subtype /Image\n');
      write('/Width ${image.width}\n');
      write('/Height ${image.height}\n');
      write('/ColorSpace /DeviceRGB\n');
      write('/BitsPerComponent 8\n');
      write('/Filter /FlateDecode\n');
      write('/Length ${image.data.length}\n');
      write('>>\nstream\n');
      writeData(image.data);
      write('\nendstream\nendobj\n\n');

      _objectId++;

      // 写入Contents对象（绘制图片的指令）
      _objectOffsets[_objectId] = getCurrentLength();
      write('$_objectId 0 obj\n');
      write('<<\n');
      var stream = '';
      stream += 'q\n';
      // Calculate scaling factors
      var scaleX = a4Width / image.width;
      var scaleY = a4Height / image.height;
      var scale = scaleX < scaleY ? scaleX : scaleY;
      // Calculate centering offsets
      var offsetX = (a4Width - (image.width * scale)) / 2;
      var offsetY = (a4Height - (image.height * scale)) / 2;
      // Apply transformation matrix
      stream += '1 0 0 1 $offsetX $offsetY cm\n'; // Translate
      stream += '${scale * image.width} 0 0 ${scale * image.height} 0 0 cm\n';
      stream += '/Im${i + 1} Do\n';
      stream += 'Q\n';
      var streamData = utf8.encode(stream);
      write('/Length ${streamData.length}\n');
      write('>>\nstream\n');
      writeData(streamData);
      write('endstream\nendobj\n\n');

      _objectId++;
    }

    // 5. 写入Info对象（元数据）
    final infoId = _objectId;
    _objectOffsets[_objectId] = getCurrentLength();
    write('$_objectId 0 obj\n');
    write('<<\n');
    write('/Title <');
    writeData(_toPdfString(title));
    write('>\n');
    write('/Author <');
    writeData(_toPdfString(author));
    write('>\n');
    write('/Producer (venera v${App.version})\n');
    write('/CreationDate (D:${_formatDateTime(DateTime.now())})\n');
    write('>>\nendobj\n\n');

    _objectId++;

    // 6. 写入交叉引用表
    final xrefOffset = getCurrentLength();
    write('xref\n');
    write('0 $_objectId\n');
    write('0000000000 65535 f\r\n');

    for (var i = 1; i < _objectId; i++) {
      final offset = _objectOffsets[i]!;
      write('${offset.toString().padLeft(10, '0')} 00000 n\r\n'); // 使用\r\n
    }

    // 7. 写入文件尾部
    write('trailer\n');
    write('<<\n');
    write('/Size $_objectId\n');
    write('/Root $catalogId 0 R\n');
    write('/Info $infoId 0 R\n');
    write('>>\n');
    write('startxref\n');
    write('$xrefOffset\n');
    write('%%EOF\n');

    await output.close();
  }

  int _codeUnitForDigit(int digit) =>
      digit < 10 ? digit + 0x30 : digit + 0x61 - 10;

  Uint8List _toPdfString(String str) {
    Uint8List data;
    try {
      data = latin1.encode(str);
    } catch (e) {
      data = Uint8List.fromList(<int>[0xfe, 0xff] + _encodeUtf16be(str));
    }
    var result = <int>[];
    for (final byte in data) {
      result.add(_codeUnitForDigit((byte & 0xF0) >> 4));
      result.add(_codeUnitForDigit(byte & 0x0F));
    }
    return Uint8List.fromList(result);
  }

  List<int> _encodeUtf16be(String str) {
    const unicodeReplacementCharacterCodePoint = 0xfffd;
    const unicodeByteZeroMask = 0xff;
    const unicodeByteOneMask = 0xff00;
    const unicodeValidRangeMax = 0x10ffff;
    const unicodePlaneOneMax = 0xffff;
    const unicodeUtf16ReservedLo = 0xd800;
    const unicodeUtf16ReservedHi = 0xdfff;
    const unicodeUtf16Offset = 0x10000;
    const unicodeUtf16SurrogateUnit0Base = 0xd800;
    const unicodeUtf16SurrogateUnit1Base = 0xdc00;
    const unicodeUtf16HiMask = 0xffc00;
    const unicodeUtf16LoMask = 0x3ff;

    final encoding = <int>[];

    void add(int unit) {
      encoding.add((unit & unicodeByteOneMask) >> 8);
      encoding.add(unit & unicodeByteZeroMask);
    }

    for (final unit in str.codeUnits) {
      if ((unit >= 0 && unit < unicodeUtf16ReservedLo) ||
          (unit > unicodeUtf16ReservedHi && unit <= unicodePlaneOneMax)) {
        add(unit);
      } else if (unit > unicodePlaneOneMax && unit <= unicodeValidRangeMax) {
        final base = unit - unicodeUtf16Offset;
        add(unicodeUtf16SurrogateUnit0Base +
            ((base & unicodeUtf16HiMask) >> 10));
        add(unicodeUtf16SurrogateUnit1Base + (base & unicodeUtf16LoMask));
      } else {
        add(unicodeReplacementCharacterCodePoint);
      }
    }
    return encoding;
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dt) {
    return dt
        .toUtc()
        .toString()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .substring(0, 14);
  }

  Future<({int width, int height, Uint8List data})> _getImage(
      String imagePath) async {
    var data = await File(imagePath).readAsBytes();
    var image = await decodeImage(data);
    var width = image.width;
    var height = image.height;
    data = Uint8List(width * height * 3);
    for (var i = 0; i < width * height; i++) {
      var pixel = image.getPixelAtIndex(i);
      data[i * 3] = pixel.r;
      data[i * 3 + 1] = pixel.g;
      data[i * 3 + 2] = pixel.b;
    }
    data = tdeflCompressData(data, true, true, 9);
    return (width: width, height: height, data: data);
  }
}
