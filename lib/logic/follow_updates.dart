import 'dart:async';
import 'dart:convert';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/log.dart';

class UpdateProgress {
  final int total;
  final int current;
  final int errors;
  final int updated;
  final FavoriteItemWithUpdateInfo? comic;

  UpdateProgress(this.total, this.current, this.errors, this.updated, [this.comic]);
}

void updateFolderBase(
  String folder,
  StreamController<UpdateProgress> stream,
  bool ignoreCheckTime,
) async {
  var comics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder);
  int total = comics.length;
  int current = 0;
  int errors = 0;
  int updated = 0;

  stream.add(UpdateProgress(total, current, errors, updated));

  var comicsToUpdate = <FavoriteItemWithUpdateInfo>[];

  for (var comic in comics) {
    if (!ignoreCheckTime) {
      var lastCheckTime = comic.lastCheckTime;
      if (lastCheckTime != null &&
          DateTime.now().difference(lastCheckTime).inDays < 1) {
        current++;
        stream.add(UpdateProgress(total, current, errors, updated));
        continue;
      }
    }
    comicsToUpdate.add(comic);
  }

  total = comicsToUpdate.length;
  current = 0;
  stream.add(UpdateProgress(total, current, errors, updated));

  Future<void> updateComic(FavoriteItemWithUpdateInfo c) async {
    int retries = 3;
    while (true) {
      try {
        var comicSource = c.type.comicSource;
        if (comicSource == null) return;
        var newInfo = (await comicSource.loadComicInfo!(c.id)).data;

        var newTags = <String>[];
        for (var entry in newInfo.tags.entries) {
          const shouldIgnore = ['author', 'artist', 'time'];
          var namespace = entry.key;
          if (shouldIgnore.contains(namespace.toLowerCase())) {
            continue;
          }
          for (var tag in entry.value) {
            newTags.add("$namespace:$tag");
          }
        }

        var item = FavoriteItem(
          id: c.id,
          name: newInfo.title,
          coverPath: newInfo.cover,
          author: newInfo.subTitle ??
              newInfo.tags['author']?.firstOrNull ??
              c.author,
          type: c.type,
          tags: newTags,
        );

        LocalFavoritesManager().updateInfo(folder, item, false);

        var updateTime = newInfo.findUpdateTime();
        if (updateTime != null && updateTime != c.updateTime) {
          LocalFavoritesManager().updateUpdateTime(
            folder,
            c.id,
            c.type,
            updateTime,
          );
          updated++;
        } else {
          LocalFavoritesManager().updateCheckTime(folder, c.id, c.type);
        }
        return;
      } catch (e, s) {
        Log.error("Check Updates", e, s);
        retries--;
        if (retries == 0) {
          errors++;
          return;
        }
      }
    }
  }

  var futures = <Future>[];
  for (var comic in comicsToUpdate) {
    var future = updateComic(comic).then((_) {
      current++;
      stream.add(UpdateProgress(total, current, errors, updated, comic));
    });
    futures.add(future);
  }

  await Future.wait(futures);

  if (updated > 0) {
    LocalFavoritesManager().notifyChanges();
  }

  stream.close();
}


Stream<UpdateProgress> updateFolder(String folder, bool ignoreCheckTime) {
  var stream = StreamController<UpdateProgress>();
  updateFolderBase(folder, stream, ignoreCheckTime);
  return stream.stream;
}

Future<String> getUpdatedComicsAsJson(String folder) async {
  var comics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder);
  var updatedComics = comics.where((c) => c.hasNewUpdate).toList();
  var jsonList = updatedComics.map((c) => {
    'id': c.id,
    'name': c.name,
    'cover': c.coverPath,
    'author': c.author,
    'type': c.type.sourceKey,
    'updateTime': c.updateTime,
    'tags': c.tags,
  }).toList();
  return jsonEncode(jsonList);
}
