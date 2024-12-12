import 'dart:async';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/utils/translations.dart';

import 'app.dart';

typedef HistoryType = ComicType;

abstract mixin class HistoryMixin {
  String get title;

  String? get subTitle;

  String get cover;

  String get id;

  int? get maxPage => null;

  HistoryType get historyType;
}

class History implements Comic {
  HistoryType type;

  DateTime time;

  @override
  String title;

  @override
  String subtitle;

  @override
  String cover;
  
  int ep;

  int page;

  @override
  String id;

  /// readEpisode is a set of episode numbers that have been read.
  ///
  /// The number of episodes is 1-based.
  Set<int> readEpisode;

  @override
  int? maxPage;

  History.fromModel(
      {required HistoryMixin model,
      required this.ep,
      required this.page,
      Set<int>? readChapters,
      DateTime? time})
      : type = model.historyType,
        title = model.title,
        subtitle = model.subTitle ?? '',
        cover = model.cover,
        id = model.id,
        readEpisode = readChapters ?? <int>{},
        time = time ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        "type": type.value,
        "time": time.millisecondsSinceEpoch,
        "title": title,
        "subtitle": subtitle,
        "cover": cover,
        "ep": ep,
        "page": page,
        "id": id,
        "readEpisode": readEpisode.toList(),
        "max_page": maxPage
      };

  History.fromMap(Map<String, dynamic> map)
      : type = HistoryType(map["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(map["time"]),
        title = map["title"],
        subtitle = map["subtitle"],
        cover = map["cover"],
        ep = map["ep"],
        page = map["page"],
        id = map["id"],
        readEpisode = Set<int>.from(
            (map["readEpisode"] as List<dynamic>?)?.toSet() ?? const <int>{}),
        maxPage = map["max_page"];

  @override
  String toString() {
    return 'History{type: $type, time: $time, title: $title, subtitle: $subtitle, cover: $cover, ep: $ep, page: $page, id: $id}';
  }

  History.fromRow(Row row)
      : type = HistoryType(row["type"]),
        time = DateTime.fromMillisecondsSinceEpoch(row["time"]),
        title = row["title"],
        subtitle = row["subtitle"],
        cover = row["cover"],
        ep = row["ep"],
        page = row["page"],
        id = row["id"],
        readEpisode = Set<int>.from((row["readEpisode"] as String)
            .split(',')
            .where((element) => element != "")
            .map((e) => int.parse(e))),
        maxPage = row["max_page"];

  static Future<History> findOrCreate(
    HistoryMixin model, {
    int ep = 0,
    int page = 0,
  }) async {
    var history = await HistoryManager().find(model.id, model.historyType);
    if (history != null) {
      return history;
    }
    history = History.fromModel(model: model, ep: ep, page: page);
    HistoryManager().addHistory(history);
    return history;
  }

  static Future<History> createIfNull(
      History? history, HistoryMixin model) async {
    if (history != null) {
      return history;
    }
    history = History.fromModel(model: model, ep: 0, page: 0);
    HistoryManager().addHistory(history);
    return history;
  }

  @override
  bool operator ==(Object other) {
    return other is History && type == other.type && id == other.id;
  }

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String get description {
    var res = "";
    if (ep >= 1) {
      res += "Chapter @ep".tlParams({
        "ep": ep,
      });
    }
    if (page >= 1) {
      if (ep >= 1) {
        res += " - ";
      }
      res += "Page @page".tlParams({
        "page": page,
      });
    }
    return res;
  }

  @override
  String? get favoriteId => null;

  @override
  String? get language => null;

  @override
  String get sourceKey => type == ComicType.local
      ? 'local'
      : type.comicSource?.key ?? "Unknown:${type.value}";

  @override
  double? get stars => null;

  @override
  List<String>? get tags => null;

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}

class HistoryManager with ChangeNotifier {
  static HistoryManager? cache;

  HistoryManager.create();

  factory HistoryManager() =>
      cache == null ? (cache = HistoryManager.create()) : cache!;

  late Database _db;

  int get length => _db.select("select count(*) from history;").first[0] as int;

  Map<String, bool>? _cachedHistory;

  static const _kMaxHistoryLength = 200;

  Future<void> init() async {
    _db = sqlite3.open("${App.dataPath}/history.db");

    _db.execute("""
        create table if not exists history  (
          id text primary key,
          title text,
          subtitle text,
          cover text,
          time int,
          type int,
          ep int,
          page int,
          readEpisode text,
          max_page int
        );
      """);

    notifyListeners();
  }

  /// add history. if exists, update time.
  ///
  /// This function would be called when user start reading.
  Future<void> addHistory(History newItem) async {
    while(count() >= _kMaxHistoryLength) {
      _db.execute("""
        delete from history
        where time == (select min(time) from history);
      """);
    }
    _db.execute("""
        insert or replace into history (id, title, subtitle, cover, time, type, ep, page, readEpisode, max_page)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """, [
      newItem.id,
      newItem.title,
      newItem.subtitle,
      newItem.cover,
      newItem.time.millisecondsSinceEpoch,
      newItem.type.value,
      newItem.ep,
      newItem.page,
      newItem.readEpisode.join(','),
      newItem.maxPage
    ]);
    updateCache();
    notifyListeners();
  }

  void clearHistory() {
    _db.execute("delete from history;");
    updateCache();
    notifyListeners();
  }

  void remove(String id, ComicType type) async {
    _db.execute("""
      delete from history
      where id == ? and type == ?;
    """, [id, type.value]);
    updateCache();
    notifyListeners();
  }

  Future<History?> find(String id, ComicType type) async {
    return findSync(id, type);
  }

  void updateCache() {
    _cachedHistory = {};
    var res = _db.select("""
        select * from history;
      """);
    for (var element in res) {
      _cachedHistory![element["id"] as String] = true;
    }
  }

  History? findSync(String id, ComicType type) {
    if(_cachedHistory == null) {
      updateCache();
    }
    if (!_cachedHistory!.containsKey(id)) {
      return null;
    }

    var res = _db.select("""
      select * from history
      where id == ? and type == ?;
    """, [id, type.value]);
    if (res.isEmpty) {
      return null;
    }
    return History.fromRow(res.first);
  }

  List<History> getAll() {
    var res = _db.select("""
      select * from history
      order by time DESC;
    """);
    return res.map((element) => History.fromRow(element)).toList();
  }

  /// 获取最近阅读的漫画
  List<History> getRecent() {
    var res = _db.select("""
      select * from history
      order by time DESC
      limit 20;
    """);
    return res.map((element) => History.fromRow(element)).toList();
  }

  /// 获取历史记录的数量
  int count() {
    var res = _db.select("""
      select count(*) from history;
    """);
    return res.first[0] as int;
  }

  void close() {
    _db.dispose();
  }
}
