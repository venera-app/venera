import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/utils/ext.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart' as s;

export 'dart:io';

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
}

String sanitizeFileName(String fileName) {
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

String findValidDirectoryName(String path, String directory) {
  var name = sanitizeFileName(directory);
  var dir = Directory("$path/$name");
  var i = 1;
  while (dir.existsSync()) {
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
      var d = await FilePicker.platform.getDirectoryPath();
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

Future<void> saveFile(
    {required Uint8List data, required String filename}) async {
  var res = await FilePicker.platform.saveFile(
    bytes: data,
    fileName: filename,
    lockParentWindow: true,
  );
  if (App.isDesktop && res != null) {
    await File(res).writeAsBytes(data);
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
      var file = File(FilePath.join(Directory.systemTemp.path, filename));
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
