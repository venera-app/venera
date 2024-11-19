import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:venera/utils/translations.dart';
import 'cbz.dart';
import 'io.dart';

class ImportComic {
  final String? selectedFolder;

  const ImportComic({this.selectedFolder});

  Future<bool> cbz() async {
    var file = await selectFile(ext: ['cbz']);
    if(file == null) {
      return false;
    }
    var controller = showLoadingDialog(App.rootContext, allowCancel: false);
    var isSuccessful = false;
    try {
      var comic = await CBZ.import(File(file.path));
      if (selectedFolder != null) {
        LocalFavoritesManager().addComic(
          selectedFolder!,
          FavoriteItem(
            id: comic.id,
            name: comic.title,
            coverPath: comic.cover,
            author: comic.subtitle,
            type: comic.comicType,
            tags: comic.tags,
          ),
        );
      }
      isSuccessful = true;
    } catch (e, s) {
      Log.error("Import Comic", e.toString(), s);
      App.rootContext.showMessage(message: e.toString());
    }
    controller.close();
    return isSuccessful;
  }

  Future<bool> ehViewer() async {
    var dbFile = await selectFile(ext: ['db']);
    final picker = DirectoryPicker();
    final comicSrc = await picker.pickDirectory();
    if (dbFile == null || comicSrc == null) {
      return false;
    }

    bool cancelled = false;
    var controller = showLoadingDialog(App.rootContext, onCancel: () {
      cancelled = true;
    });
    bool isSuccessful = false;

    try {
      var cache = FilePath.join(App.cachePath, dbFile.name);
      await dbFile.saveTo(cache);
      var db = sql.sqlite3.open(cache);

      Future<void> addTagComics(String destFolder, List<sql.Row> comics) async {
        for (var comic in comics) {
          if (cancelled) {
            return;
          }
          var comicDir = Directory(
              FilePath.join(comicSrc.path, comic['DIRNAME'] as String));
          if (!(await comicDir.exists())) {
            continue;
          }
          String titleJP =
              comic['TITLE_JPN'] == null ? "" : comic['TITLE_JPN'] as String;
          String title = titleJP == "" ? comic['TITLE'] as String : titleJP;
          if (LocalManager().findByName(title) != null) {
            Log.info("Import Comic", "Comic already exists: $title");
            continue;
          }

          String coverURL = await comicDir.joinFile(".thumb").exists()
              ? comicDir.joinFile(".thumb").path
              : (comic['THUMB'] as String)
                  .replaceAll('s.exhentai.org', 'ehgt.org');
          int downloadedTimeStamp = comic['TIME'] as int;
          DateTime downloadedTime = downloadedTimeStamp != 0
              ? DateTime.fromMillisecondsSinceEpoch(downloadedTimeStamp)
              : DateTime.now();
          var comicObj = LocalComic(
            id: LocalManager().findValidId(ComicType.local),
            title: title,
            subtitle: '',
            tags: [
              //1 >> x
              [
                "MISC",
                "DOUJINSHI",
                "MANGA",
                "ARTISTCG",
                "GAMECG",
                "IMAGE SET",
                "COSPLAY",
                "ASIAN PORN",
                "NON-H",
                "WESTERN",
              ][(log(comic['CATEGORY'] as int) / ln2).floor()]
            ],
            directory: comicDir.path,
            chapters: null,
            cover: coverURL,
            comicType: ComicType.local,
            downloadedChapters: [],
            createdAt: downloadedTime,
          );
          LocalManager().add(comicObj, comicObj.id);
          LocalFavoritesManager().addComic(
            destFolder,
            FavoriteItem(
              id: comicObj.id,
              name: comicObj.title,
              coverPath: comicObj.cover,
              author: comicObj.subtitle,
              type: comicObj.comicType,
              tags: comicObj.tags,
              favoriteTime: downloadedTime,
            ),
          );
        }
      }

      {
        var defaultFolderName = '(EhViewer)Default';
        if (!LocalFavoritesManager().existsFolder(defaultFolderName)) {
          LocalFavoritesManager().createFolder(defaultFolderName);
        }
        var comicList = db.select("""
              SELECT * 
              FROM DOWNLOAD_DIRNAME DN
              LEFT JOIN DOWNLOADS DL
              ON DL.GID = DN.GID
              WHERE DL.LABEL IS NULL AND DL.STATE = 3
              ORDER BY DL.TIME DESC
            """).toList();
        await addTagComics(defaultFolderName, comicList);
      }

      var folders = db.select("""
            SELECT * FROM DOWNLOAD_LABELS;
          """);

      for (var folder in folders) {
        if (cancelled) {
          break;
        }
        var label = folder["LABEL"] as String;
        var folderName = '(EhViewer)$label';
        if (!LocalFavoritesManager().existsFolder(folderName)) {
          LocalFavoritesManager().createFolder(folderName);
        }
        var comicList = db.select("""
              SELECT * 
              FROM DOWNLOAD_DIRNAME DN
              LEFT JOIN DOWNLOADS DL
              ON DL.GID = DN.GID
              WHERE DL.LABEL = ? AND DL.STATE = 3
              ORDER BY DL.TIME DESC
            """, [label]).toList();
        await addTagComics(folderName, comicList);
      }
      db.dispose();
      await File(cache).deleteIgnoreError();
      isSuccessful = true;
    } catch (e, s) {
      Log.error("Import Comic", e.toString(), s);
      App.rootContext.showMessage(message: e.toString());
    }
    controller.close();
    return isSuccessful;
  }

