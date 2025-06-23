import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:flutter_saf/flutter_saf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/download.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/io.dart';

import 'app.dart';
import 'history.dart';

class LocalComic with HistoryMixin implements Comic {
  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final List<String> tags;

  /// The name of the directory where the comic is stored
  final String directory;

  /// key: chapter id, value: chapter title
  ///
  /// chapter id is the name of the directory in `LocalManager.path/$directory`
  final ComicChapters? chapters;

  bool get hasChapters => chapters != null;

  /// relative path to the cover image
  @override
  final String cover;

  final ComicType comicType;

  final List<String> downloadedChapters;

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
    required this.downloadedChapters,
    required this.createdAt,
  });

  LocalComic.fromRow(Row row)
      : id = row[0] as String,
        title = row[1] as String,
        subtitle = row[2] as String,
        tags = List.from(jsonDecode(row[3] as String)),
        directory = row[4] as String,
        chapters = ComicChapters.fromJsonOrNull(jsonDecode(row[5] as String)),
        cover = row[6] as String,
        comicType = ComicType(row[7] as int),
        downloadedChapters = List.from(jsonDecode(row[8] as String)),
        createdAt = DateTime.fromMillisecondsSinceEpoch(row[9] as int);

  File get coverFile => File(FilePath.join(
        baseDir,
        cover,
      ));

  String get baseDir => (directory.contains('/') || directory.contains('\\'))
      ? directory
      : FilePath.join(LocalManager().path, directory);

  @override
  String get description => "";

  @override
  String get sourceKey =>
      comicType == ComicType.local ? "local" : comicType.sourceKey;

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
      "chapters": chapters?.toJson(),
    };
  }

  @override
  int? get maxPage => null;

  void read() {
    var history = HistoryManager().find(id, comicType);
    int? firstDownloadedChapter;
    int? firstDownloadedChapterGroup;
    if (downloadedChapters.isNotEmpty && chapters != null) {
      final chapters = this.chapters!;
      if (chapters.isGrouped) {
        for (int i=0; i<chapters.groupCount; i++) {
          var group = chapters.getGroupByIndex(i);
          var keys = group.keys.toList();
          for (int j=0; j<keys.length; j++) {
            var chapterId = keys[j];
            if (downloadedChapters.contains(chapterId)) {
              firstDownloadedChapter = j + 1;
              firstDownloadedChapterGroup = i + 1;
              break;
            }
          }
        }
      } else {
        var keys = chapters.allChapters.keys;
        for (int i = 0; i < keys.length; i++) {
          if (downloadedChapters.contains(keys.elementAt(i))) {
            firstDownloadedChapter = i + 1;
            break;
          }
        }
      }
    }
    App.rootContext.to(
      () => Reader(
        type: comicType,
        cid: id,
        name: title,
        chapters: chapters,
        initialChapter: history?.ep ?? firstDownloadedChapter,
        initialPage: history?.page,
        initialChapterGroup: history?.group ?? firstDownloadedChapterGroup,
        history: history ??
            History.fromModel(
              model: this,
              ep: 0,
              page: 0,
            ),
        author: subtitle,
        tags: tags,
      ),
    );
  }

  @override
  HistoryType get historyType => comicType;

  @override
  String? get subTitle => subtitle;

  @override
  String? get language => null;

  @override
  String? get favoriteId => null;

  @override
  double? get stars => null;
}

class LocalManager with ChangeNotifier {
  static LocalManager? _instance;

  LocalManager._();

  factory LocalManager() {
    return _instance ??= LocalManager._();
  }

  late Database _db;

  /// path to the directory where all the comics are stored
  late String path;

  Directory get directory => Directory(path);

  void _checkNoMedia() {
    if (App.isAndroid) {
      var file = File(FilePath.join(path, '.nomedia'));
      if (!file.existsSync()) {
        file.createSync();
      }
    }
  }

