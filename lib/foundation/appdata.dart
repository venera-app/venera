import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/io.dart';

class _Appdata {
  final _Settings settings = _Settings();

  var searchHistory = <String>[];

  bool _isSavingData = false;

  Future<void> saveData([bool sync = true]) async {
    if (_isSavingData) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 20));
        return _isSavingData;
      });
    }
    _isSavingData = true;
    var data = jsonEncode(toJson());
    var file = File(FilePath.join(App.dataPath, 'appdata.json'));
    await file.writeAsString(data);
    _isSavingData = false;
    if (sync) {
      DataSync().uploadData();
    }
  }

  void addSearchHistory(String keyword) {
    if (searchHistory.contains(keyword)) {
      searchHistory.remove(keyword);
    }
    searchHistory.insert(0, keyword);
    if (searchHistory.length > 50) {
      searchHistory.removeLast();
    }
    saveData();
  }

  void removeSearchHistory(String keyword) {
    searchHistory.remove(keyword);
    saveData();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    saveData();
  }

  Future<void> init() async {
    var dataPath = (await getApplicationSupportDirectory()).path;
    var file = File(FilePath.join(
      dataPath,
      'appdata.json',
    ));
    if (!await file.exists()) {
      return;
    }
    var json = jsonDecode(await file.readAsString());
    for (var key in (json['settings'] as Map<String, dynamic>).keys) {
      if (json['settings'][key] != null) {
        settings[key] = json['settings'][key];
      }
    }
    searchHistory = List.from(json['searchHistory']);
    var implicitDataFile = File(FilePath.join(dataPath, 'implicitData.json'));
    if (await implicitDataFile.exists()) {
      implicitData = jsonDecode(await implicitDataFile.readAsString());
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings._data,
      'searchHistory': searchHistory,
    };
  }

  /// Following fields are related to device-specific data and should not be synced.
  static const _disableSync = [
    "proxy",
    "authorizationRequired",
    "customImageProcessing",
  ];

  /// Sync data from another device
  void syncData(Map<String, dynamic> data) {
    for (var key in data.keys) {
      if (_disableSync.contains(key)) {
        continue;
      }
      settings[key] = data[key];
    }
    searchHistory = List.from(data['searchHistory']);
    saveData();
  }

  var implicitData = <String, dynamic>{};

  void writeImplicitData() {
    var file = File(FilePath.join(App.dataPath, 'implicitData.json'));
    file.writeAsString(jsonEncode(implicitData));
  }
}

final appdata = _Appdata();

class _Settings with ChangeNotifier {
  _Settings();

  final _data = <String, dynamic>{
    'comicDisplayMode': 'detailed', // detailed, brief
    'comicTileScale': 1.00, // 0.75-1.25
    'color': 'system', // red, pink, purple, green, orange, blue
    'theme_mode': 'system', // light, dark, system
    'newFavoriteAddTo': 'end', // start, end
    'moveFavoriteAfterRead': 'none', // none, end, start
    'proxy': 'system', // direct, system, proxy string
    'explore_pages': [],
    'categories': [],
    'favorites': [],
    'showFavoriteStatusOnTile': true,
    'showHistoryStatusOnTile': false,
    'blockedWords': [],
    'defaultSearchTarget': null,
    'autoPageTurningInterval': 5, // in seconds
    'readerMode': 'galleryLeftToRight', // values of [ReaderMode]
    'readerScreenPicNumber': 1, // 1 - 5
    'enableTapToTurnPages': true,
    'enablePageAnimation': true,
    'language': 'system', // system, zh-CN, zh-TW, en-US
    'cacheSize': 2048, // in MB
    'downloadThreads': 5,
    'enableLongPressToZoom': true,
    'checkUpdateOnStart': true,
    'limitImageWidth': true,
    'webdav': [], // empty means not configured
    'dataVersion': 0,
    'quickFavorite': null,
    'enableTurnPageByVolumeKey': true,
    'enableClockAndBatteryInfoInReader': true,
    'ignoreCertificateErrors': false,
    'supportSwipeToFavorite': 'yes', // yes, no
    'authorizationRequired': false,
    'onClickFavorite': 'viewDetail', // viewDetail, read
    'enableDnsOverrides': false,
    'dnsOverrides': {},
    'enableCustomImageProcessing': false,
    'customImageProcessing': _defaultCustomImageProcessing,
    'sni': true,
    'autoAddLanguageFilter': 'none', // none, chinese, english, japanese
  };

  operator [](String key) {
    return _data[key];
  }

  operator []=(String key, dynamic value) {
    _data[key] = value;
    notifyListeners();
  }

  @override
  String toString() {
    return _data.toString();
  }
}

const _defaultCustomImageProcessing = '''
/**
 * Process an image
 * @param image {ArayBuffer} - The image to process
 * @param cid {string} - The comic ID
 * @param eid {string} - The episode ID
 * @returns {Promise<ArrayBuffer>} - The processed image
 */
async function processImage(image, cid, eid) {
    return image;
}
''';
