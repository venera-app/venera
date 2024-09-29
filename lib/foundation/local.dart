import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/comic_type.dart';

import 'app.dart';

class LocalComic {
  final int id;

  final String title;

  final String subtitle;

  final List<String> tags;

  /// name of the directory, which is in `LocalManager.path`
  final String directory;

  /// key: chapter id, value: chapter title
  ///
  /// chapter id is the name of the directory in `LocalManager.path/$directory`
  final Map<String, String>? chapters;

  /// relative path to the cover image
  final String cover;

  final ComicType comicType;

  final DateTime createdAt;

  const LocalComic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.directory,
    required this.chapters,
    required this.cover,
    required this.comicType,
    required this.createdAt,
  });

  LocalComic.fromRow(Row row)
      : id = row[0] as int,
        title = row[1] as String,
        subtitle = row[2] as String,
        tags = List.from(jsonDecode(row[3] as String)),
        directory = row[4] as String,
        chapters = Map.from(jsonDecode(row[5] as String)),
        cover = row[6] as String,
        comicType = ComicType(row[7] as int),
        createdAt = DateTime.fromMillisecondsSinceEpoch(row[8] as int);

  File get coverFile => File('${LocalManager().path}/$directory/$cover');
}

class LocalManager with ChangeNotifier {
  static LocalManager? _instance;

  LocalManager._();

  factory LocalManager() {
    return _instance ??= LocalManager._();
  }

  late Database _db;

  late String path;

  Future<void> init() async {
    _db = sqlite3.open(
      '${App.dataPath}/local.db',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS comics (
        id INTEGER,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        tags TEXT NOT NULL,
        directory TEXT NOT NULL,
        chapters TEXT NOT NULL,
        cover TEXT NOT NULL,
        comic_type INTEGER NOT NULL,
        created_at INTEGER,
        PRIMARY KEY (id, comic_type)
      );
    ''');
    if(File('${App.dataPath}/local_path').existsSync()){
      path = File('${App.dataPath}/local_path').readAsStringSync();
    } else {
      if(App.isAndroid) {
        var external = await getExternalStorageDirectories();
        if(external != null && external.isNotEmpty){
          path = '${external.first.path}/local';
        } else {
          path = '${App.dataPath}/local';
        }
      } else {
        path = '${App.dataPath}/local';
      }
    }
    if(!Directory(path).existsSync()) {
      await Directory(path).create();
    }
  }

  int findValidId(ComicType type) {
    final res = _db.select(
      'SELECT id FROM comics WHERE comic_type = ? ORDER BY id DESC LIMIT 1;',
      [type.value],
    );
    if (res.isEmpty) {
      return 1;
    }
    return (res.first[0] as int) + 1;
  }

  Future<void> add(LocalComic comic, [int? id]) async {
    _db.execute(
      'INSERT INTO comics VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        id ?? comic.id,
        comic.title,
        comic.subtitle,
        jsonEncode(comic.tags),
        comic.directory,
        jsonEncode(comic.chapters),
        comic.cover,
        comic.comicType.value,
        comic.createdAt.millisecondsSinceEpoch,
      ],
    );
    notifyListeners();
  }

  void remove(int id, ComicType comicType) async {
    _db.execute(
      'DELETE FROM comics WHERE id = ? AND comic_type = ?;',
      [id, comicType.value],
    );
    notifyListeners();
  }

  void removeComic(LocalComic comic) {
    remove(comic.id, comic.comicType);
    notifyListeners();
  }

  List<LocalComic> getComics() {
    final res = _db.select('SELECT * FROM comics;');
    return res.map((row) => LocalComic.fromRow(row)).toList();
  }

  LocalComic? find(int id, ComicType comicType) {
    final res = _db.select(
      'SELECT * FROM comics WHERE id = ? AND comic_type = ?;',
      [id, comicType.value],
    );
    if (res.isEmpty) {
      return null;
    }
    return LocalComic.fromRow(res.first);
  }

  @override
  void dispose() {
    super.dispose();
    _db.dispose();
  }

  List<LocalComic> getRecent() {
    final res = _db.select('''
      SELECT * FROM comics
      ORDER BY created_at DESC
      LIMIT 20;
    ''');
    return res.map((row) => LocalComic.fromRow(row)).toList();
  }

  int get count {
    final res = _db.select('''
      SELECT COUNT(*) FROM comics;
    ''');
    return res.first[0] as int;
  }

  LocalComic? findByName(String name) {
    final res = _db.select('''
      SELECT * FROM comics 
      WHERE title = ? OR directory = ?;
    ''', [name, name]);
    if (res.isEmpty) {
      return null;
    }
    return LocalComic.fromRow(res.first);
  }
}