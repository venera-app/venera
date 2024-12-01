import 'dart:isolate';

import 'package:pdf/widgets.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/utils/io.dart';

Future<void> _createPdfFromComic({
  required LocalComic comic,
  required String savePath,
  required String localPath,
}) async {
  final pdf = Document(
    title: comic.title,
    author: comic.subTitle ?? "",
    producer: "Venera",
  );

  pdf.document.outline;

  var baseDir = comic.directory.contains('/') || comic.directory.contains('\\')
      ? comic.directory
      : FilePath.join(localPath, comic.directory);

  // add cover
  var imageData = File(FilePath.join(baseDir, comic.cover)).readAsBytesSync();
  pdf.addPage(Page(
    build: (Context context) {
      return Image(MemoryImage(imageData), fit: BoxFit.contain);
    },
  ));

  bool multiChapters = comic.chapters != null;

  void reorderFiles(List<FileSystemEntity> files) {
    files.removeWhere(
        (element) => element is! File || element.path.startsWith('cover'));
    files.sort((a, b) {
      var aName = (a as File).name;
      var bName = (b as File).name;
      var aNumber = int.tryParse(aName);
      var bNumber = int.tryParse(bName);
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return aName.compareTo(bName);
    });
  }

  if (!multiChapters) {
    var files = Directory(baseDir).listSync();
    reorderFiles(files);

    for (var file in files) {
      var imageData = (file as File).readAsBytesSync();
      pdf.addPage(Page(
        build: (Context context) {
          return Image(MemoryImage(imageData), fit: BoxFit.contain);
        },
      ));
    }
  } else {
    for (var chapter in comic.chapters!.keys) {
      var files = Directory(FilePath.join(baseDir, chapter)).listSync();
      reorderFiles(files);
      for (var file in files) {
        var imageData = (file as File).readAsBytesSync();
        pdf.addPage(Page(
          build: (Context context) {
            return Image(MemoryImage(imageData), fit: BoxFit.contain);
          },
        ));
      }
    }
  }

  final file = File(savePath);
  file.writeAsBytesSync(await pdf.save());
}

Future<void> createPdfFromComicIsolate({
  required LocalComic comic,
  required String savePath,
}) async {
  var localPath = LocalManager().path;
  return Isolate.run(() => overrideIO(() async {
        return await _createPdfFromComic(
          comic: comic,
          savePath: savePath,
          localPath: localPath,
        );
      }));
}
