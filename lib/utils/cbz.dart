import 'dart:convert';
import 'dart:isolate';

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/io.dart';
import 'package:zip_flutter/zip_flutter.dart';

class ComicMetaData {
  final String title;

  final String author;

  final List<String> tags;

  final List<ComicChapter>? chapters;

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'tags': tags,
        'chapters': chapters?.map((e) => e.toJson()).toList()
      };

  ComicMetaData.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        author = json['author'],
        tags = List<String>.from(json['tags']),
        chapters = json['chapters'] == null
            ? null
            : List<ComicChapter>.from(
                json['chapters'].map((e) => ComicChapter.fromJson(e)));

  ComicMetaData({
    required this.title,
    required this.author,
    required this.tags,
    this.chapters,
  });
}

class ComicChapter {
  final String title;

  final int start;

  final int end;

  Map<String, dynamic> toJson() => {'title': title, 'start': start, 'end': end};

  ComicChapter.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        start = json['start'],
        end = json['end'];

  ComicChapter({required this.title, required this.start, required this.end});
}

abstract class CBZ {
  static Future<LocalComic> import(File file) async {
    var cache = Directory(FilePath.join(App.cachePath, 'cbz_import'));
    if (cache.existsSync()) cache.deleteSync(recursive: true);
    cache.createSync();
    await Isolate.run(() => ZipFile.openAndExtract(file.path, cache.path));
    var metaDataFile = File(FilePath.join(cache.path, 'metadata.json'));
    ComicMetaData? metaData;
    if (metaDataFile.existsSync()) {
      try {
        metaData =
            ComicMetaData.fromJson(jsonDecode(metaDataFile.readAsStringSync()));
      } catch (_) {}
    }
    metaData ??= ComicMetaData(
      title: file.name.replaceLast('.cbz', ''),
      author: "",
      tags: [],
    );
    var old = LocalManager().findByName(metaData.title);
    if (old != null) {
      throw Exception('Comic with name ${metaData.title} already exists');
    }
    var files = cache.listSync().whereType<File>().toList();
    files.removeWhere((e) {
      var ext = e.path.split('.').last;
      return !['jpg', 'jpeg', 'png', 'webp', 'gif', 'jpe'].contains(ext);
    });
    if(files.isEmpty) {
      throw Exception('No images found in the archive');
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    var coverFile = files.firstWhereOrNull(
      (element) =>
          element.path.endsWith('cover.${element.path.split('.').last}'),
    );
    if (coverFile != null) {
      files.remove(coverFile);
    } else {
      coverFile = files.first;
    }
    Map<String, String>? cpMap;
    var dest = Directory(
      FilePath.join(LocalManager().path, sanitizeFileName(metaData.title)),
    );
    dest.createSync();
    coverFile.copyMem(
        FilePath.join(dest.path, 'cover.${coverFile.extension}'));
    if (metaData.chapters == null) {
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var dst = File(
            FilePath.join(dest.path, '${i + 1}.${src.path.split('.').last}'));
        await src.copyMem(dst.path);
      }
    } else {
      dest.createSync();
      var chapters = <String, List<File>>{};
      for (var chapter in metaData.chapters!) {
        chapters[chapter.title] = files.sublist(chapter.start - 1, chapter.end);
      }
      int i = 0;
      cpMap = <String, String>{};
      for (var chapter in chapters.entries) {
        cpMap[i.toString()] = chapter.key;
        var chapterDir = Directory(FilePath.join(dest.path, i.toString()));
        chapterDir.createSync();
        for (var i = 0; i < chapter.value.length; i++) {
          var src = chapter.value[i];
          var dst = File(FilePath.join(
              chapterDir.path, '${i + 1}.${src.path.split('.').last}'));
          await src.copyMem(dst.path);
        }
      }
    }
    var comic = LocalComic(
      id: LocalManager().findValidId(ComicType.local),
      title: metaData.title,
      subtitle: metaData.author,
      tags: metaData.tags,
      comicType: ComicType.local,
      directory: dest.name,
      chapters: cpMap,
      downloadedChapters: cpMap?.keys.toList() ?? [],
      cover: 'cover.${coverFile.extension}',
      createdAt: DateTime.now(),
    );
    await cache.delete(recursive: true);
    return comic;
  }

  static Future<File> export(LocalComic comic) async {
    var cache = Directory(FilePath.join(App.cachePath, 'cbz_export'));
    if (cache.existsSync()) cache.deleteSync(recursive: true);
    cache.createSync();
    List<ComicChapter>? chapters;
    if (comic.chapters == null) {
      var images = await LocalManager().getImages(comic.id, comic.comicType, 1);
      int i = 1;
      for (var image in images) {
        var src = File(image.replaceFirst('file://', ''));
        var width = images.length.toString().length;
        var dstName =
            '${i.toString().padLeft(width, '0')}.${image.split('.').last}';
        var dst = File(FilePath.join(cache.path, dstName));
        await src.copyMem(dst.path);
        i++;
      }
    } else {
      chapters = [];
      var allImages = <String>[];
      for (var c in comic.downloadedChapters) {
        var chapterName = comic.chapters![c];
        var images = await LocalManager().getImages(
          comic.id,
          comic.comicType,
          c,
        );
        allImages.addAll(images);
        var chapter = ComicChapter(
          title: chapterName!,
          start: chapters.length + 1,
          end: chapters.length + images.length,
        );
        chapters.add(chapter);
      }
      int i = 1;
      for (var image in allImages) {
        var src = File(image);
        var width = allImages.length.toString().length;
        var dstName =
            '${i.toString().padLeft(width, '0')}.${image.split('.').last}';
        var dst = File(FilePath.join(cache.path, dstName));
        await src.copyMem(dst.path);
        i++;
      }
    }
    var cover = comic.coverFile;
    await cover
        .copyMem(FilePath.join(cache.path, 'cover.${cover.path.split('.').last}'));
    await File(FilePath.join(cache.path, 'metadata.json')).writeAsString(
      jsonEncode(
        ComicMetaData(
          title: comic.title,
          author: comic.subtitle,
          tags: comic.tags,
          chapters: chapters,
        ).toJson(),
      ),
    );
    var cbz = File(FilePath.join(App.cachePath, '${comic.title}.cbz'));
    await _compress(cache.path, cbz.path);
    cache.deleteSync(recursive: true);
    return cbz;
  }

  static _compress(String src, String dst) async {
    await Isolate.run(() => ZipFile.compressFolder(src, dst));
  }
}
