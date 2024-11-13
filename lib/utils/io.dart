import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/utils/ext.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart' as s;
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:venera/utils/file_type.dart';

export 'dart:io';
export 'dart:typed_data';

class FilePath {
  const FilePath._();

  static String join(String path1, String path2,
      [String? path3, String? path4, String? path5]) {
    return p.join(path1, path2, path3, path4, path5);
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  String get name {
    var path = this.path;
    if (path.endsWith('/') || path.endsWith('\\')) {
      path = path.substring(0, path.length - 1);
    }

    int i = path.length - 1;

    while (i >= 0 && path[i] != '\\' && path[i] != '/') {
      i--;
    }

    return path.substring(i + 1);
  }

  Future<void> deleteIgnoreError({bool recursive = false}) async {
    try {
      await delete(recursive: recursive);
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteIfExists({bool recursive = false}) async {
    if (existsSync()) {
      await delete(recursive: recursive);
    }
  }

  void deleteIfExistsSync({bool recursive = false}) {
    if (existsSync()) {
      deleteSync(recursive: recursive);
    }
  }
}

extension FileExtension on File {
  String get extension => path.split('.').last;
}

extension DirectoryExtension on Directory {
  Future<int> get size async {
    if (!existsSync()) return 0;
    int total = 0;
    for (var f in listSync(recursive: true)) {
      if (FileSystemEntity.typeSync(f.path) == FileSystemEntityType.file) {
        total += await File(f.path).length();
      }
    }
    return total;
  }

  Directory renameX(String newName) {
    newName = sanitizeFileName(newName);
    return renameSync(path.replaceLast(name, newName));
  }

  File joinFile(String name) {
    return File(FilePath.join(path, name));
  }
}

String sanitizeFileName(String fileName) {
  if (fileName.endsWith('.')) {
    fileName = fileName.substring(0, fileName.length - 1);
  }
  const maxLength = 255;
  final invalidChars = RegExp(r'[<>:"/\\|?*]');
  final sanitizedFileName = fileName.replaceAll(invalidChars, ' ');
  var trimmedFileName = sanitizedFileName.trim();
  if (trimmedFileName.isEmpty) {
    throw Exception('Invalid File Name: Empty length.');
  }
  while (true) {
    final bytes = utf8.encode(trimmedFileName);
    if (bytes.length > maxLength) {
      trimmedFileName =
          trimmedFileName.substring(0, trimmedFileName.length - 1);
    } else {
      break;
    }
  }
  return trimmedFileName;
}

/// Copy the **contents** of the source directory to the destination directory.
Future<void> copyDirectory(Directory source, Directory destination) async {
  List<FileSystemEntity> contents = source.listSync();
  for (FileSystemEntity content in contents) {
    String newPath = destination.path +
        Platform.pathSeparator +
        content.path.split(Platform.pathSeparator).last;

    if (content is File) {
      content.copySync(newPath);
    } else if (content is Directory) {
      Directory newDirectory = Directory(newPath);
      newDirectory.createSync();
      copyDirectory(content.absolute, newDirectory.absolute);
    }
  }
}

Future<void> copyDirectoryIsolate(
    Directory source, Directory destination) async {
  await Isolate.run(() {
    copyDirectory(source, destination);
  });
}

String findValidDirectoryName(String path, String directory) {
  var name = sanitizeFileName(directory);
  var dir = Directory("$path/$name");
  var i = 1;
  while (dir.existsSync() && dir.listSync().isNotEmpty) {
    name = sanitizeFileName("$directory($i)");
    dir = Directory("$path/$name");
    i++;
  }
  return name;
}

class DirectoryPicker {
  String? _directory;

  final _methodChannel = const MethodChannel("venera/method_channel");

  Future<Directory?> pickDirectory() async {
    if (App.isWindows || App.isLinux) {
      var d = await file_selector.getDirectoryPath();
      _directory = d;
      return d == null ? null : Directory(d);
    } else if (App.isAndroid) {
      var d = await _methodChannel.invokeMethod<String?>("getDirectoryPath");
      _directory = d;
      return d == null ? null : Directory(d);
    } else {
      // ios, macos
      var d = await _methodChannel.invokeMethod<String?>("getDirectoryPath");
      _directory = d;
      return d == null ? null : Directory(d);
    }
  }

  Future<void> dispose() async {
    if (_directory == null) {
      return;
    }
    if (App.isAndroid && _directory != null) {
      return Directory(_directory!).deleteIgnoreError(recursive: true);
    }
    if (App.isIOS || App.isMacOS) {
      await _methodChannel.invokeMethod("stopAccessingSecurityScopedResource");
    }
  }
}

class IOSDirectoryPicker {
  static const MethodChannel _channel = MethodChannel("venera/method_channel");

  // 调用 iOS 目录选择方法
  static Future<String?> selectDirectory() async {
    try {
      final String? path = await _channel.invokeMethod('selectDirectory');
      return path;
    } catch (e) {
      print("Error selecting directory: $e");
      // 返回报错信息
      return e.toString();
    }
  }
}

Future<file_selector.XFile?> selectFile({required List<String> ext}) async {
  var extensions = App.isMacOS || App.isIOS ? null : ext;
  if (App.isAndroid) {
    for (var e in ext) {
      var fileType = FileType.fromExtension(e);
      if (fileType.mime == "application/octet-stream") {
        extensions = null;
        break;
      }
    }
  }
  file_selector.XTypeGroup typeGroup = file_selector.XTypeGroup(
    label: 'files',
    extensions: extensions,
  );
  file_selector.XFile? file;
  if (extensions == null && App.isAndroid) {
    const selectFileChannel = MethodChannel("venera/select_file");
    var filePath = await selectFileChannel.invokeMethod("selectFile");
    if (filePath == null) return null;
    file = file_selector.XFile(filePath);
  } else {
    file = await file_selector.openFile(
      acceptedTypeGroups: <file_selector.XTypeGroup>[typeGroup],
    );
    if (file == null) return null;
  }
  if (!ext.contains(file.path.split(".").last)) {
    App.rootContext.showMessage(message: "Invalid file type");
    return null;
  }
  return file;
}

Future<String?> selectDirectory() async {
  var path = await file_selector.getDirectoryPath();
  return path;
}

// selectDirectoryIOS
Future<String?> selectDirectoryIOS() async {
  return IOSDirectoryPicker.selectDirectory();
}

Future<void> saveFile(
    {Uint8List? data, required String filename, File? file}) async {
  if (data == null && file == null) {
    throw Exception("data and file cannot be null at the same time");
  }
  if (data != null) {
    var cache = FilePath.join(App.cachePath, filename);
    if (File(cache).existsSync()) {
      File(cache).deleteSync();
    }
    await File(cache).writeAsBytes(data);
    file = File(cache);
  }
  if (App.isMobile) {
    final params = SaveFileDialogParams(sourceFilePath: file!.path);
    await FlutterFileDialog.saveFile(params: params);
  } else {
    final result = await file_selector.getSaveLocation(
      suggestedName: filename,
    );
    if (result != null) {
      var xFile = file_selector.XFile(file!.path);
      await xFile.saveTo(result.path);
    }
  }
}

class Share {
  static void shareFile({
    required Uint8List data,
    required String filename,
    required String mime,
  }) {
    if (!App.isWindows) {
      s.Share.shareXFiles(
        [s.XFile.fromData(data, mimeType: mime)],
        fileNameOverrides: [filename],
      );
    } else {
      // write to cache
      var file = File(FilePath.join(App.cachePath, filename));
      file.writeAsBytesSync(data);
      s.Share.shareXFiles([s.XFile(file.path)]);
    }
  }

  static void shareText(String text) {
    s.Share.share(text);
  }
}

String bytesToReadableString(int bytes) {
  if (bytes < 1024) {
    return "$bytes B";
  } else if (bytes < 1024 * 1024) {
    return "${(bytes / 1024).toStringAsFixed(2)} KB";
  } else if (bytes < 1024 * 1024 * 1024) {
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  } else {
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
