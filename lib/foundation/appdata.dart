import 'dart:convert';

import 'package:venera/foundation/app.dart';
import 'package:venera/utils/io.dart';

class _Appdata {
  final _Settings settings = _Settings();
  
  void saveSettings() async {
    var data = jsonEncode(settings._data);
    var file = File(FilePath.join(App.dataPath, 'settings.json'));
    await file.writeAsString(data);
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
  };

  operator[](String key) {
    return _data[key];
  }

  operator[]=(String key, dynamic value) {
    _data[key] = value;
  }
}