  Future<bool> directory(bool single) async {
    final picker = DirectoryPicker();
    final path = await picker.pickDirectory();
    if (path == null) {
      return false;
    }
    Map<Directory, LocalComic> comics = {};
    if (single) {
      var result = await _checkSingleComic(path);
      if (result != null) {
        comics[path] = result;
      } else {
        App.rootContext.showMessage(message: "Invalid Comic".tl);
        return false;
      }
    } else {
      await for (var entry in path.list()) {
        if (entry is Directory) {
          var result = await _checkSingleComic(entry);
          if (result != null) {
            comics[entry] = result;
          }
        }
      }
    }
    bool shouldCopy = true;
    for (var comic in comics.keys) {
      if (comic.parent.path == LocalManager().path) {
        shouldCopy = false;
        break;
      }
    }
    if (shouldCopy && comics.isNotEmpty) {
      try {
        // copy the comics to the local directory
        await compute<Map<String, dynamic>, void>(_copyDirectories, {
          'toBeCopied': comics.keys.map((e) => e.path).toList(),
          'destination': LocalManager().path,
        });
      } catch (e) {
        App.rootContext.showMessage(message: "Failed to import comics".tl);
        Log.error("Import Comic", e.toString());
        return false;
      }
    }
    for (var comic in comics.values) {
      LocalManager().add(comic, LocalManager().findValidId(ComicType.local));
      if (selectedFolder != null) {
        LocalFavoritesManager().addComic(
          selectedFolder!,
          FavoriteItem(
            id: comic.id,
            name: comic.title,
            coverPath: comic.cover,
            author: comic.subtitle,
            type: comic.comicType,
            tags: comic.tags,
          ),
        );
      }
    }
    App.rootContext.showMessage(
        message: "Imported @a comics".tlParams({
      'a': comics.length,
    }));
    return true;
  }

  Future<LocalComic?> _checkSingleComic(Directory directory) async {
    if (!(await directory.exists())) return null;
    var name = directory.name;
    if (LocalManager().findByName(name) != null) {
      Log.info("Import Comic", "Comic already exists: $name");
      return null;
    }
    bool hasChapters = false;
    var chapters = <String>[];
    var coverPath = ''; // relative path to the cover image
    for (var entry in directory.listSync()) {
      if (entry is Directory) {
        hasChapters = true;
        chapters.add(entry.name);
        await for (var file in entry.list()) {
          if (file is Directory) {
            Log.info("Import Comic",
                "Invalid Chapter: ${entry.name}\nA directory is found in the chapter directory.");
            return null;
          }
        }
      } else if (entry is File) {
        if (entry.name.startsWith('cover')) {
          coverPath = entry.name;
        }
        const imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'jpe'];
        if (!coverPath.startsWith('cover') &&
            imageExtensions.contains(entry.extension)) {
          coverPath = entry.name;
        }
      }
    }
    chapters.sort();
    if (hasChapters && coverPath == '') {
      // use the first image in the first chapter as the cover
      var firstChapter = Directory('${directory.path}/${chapters.first}');
      await for (var entry in firstChapter.list()) {
        if (entry is File) {
          coverPath = entry.name;
          break;
        }
      }
    }
    if (coverPath == '') {
      Log.info("Import Comic", "Invalid Comic: $name\nNo cover image found.");
      return null;
    }
    return LocalComic(
      id: '0',
      title: name,
      subtitle: '',
      tags: [],
      directory: directory.name,
      chapters: hasChapters ? Map.fromIterables(chapters, chapters) : null,
      cover: coverPath,
      comicType: ComicType.local,
      downloadedChapters: chapters,
      createdAt: DateTime.now(),
    );
  }

  static _copyDirectories(Map<String, dynamic> data) {
    var toBeCopied = data['toBeCopied'] as List<String>;
    var destination = data['destination'] as String;
    for (var dir in toBeCopied) {
      var source = Directory(dir);
      var dest = Directory("$destination/${source.name}");
      if (dest.existsSync()) {
        // The destination directory already exists, and it is not managed by the app.
        // Rename the old directory to avoid conflicts.
        Log.info("Import Comic",
            "Directory already exists: ${source.name}\nRenaming the old directory.");
        dest.rename(
            findValidDirectoryName(dest.parent.path, "${dest.path}_old"));
      }
      dest.createSync();
      copyDirectory(source, dest);
    }
  }
}
