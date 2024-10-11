import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/utils/io.dart';

import 'app.dart';

class LocalComic implements Comic {
  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final List<String> tags;

  /// name of the directory, which is in `LocalManager.path`
  final String directory;

  /// key: chapter id, value: chapter title
  ///
  /// chapter id is the name of the directory in `LocalManager.path/$directory`
  final Map<String, String>? chapters;

  /// relative path to the cover image
  @override
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
      : id = row[0] as String,
        title = row[1] as String,
        subtitle = row[2] as String,
        tags = List.from(jsonDecode(row[3] as String)),
        directory = row[4] as String,
        chapters = Map.from(jsonDecode(row[5] as String)),
        cover = row[6] as String,
        comicType = ComicType(row[7] as int),
        createdAt = DateTime.fromMillisecondsSinceEpoch(row[8] as int);

  File get coverFile => File('${LocalManager().path}/$directory/$cover');

  @override
  String get description => "";

  @override
  String get sourceKey => comicType.comicSource?.key ?? '_local_';

  @override
  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "cover": cover,
      "id": id,
      "subTitle": subtitle,
      "tags": tags,
      "description": description,
      "sourceKey": sourceKey,
    };
  }

  @override
  int? get maxPage => null;
}

class LocalManager with ChangeNotifier {
  static LocalManager? _instance;

  LocalManager._();

  factory LocalManager() {
    return _instance ??= LocalManager._();
  }

  late Database _db;

  late String path;

  // return error message if failed
  Future<String?> setNewPath(String newPath) async {
    var newDir = Directory(newPath);
    if(!await newDir.exists()) {
      return "Directory does not exist";
    }
    if(!await newDir.list().isEmpty) {
      return "Directory is not empty";
    }
    try {
      await copyDirectory(
        Directory(path),
        newDir,
      );
      await File(FilePath.join(App.dataPath, 'local_path')).writeAsString(path);
    } catch (e) {
      return e.toString();
    }
    await Directory(path).deleteIgnoreError();
    path = newPath;
    return null;
  }

  Future<void> init() async {
    _db = sqlite3.open(
      '${App.dataPath}/local.db',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS comics (
        id TEXT NOT NULL,
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
    if (File(FilePath.join(App.dataPath, 'local_path')).existsSync()) {
      path = File(FilePath.join(App.dataPath, 'local_path')).readAsStringSync();
    } else {
      if (App.isAndroid) {
        var external = await getExternalStorageDirectories();
        if (external != null && external.isNotEmpty) {
          path = FilePath.join(external.first.path, 'local_path');
        } else {
          path = FilePath.join(App.dataPath, 'local_path');
        }
      } else {
        path = FilePath.join(App.dataPath, 'local_path');
      }
    }
    if (!Directory(path).existsSync()) {
      await Directory(path).create();
    }
  }

  String findValidId(ComicType type) {
    final res = _db.select(
      '''
      SELECT id FROM comics WHERE comic_type = ? 
      ORDER BY CAST(id AS INTEGER) DESC
      LIMIT 1;
      '''[type.value],
    );
    if (res.isEmpty) {
      return '1';
    }
    return ((res.first[0] as int) + 1).toString();
  }

  Future<void> add(LocalComic comic, [String? id]) async {
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

  void remove(String id, ComicType comicType) async {
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

  LocalComic? find(String id, ComicType comicType) {
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

  Future<List<String>> getImages(String id, ComicType type, int ep) async {
    var comic = find(id, type) ?? (throw "Comic Not Found");
    var directory = Directory(FilePath.join(path, comic.directory));
    if (comic.chapters != null) {
      var cid = comic.chapters!.keys.elementAt(ep - 1);
      directory = Directory(FilePath.join(directory.path, cid));
    }
    var files = <File>[];
    await for (var entity in directory.list()) {
      if (entity is File) {
        if (entity.absolute.path.replaceFirst(path, '').substring(1) ==
            comic.cover) {
          continue;
        }
        files.add(entity);
      }
    }
    files.sort((a, b) {
      var ai = int.tryParse(a.name.split('.').first);
      var bi = int.tryParse(b.name.split('.').first);
      if(ai != null && bi != null) {
        return ai.compareTo(bi);
      }
      return a.name.compareTo(b.name);
    });
    return files.map((e) => "file://${e.path}").toList();
  }

  Future<bool> isDownloaded(String id, ComicType type, int ep) async {
    var comic = find(id, type);
    if(comic == null) return false;
    if(comic.chapters == null)  return true;
    var eid = comic.chapters!.keys.elementAt(ep);
    return Directory(FilePath.join(path, comic.directory, eid)).exists();
  }
}
