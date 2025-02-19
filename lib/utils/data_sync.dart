import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/utils/data.dart';
import 'package:venera/utils/ext.dart';
import 'package:webdav_client/webdav_client.dart' hide File;

import 'io.dart';

class DataSync with ChangeNotifier {
  DataSync._() {
    if (isEnabled) {
      downloadData();
    }
    LocalFavoritesManager().addListener(onDataChanged);
    ComicSource.addListener(onDataChanged);
  }

  void onDataChanged() {
    if (isEnabled) {
      uploadData();
    }
  }

  static DataSync? instance;

  factory DataSync() => instance ?? (instance = DataSync._());

  bool isDownloading = false;

  bool isUploading = false;

  bool haveWaitingTask = false;

  bool get isEnabled {
    var config = appdata.settings['webdav'];
    var autoSync = appdata.settings['webdavAutoSync'] ?? false;
    return autoSync && config is List && config.isNotEmpty;
  }

  List<String>? _validateConfig() {
    var config = appdata.settings['webdav'];
    if (config is! List) {
      return null;
    }
    if (config.isEmpty) {
      return [];
    }
    if (config.length != 3 || config.whereType<String>().length != 3) {
      return null;
    }
    return List.from(config);
  }

  Future<Res<bool>> uploadData({bool forceSync = false}) async {
    if (isDownloading) return const Res(true);
    if (haveWaitingTask) return const Res(true);
    while (isUploading) {
      haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    haveWaitingTask = false;
    isUploading = true;
    notifyListeners();
    try {
      var config = _validateConfig();
      if (config == null) {
        return const Res.error('Invalid WebDAV configuration');
      }
      if (config.isEmpty) {
        return const Res(true);
      }
      String url = config[0];
      String user = config[1];
      String pass = config[2];

      var proxy = await AppDio.getProxy();

      var client = newClient(
        url,
        user: user,
        password: pass,
        adapter: IOHttpClientAdapter(
          createHttpClient: () {
            return HttpClient()
              ..findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
          },
        ),
      );

      try {
        await client.ping();
      } catch (e) {
        Log.error("Upload Data", 'Failed to connect to WebDAV server');
        return const Res.error('Failed to connect to WebDAV server');
      }

      try {
        var files = await client.readDir('/');
        files = files.where((e) => e.name!.endsWith('.venera')).toList();
        files.sort((a, b) => b.name!.compareTo(a.name!));
        var remoteFile = files.firstWhereOrNull((e) => e.name!.endsWith('.venera'));
        var remoteVersion = 0;
        if (remoteFile != null) {
          remoteVersion = int.tryParse(remoteFile.name!.split('-').elementAtOrNull(1)?.split('.').first ?? '0') ?? 0;
        }
        var localVersion = appdata.settings['dataVersion'] ?? 0;

        if (!forceSync && remoteVersion >= localVersion) {
          Log.info("Data Sync", 'Local: $localVersion Remote: $remoteVersion Skip upload ForceSync: $forceSync');
          return const Res(true);
        }

        appdata.settings['dataVersion'] = forceSync ? remoteVersion + 1 : localVersion + 1;
        await appdata.saveData(false);
        var data = await exportAppData();
        var time = (DateTime.now().millisecondsSinceEpoch ~/ 86400000).toString();
        var filename = '$time-${appdata.settings['dataVersion']}.venera';
        
        if (!forceSync) {
          var old = files.firstWhereOrNull((e) => e.name!.startsWith("$time-"));
          if (old != null) {
            await client.remove(old.name!);
          }
        }
        if (files.length >= 10) {
          files.sort((a, b) => a.name!.compareTo(b.name!));
          await client.remove(files.first.name!);
        }
        await client.write(filename, await data.readAsBytes());
        data.deleteIgnoreError();
        Log.info("Data Sync", "Local: ${appdata.settings['dataVersion']} Remote: $remoteVersion Data uploaded successfully ForceSync: $forceSync");
        return const Res(true);
      } catch (e, s) {
        Log.error("Upload Data", e, s);
        return Res.error(e.toString());
      }
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Future<Res<bool>> downloadData({bool forceSync = false}) async {
    if (haveWaitingTask) return const Res(true);
    while (isDownloading || isUploading) {
      haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    haveWaitingTask = false;
    isDownloading = true;
    notifyListeners();
    try {
      var config = _validateConfig();
      if (config == null) {
        return const Res.error('Invalid WebDAV configuration');
      }
      if (config.isEmpty) {
        return const Res(true);
      }
      String url = config[0];
      String user = config[1];
      String pass = config[2];

      var proxy = await AppDio.getProxy();

      var client = newClient(
        url,
        user: user,
        password: pass,
        adapter: IOHttpClientAdapter(
          createHttpClient: () {
            return HttpClient()
              ..findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
          },
        ),
      );

      try {
        await client.ping();
      } catch (e) {
        Log.error("Data Sync", 'Failed to connect to WebDAV server');
        return const Res.error('Failed to connect to WebDAV server');
      }

      try {
        var files = await client.readDir('/');
        files.sort((a, b) => b.name!.compareTo(a.name!));
        var file = files.firstWhereOrNull((e) => e.name!.endsWith('.venera'));
        if (file == null) {
          throw 'No data file found';
        }
        var version = file.name!.split('-').elementAtOrNull(1)?.split('.').first;
        var remoteVersion = int.tryParse(version ?? '') ?? 0;
        var localVersion = appdata.settings['dataVersion'] ?? 0;

        if (!forceSync && remoteVersion <= localVersion) {
          Log.info("Data Sync", 'Local: $localVersion Remote: $remoteVersion Skip download ForceSync: $forceSync');
          return const Res(true);
        }

        Log.info("Data Sync", "Local: $localVersion Remote: $remoteVersion Downloading data ForceSync: $forceSync");
        var localFile = File(FilePath.join(App.cachePath, file.name!));
        await client.read2File(file.name!, localFile.path);
        await importAppData(localFile, true);
        await localFile.delete();
        Log.info("Data Sync", "Data downloaded successfully");
        return const Res(true);
      } catch (e, s) {
        Log.error("Data Sync", e, s);
        return Res.error(e.toString());
      }
    } finally {
      isDownloading = false;
      notifyListeners();
    }
  }
}