  // return error message if failed
  Future<String?> setNewPath(String newPath) async {
    var newDir = Directory(newPath);
    if (!await newDir.exists()) {
      return "Directory does not exist";
    }
    if (!await newDir.list().isEmpty) {
      return "Directory is not empty";
    }
    try {
      await copyDirectoryIsolate(
        directory,
        newDir,
      );
      await File(FilePath.join(App.dataPath, 'local_path'))
          .writeAsString(newPath);
    } catch (e, s) {
      Log.error("IO", e, s);
      return e.toString();
    }
    await directory.deleteContents(recursive: true);
    path = newPath;
    _checkNoMedia();
    return null;
  }

  Future<String> findDefaultPath() async {
    if (App.isAndroid) {
      var external = await getExternalStorageDirectories();
      if (external != null && external.isNotEmpty) {
        return FilePath.join(external.first.path, 'local');
      } else {
        return FilePath.join(App.dataPath, 'local');
      }
    } else if (App.isIOS) {
      var oldPath = FilePath.join(App.dataPath, 'local');
      if (Directory(oldPath).existsSync() &&
          Directory(oldPath).listSync().isNotEmpty) {
        return oldPath;
      } else {
        var directory = await getApplicationDocumentsDirectory();
        return FilePath.join(directory.path, 'local');
      }
    } else {
      return FilePath.join(App.dataPath, 'local');
    }
  }

