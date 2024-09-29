class _Appdata {
  final _Settings settings = _Settings();
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
  };

  operator[](String key) {
    return _data[key];
  }
}