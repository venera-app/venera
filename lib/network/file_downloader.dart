import 'dart:async';
import 'dart:io';

import 'package:dio/io.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/network/proxy.dart';
import 'package:venera/utils/ext.dart';

class FileDownloader {
  final String url;
  final String savePath;
  final int maxConcurrent;

  FileDownloader(this.url, this.savePath, {this.maxConcurrent = 4});

  int _currentBytes = 0;

  int _lastBytes = 0;

  late int _fileSize;

  final _dio = Dio();

  RandomAccessFile? _file;

  bool _isWriting = false;

  int _kChunkSize = 16 * 1024 * 1024;

  bool _canceled = false;

  late List<_DownloadBlock> _blocks;

  Future<void> _writeStatus() async {
    var file = File("$savePath.download");
    await file.writeAsString(_blocks.map((e) => e.toString()).join("\n"));
  }

  Future<void> _readStatus() async {
    var file = File("$savePath.download");
    if (!await file.exists()) {
      return;
    }

    var lines = await file.readAsLines();
    _blocks = lines.map((e) => _DownloadBlock.fromString(e)).toList();
  }

  /// create file and write empty bytes
  Future<void> _prepareFile() async {
    var file = File(savePath);
    if (await file.exists()) {
      if (file.lengthSync() == _fileSize &&
          File("$savePath.download").existsSync()) {
        _file = await file.open(mode: FileMode.append);
        return;
      } else {
        await file.delete();
      }
    }

    await file.create(recursive: true);
    _file = await file.open(mode: FileMode.append);
    await _file!.truncate(_fileSize);
  }

  Future<void> _createTasks() async {
    var res = await _dio.head(url);
    var length = res.headers["content-length"]?.first;
    _fileSize = length == null ? 0 : int.parse(length);

    await _prepareFile();

    if (File("$savePath.download").existsSync()) {
      await _readStatus();
      _currentBytes = _blocks.fold<int>(0,
          (previousValue, element) => previousValue + element.downloadedBytes);
    } else {
      if (_fileSize > 1024 * 1024 * 1024) {
        _kChunkSize = 64 * 1024 * 1024;
      } else if (_fileSize > 512 * 1024 * 1024) {
        _kChunkSize = 32 * 1024 * 1024;
      }

      _blocks = [];
      for (var i = 0; i < _fileSize; i += _kChunkSize) {
        var end = i + _kChunkSize;
        if (end > _fileSize) {
          _blocks.add(_DownloadBlock(i, _fileSize, 0, false));
        } else {
          _blocks.add(_DownloadBlock(i, i + _kChunkSize, 0, false));
        }
      }
    }
  }

  Stream<DownloadingStatus> start() {
    var stream = StreamController<DownloadingStatus>();
    _download(stream);
    return stream.stream;
  }

  void _reportStatus(StreamController<DownloadingStatus> stream) {
    stream.add(DownloadingStatus(_currentBytes, _fileSize, 0));
  }

  void _download(StreamController<DownloadingStatus> resultStream) async {
    try {
      var proxy = await getProxy();
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          return HttpClient()
            ..findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
        },
      );

      // get file size
      await _createTasks();

      if (_canceled) return;

      // check if file is downloaded
      if (_currentBytes >= _fileSize) {
        await _file!.close();
        _file = null;
        _reportStatus(resultStream);
        resultStream.close();
        return;
      }

      _reportStatus(resultStream);

      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_canceled || _currentBytes >= _fileSize) {
          timer.cancel();
          return;
        }
        resultStream.add(DownloadingStatus(
            _currentBytes, _fileSize, _currentBytes - _lastBytes));
        _lastBytes = _currentBytes;
      });

      // start downloading
      await _scheduleDownload();
      if (_canceled) {
        resultStream.close();
        return;
      }
      await _file!.close();
      _file = null;
      await File("$savePath.download").delete();

      // check if download is finished
      if (_currentBytes < _fileSize) {
        resultStream
            .addError(Exception("Download failed: Expected $_fileSize bytes, "
                "but only $_currentBytes bytes downloaded."));
        resultStream.close();
      }

      resultStream.add(DownloadingStatus(_currentBytes, _fileSize, 0, true));
      resultStream.close();
    } catch (e, s) {
      await _file?.close();
      _file = null;
      resultStream.addError(e, s);
      resultStream.close();
    }
  }

  Future<void> _scheduleDownload() async {
    var tasks = <Future>[];
    while (true) {
      if (_canceled) return;
      if (tasks.length >= maxConcurrent) {
        await Future.any(tasks);
      }
      final block = _blocks.firstWhereOrNull((element) =>
          !element.downloading &&
          element.end - element.start > element.downloadedBytes);
      if (block == null) {
        break;
      }
      block.downloading = true;
      var task = _fetchBlock(block);
      task.then((value) => tasks.remove(task), onError: (e) {
        if(_canceled) return;
        throw e;
      });
      tasks.add(task);
    }
    await Future.wait(tasks);
  }

  Future<void> _fetchBlock(_DownloadBlock block) async {
    final start = block.start;
    final end = block.end;

    if (start > _fileSize) {
      return;
    }

    var options = Options(
      responseType: ResponseType.stream,
      headers: {
        "Range": "bytes=${start + block.downloadedBytes}-${end - 1}",
        "Accept": "*/*",
        "Accept-Encoding": "deflate, gzip",
      },
      preserveHeaderCase: true,
    );
    var res = await _dio.get<ResponseBody>(url, options: options);
    if (_canceled) return;
    if (res.data == null) {
      throw Exception("Failed to block $start-$end");
    }

    var buffer = <int>[];
    await for (var data in res.data!.stream) {
      if (_canceled) return;
      buffer.addAll(data);
      if (buffer.length > 16 * 1024) {
        if (_isWriting) continue;
        _currentBytes += buffer.length;
        _isWriting = true;
        await _file!.setPosition(start + block.downloadedBytes);
        await _file!.writeFrom(buffer);
        block.downloadedBytes += buffer.length;
        buffer.clear();
        await _writeStatus();
        _isWriting = false;
      }
    }

    if (buffer.isNotEmpty) {
      while (_isWriting) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      _isWriting = true;
      _currentBytes += buffer.length;
      await _file!.setPosition(start + block.downloadedBytes);
      await _file!.writeFrom(buffer);
      block.downloadedBytes += buffer.length;
      await _writeStatus();
      _isWriting = false;
    }

    block.downloading = false;
  }

  Future<void> stop() async {
    _canceled = true;
    await _file?.close();
    _file = null;
  }
}

class DownloadingStatus {
  /// The current downloaded bytes
  final int downloadedBytes;

  /// The total bytes of the file
  final int totalBytes;

  /// Whether the download is finished
  final bool isFinished;

  /// The download speed in bytes per second
  final int bytesPerSecond;

  const DownloadingStatus(
      this.downloadedBytes, this.totalBytes, this.bytesPerSecond,
      [this.isFinished = false]);

  @override
  String toString() {
    return "Downloaded: $downloadedBytes/$totalBytes ${isFinished ? "Finished" : ""}";
  }
}

class _DownloadBlock {
  final int start;
  final int end;
  int downloadedBytes;
  bool downloading;

  _DownloadBlock(this.start, this.end, this.downloadedBytes, this.downloading);

  @override
  String toString() {
    return "$start-$end-$downloadedBytes";
  }

  _DownloadBlock.fromString(String str)
      : start = int.parse(str.split("-")[0]),
        end = int.parse(str.split("-")[1]),
        downloadedBytes = int.parse(str.split("-")[2]),
        downloading = false;
}