  Future<void> _checkPathValidation() async {
    var testFile = File(FilePath.join(path, 'venera_test'));
    try {
      testFile.createSync();
      testFile.deleteSync();
    } catch (e) {
      Log.error("IO",
          "Failed to create test file in local path: $e\nUsing default path instead.");
      path = await findDefaultPath();
    }
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
        downloadedChapters TEXT NOT NULL,
        created_at INTEGER,
        PRIMARY KEY (id, comic_type)
      );
    ''');
    if (File(FilePath.join(App.dataPath, 'local_path')).existsSync()) {
      path = File(FilePath.join(App.dataPath, 'local_path')).readAsStringSync();
      if (!directory.existsSync()) {
        path = await findDefaultPath();
      }
    } else {
      path = await findDefaultPath();
    }
    try {
      if (!directory.existsSync()) {
        await directory.create();
      }
    } catch (e, s) {
      Log.error("IO", "Failed to create local folder: $e", s);
    }
    _checkPathValidation();
    _checkNoMedia();
    await ComicSourceManager().ensureInit();
    restoreDownloadingTasks();
  }

  String findValidId(ComicType type) {
    final res = _db.select(
      '''
      SELECT id FROM comics WHERE comic_type = ?
      ORDER BY CAST(id AS INTEGER) DESC
      LIMIT 1;
      ''',
      [type.value],
    );
    if (res.isEmpty) {
      return '1';
    }
    return (int.parse((res.first[0])) + 1).toString();
  }

  Future<void> add(LocalComic comic, [String? id]) async {
    var old = find(id ?? comic.id, comic.comicType);
    var downloaded = comic.downloadedChapters;
    if (old != null) {
      downloaded.addAll(old.downloadedChapters);
    }
    _db.execute(
      'INSERT OR REPLACE INTO comics VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        id ?? comic.id,
        comic.title,
        comic.subtitle,
        jsonEncode(comic.tags),
        comic.directory,
        jsonEncode(comic.chapters),
        comic.cover,
        comic.comicType.value,
        jsonEncode(downloaded),
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

  List<LocalComic> getComics(LocalSortType sortType) {
    var res = _db.select('''
      SELECT * FROM comics
      ORDER BY
        ${sortType.value == 'name' ? 'title' : 'created_at'}
        ${sortType.value == 'time_asc' ? 'ASC' : 'DESC'}
      ;
    ''');
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

  List<LocalComic> search(String keyword) {
    final res = _db.select('''
      SELECT * FROM comics
      WHERE title LIKE ? OR tags LIKE ? OR subtitle LIKE ?
      ORDER BY created_at DESC;
    ''', ['%$keyword%', '%$keyword%', '%$keyword%']);
    return res.map((row) => LocalComic.fromRow(row)).toList();
  }

  Future<List<String>> getImages(String id, ComicType type, Object ep) async {
    if (ep is! String && ep is! int) {
      throw "Invalid ep";
    }
    var comic = find(id, type) ?? (throw "Comic Not Found");
    var directory = Directory(comic.baseDir);
    if (comic.hasChapters) {
      var cid =
          ep is int ? comic.chapters!.ids.elementAt(ep - 1) : (ep as String);
      directory = Directory(FilePath.join(directory.path, cid));
    }
    var files = <File>[];
    await for (var entity in directory.list()) {
      if (entity is File) {
        // Do not exclude comic.cover, since it may be the first page of the chapter.
        // A file with name starting with 'cover.' is not a comic page.
        if (entity.name.startsWith('cover.')) {
          continue;
        }
        //Hidden file in some file system
        if (entity.name.startsWith('.')) {
          continue;
        }
        files.add(entity);
      }
    }
    files.sort((a, b) {
      var ai = int.tryParse(a.name.split('.').first);
      var bi = int.tryParse(b.name.split('.').first);
      if (ai != null && bi != null) {
        return ai.compareTo(bi);
      }
      return a.name.compareTo(b.name);
    });
    return files.map((e) => "file://${e.path}").toList();
  }

  bool isDownloaded(String id, ComicType type,
      [int? ep, ComicChapters? chapters]) {
    var comic = find(id, type);
    if (comic == null) return false;
    if (comic.chapters == null || ep == null) return true;
    if (chapters != null) {
      if (comic.chapters?.length != chapters.length) {
        // update
        add(LocalComic(
          id: comic.id,
          title: comic.title,
          subtitle: comic.subtitle,
          tags: comic.tags,
          directory: comic.directory,
          chapters: chapters,
          cover: comic.cover,
          comicType: comic.comicType,
          downloadedChapters: comic.downloadedChapters,
          createdAt: comic.createdAt,
        ));
      }
    }
    return comic.downloadedChapters
        .contains((chapters ?? comic.chapters)!.ids.elementAtOrNull(ep - 1));
  }

  List<DownloadTask> downloadingTasks = [];

  bool isDownloading(String id, ComicType type) {
    return downloadingTasks
        .any((element) => element.id == id && element.comicType == type);
  }

  Future<Directory> findValidDirectory(
      String id, ComicType type, String name) async {
    var comic = find(id, type);
    if (comic != null) {
      return Directory(FilePath.join(path, comic.directory));
    }
    const comicDirectoryMaxLength = 80;
    if (name.length > comicDirectoryMaxLength) {
      name = name.substring(0, comicDirectoryMaxLength);
    }
    var dir = findValidDirectoryName(path, name);
    return Directory(FilePath.join(path, dir)).create().then((value) => value);
  }

  void completeTask(DownloadTask task) {
    add(task.toLocalComic());
    downloadingTasks.remove(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
    downloadingTasks.firstOrNull?.resume();
  }

  void removeTask(DownloadTask task) {
    downloadingTasks.remove(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
  }

  void moveToFirst(DownloadTask task) {
    if (downloadingTasks.first != task) {
      var shouldResume = !downloadingTasks.first.isPaused;
      downloadingTasks.first.pause();
      downloadingTasks.remove(task);
      downloadingTasks.insert(0, task);
      notifyListeners();
      saveCurrentDownloadingTasks();
      if (shouldResume) {
        downloadingTasks.first.resume();
      }
    }
  }

  Future<void> saveCurrentDownloadingTasks() async {
    var tasks = downloadingTasks.map((e) => e.toJson()).toList();
    await File(FilePath.join(App.dataPath, 'downloading_tasks.json'))
        .writeAsString(jsonEncode(tasks));
  }

  void restoreDownloadingTasks() {
    var file = File(FilePath.join(App.dataPath, 'downloading_tasks.json'));
    if (file.existsSync()) {
      try {
        var tasks = jsonDecode(file.readAsStringSync());
        for (var e in tasks) {
          var task = DownloadTask.fromJson(e);
          if (task != null) {
            downloadingTasks.add(task);
          }
        }
      } catch (e) {
        file.delete();
        Log.error("LocalManager", "Failed to restore downloading tasks: $e");
      }
    }
  }

  void addTask(DownloadTask task) {
    downloadingTasks.add(task);
    notifyListeners();
    saveCurrentDownloadingTasks();
    downloadingTasks.first.resume();
  }

  void deleteComic(LocalComic c, [bool removeFileOnDisk = true]) {
    if (removeFileOnDisk) {
      var dir = Directory(FilePath.join(path, c.directory));
      dir.deleteIgnoreError(recursive: true);
    }
    // Deleting a local comic means that it's no longer available, thus both favorite and history should be deleted.
    if (c.comicType == ComicType.local) {
      if (HistoryManager().find(c.id, c.comicType) != null) {
        HistoryManager().remove(c.id, c.comicType);
      }
      var folders = LocalFavoritesManager().find(c.id, c.comicType);
      for (var f in folders) {
        LocalFavoritesManager().deleteComicWithId(f, c.id, c.comicType);
      }
    }
    remove(c.id, c.comicType);
    notifyListeners();
  }

  void deleteComicChapters(LocalComic c, List<String> chapters) {
    if (chapters.isEmpty) {
      return;
    }
    var newDownloadedChapters = c.downloadedChapters
        .where((e) => !chapters.contains(e))
        .toList();
    if (newDownloadedChapters.isNotEmpty) {
      _db.execute(
        'UPDATE comics SET downloadedChapters = ? WHERE id = ? AND comic_type = ?;',
        [
          jsonEncode(newDownloadedChapters),
          c.id,
          c.comicType.value,
        ],
      );
    } else {
      _db.execute(
        'DELETE FROM comics WHERE id = ? AND comic_type = ?;',
        [c.id, c.comicType.value],
      );
    }
    var shouldRemovedDirs = <Directory>[];
    for (var chapter in chapters) {
      var dir = Directory(FilePath.join(c.baseDir, chapter));
      if (dir.existsSync()) {
        shouldRemovedDirs.add(dir);
      }
    }
    if (shouldRemovedDirs.isNotEmpty) {
      _deleteDirectories(shouldRemovedDirs);
    }
    notifyListeners();
  }

  void batchDeleteComics(List<LocalComic> comics, [bool removeFileOnDisk = true, bool removeFavoriteAndHistory = true]) {
    if (comics.isEmpty) {
      return;
    }

    var shouldRemovedDirs = <Directory>[];
    _db.execute('BEGIN TRANSACTION;');
    try {
      for (var c in comics) {
        if (removeFileOnDisk) {
          var dir = Directory(FilePath.join(path, c.directory));
          if (dir.existsSync()) {
            shouldRemovedDirs.add(dir);
          }
        }
        _db.execute(
          'DELETE FROM comics WHERE id = ? AND comic_type = ?;',
          [c.id, c.comicType.value],
        );
      }
    }
    catch(e, s) {
      Log.error("LocalManager", "Failed to batch delete comics: $e", s);
      _db.execute('ROLLBACK;');
      return;
    }
    _db.execute('COMMIT;');

    var comicIDs = comics.map((e) => ComicID(e.comicType, e.id)).toList();

    if (removeFavoriteAndHistory) {
      LocalFavoritesManager().batchDeleteComicsInAllFolders(comicIDs);
      HistoryManager().batchDeleteHistories(comicIDs);
    }

    notifyListeners();

    if (removeFileOnDisk) {
      _deleteDirectories(shouldRemovedDirs);
    }
  }

  /// Deletes the directories in a separate isolate to avoid blocking the UI thread.
  static void _deleteDirectories(List<Directory> directories) {
    Isolate.run(() async {
      await SAFTaskWorker().init();
      for (var dir in directories) {
        try {
          if (dir.existsSync()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          continue;
        }
      }
    });
  }
}

enum LocalSortType {
  name("name"),
  timeAsc("time_asc"),
  timeDesc("time_desc");

  final String value;

  const LocalSortType(this.value);

  static LocalSortType fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return name;
  }
}
