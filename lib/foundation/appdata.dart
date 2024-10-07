import 'dart:convert';

import 'package:venera/foundation/app.dart';
import 'package:venera/utils/io.dart';

class _Appdata {
  final _Settings settings = _Settings();

  var searchHistory = <String>[];
  
  void saveData() async {
    var data = jsonEncode(toJson());
    var file = File(FilePath.join(App.dataPath, 'appdata.json'));
    await file.writeAsString(data);
  }

  void addSearchHistory(String keyword) {
    if(searchHistory.contains(keyword)) {
      searchHistory.remove(keyword);
    }
    searchHistory.insert(0, keyword);
    if(searchHistory.length > 50) {
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
    var file = File(FilePath.join(App.dataPath, 'appdata.json'));
    if(!await file.exists()) {
      return;
    }
    var json = jsonDecode(await file.readAsString());
    for(var key in json['settings'].keys) {
      settings[key] = json[key];
    }
    searchHistory = List.from(json['searchHistory']);
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings._data,
      'searchHistory': searchHistory,
    };
  }
}

final appdata = _Appdata();

class _Settings {
  _Settings();

  final _data = <String, dynamic>{
    'comicDisplayMode': 'detailed', // detailed, brief
    'comicTileScale': 1.0, // 0.8-1.2
    'color': 'blue', // red, pink, purple, green, orange, blue
    'theme_mode': 'system', // light, dark, system
    'newFavoriteAddTo': 'end', // start, end
    'moveFavoriteAfterRead': 'none', // none, end, start
    'proxy': 'direct', // direct, system, proxy string
    'explore_pages': [],
    'categories': [],
    'favorites': [],
    'showFavoriteStatusOnTile': true,
    'showHistoryStatusOnTile': false,
    'blockedWords': [],
    'defaultSearchTarget': null,
    'autoPageTurningInterval': 5, // in seconds
    'readerMode': 'galleryLeftToRight', // values of [ReaderMode]
    'enableTapToTurnPages': true,
    'enablePageAnimation': true,
  };

  operator[](String key) {
    return _data[key];
  }

  operator[]=(String key, dynamic value) {
    _data[key] = value;
  }
}