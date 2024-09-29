import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmoothCustomScrollView(
      slivers: [
        _History(),
        _Local(),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final history = HistoryManager().getRecent();
    final count = HistoryManager().count();

    return SliverToBoxAdapter(
      child: InkWell(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('History'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(count.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (history.isNotEmpty)
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          // TODO: toComicPageWithHistory(context, history[index]);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 96,
                          height: 128,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: CachedImageProvider(
                              history[index].cover,
                              sourceKey: history[index].type.comicSource?.key,
                            ),
                            width: 96,
                            height: 128,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingHorizontal(8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Local extends StatelessWidget {
  const _Local();

  @override
  Widget build(BuildContext context) {
    final local = LocalManager().getRecent();
    final count = LocalManager().count;

    return SliverToBoxAdapter(
      child: InkWell(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('Local'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(count.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (local.isNotEmpty)
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: local.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          // TODO: view local comic
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 96,
                          height: 128,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: FileImage(
                              local[index].coverFile,
                            ),
                            width: 96,
                            height: 128,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingHorizontal(8),
              Row(
                children: [
                  const Spacer(),
                  Button.filled(
                    onPressed: import,
                    child: Text("Import".tl),
                  ),
                ],
              ).paddingHorizontal(16).paddingVertical(8),
            ],
          ),
        ),
      ),
    );
  }

  void import() {
    showDialog(
      barrierDismissible: false,
      context: App.rootContext,
      builder: (context) {
        return const _ImportComicsWidget();
      },
    );
  }
}

class _ImportComicsWidget extends StatefulWidget {
  const _ImportComicsWidget();

  @override
  State<_ImportComicsWidget> createState() => _ImportComicsWidgetState();
}

class _ImportComicsWidgetState extends State<_ImportComicsWidget> {
  int type = 0;

  bool loading = false;

  var key = GlobalKey();

  var height = 200.0;

  @override
  void dispose() {
    loading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String info = type == 0
        ? "Select a directory which contains the comic files.".tl
        : "Select a directory which contains the comic directories.".tl;

    return ContentDialog(
      dismissible: !loading,
      title: "Import Comics".tl,
      content: loading
          ? SizedBox(
              width: 600,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
          )
          : Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 600),
                RadioListTile(
                  title: Text("Single Comic".tl),
                  value: 0,
                  groupValue: type,
                  onChanged: (value) {
                    setState(() {
                      type = value as int;
                    });
                  },
                ),
                RadioListTile(
                  title: Text("Multiple Comics".tl),
                  value: 1,
                  groupValue: type,
                  onChanged: (value) {
                    setState(() {
                      type = value as int;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(info).paddingHorizontal(24),
              ],
            ),
      actions: [
        Button.text(
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text("help".tl),
            ],
          ),
          onPressed: () {
            showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) {
                var help = '';
                help +=
                    '${"A directory is considered as a comic only if it matches one of the following conditions:".tl}\n';
                help += '${'1. The directory only contains image files.'.tl}\n';
                help +=
                    '${'2. The directory contains directories which contain image files. Each directory is considered as a chapter.'.tl}\n\n';
                help +=
                    '${"If the directory contains a file named 'cover.*', it will be used as the cover image. Otherwise the first image will be used.".tl}\n\n';
                help +=
                    "The directory name will be used as the comic title. And the name of chapter directories will be used as the chapter titles."
                        .tl;
                return ContentDialog(
                  title: "Help".tl,
                  content: Text(help).paddingHorizontal(16),
                  actions: [
                    Button.filled(
                      child: Text("OK".tl),
                      onPressed: () {
                        context.pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        ).fixWidth(90).paddingRight(8),
        Button.filled(
          isLoading: loading,
          onPressed: selectAndImport,
          child: Text("Select".tl),
        )
      ],
    );
  }

  void selectAndImport() async {
    height = key.currentContext!.size!.height;
    setState(() {
      loading = true;
    });
    final picker = DirectoryPicker();
    final path = await picker.pickDirectory();
    if(!loading) {
      picker.dispose();
      return;
    }
    if(path == null) {
      setState(() {
        loading = false;
      });
      return;
    }
    Map<Directory, LocalComic> comics = {};
    if(type == 0) {
      var result = await checkSingleComic(path);
      if(result != null) {
        comics[path] = result;
      } else {
        context.showMessage(message: "Invalid Comic".tl);
        setState(() {
          loading = false;
        });
        return;
      }
    } else {
      await for(var entry in path.list()) {
        if(entry is Directory) {
          var result = await checkSingleComic(entry);
          if(result != null) {
            comics[entry] = result;
          }
        }
      }
    }
    bool shouldCopy = true;
    for(var comic in comics.keys) {
      if(comic.parent.path == LocalManager().path) {
        shouldCopy = false;
        break;
      }
    }
    if(shouldCopy && comics.isNotEmpty) {
      try {
        // copy the comics to the local directory
        await compute<Map<String, dynamic>, void>(_copyDirectories, {
          'toBeCopied': comics.keys.map((e) => e.path).toList(),
          'destination': LocalManager().path,
        });
      }
      catch(e) {
        context.showMessage(message: "Failed to import comics".tl);
        Log.error("Import Comic", e.toString());
        setState(() {
          loading = false;
        });
        return;
      }
    }
    for(var comic in comics.values) {
      LocalManager().add(comic, LocalManager().findValidId(ComicType.local));
    }
    context.pop();
    context.showMessage(message: "Imported @a comics".tlParams({
      'a': comics.length,
    }));
  }

  static _copyDirectories(Map<String, dynamic> data) {
    var toBeCopied = data['toBeCopied'] as List<String>;
    var destination = data['destination'] as String;
    for(var dir in toBeCopied) {
      var source = Directory(dir);
      var dest = Directory("$destination/${source.name}");
      if(dest.existsSync()) {
        // The destination directory already exists, and it is not managed by the app.
        // Rename the old directory to avoid conflicts.
        Log.info("Import Comic", "Directory already exists: ${source.name}\nRenaming the old directory.");
        dest.rename(findValidDirectoryName(dest.parent.path, "${dest.path}_old"));
      }
      dest.createSync();
      copyDirectory(source, dest);
    }
  }

  Future<LocalComic?> checkSingleComic(Directory directory) async {
    if(!(await directory.exists())) return null;
    var name = directory.name;
    bool hasChapters = false;
    var chapters = <String>[];
    var coverPath = ''; // relative path to the cover image
    await for(var entry in directory.list()) {
      if(entry is Directory) {
        hasChapters = true;
        if(LocalManager().findByName(entry.name) != null) {
          Log.info("Import Comic", "Comic already exists: $name");
          return null;
        }
        chapters.add(entry.name);
        await for(var file in entry.list()) {
          if(file is Directory) {
            Log.info("Import Comic", "Invalid Chapter: ${entry.name}\nA directory is found in the chapter directory.");
            return null;
          }
        }
      } else if(entry is File){
        if(entry.name.startsWith('cover')) {
          coverPath = entry.name;
        }
        const imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'jpe'];
        if(!coverPath.startsWith('cover') && imageExtensions.contains(entry.extension)) {
          coverPath = entry.name;
        }
      }
    }
    chapters.sort();
    if(hasChapters && coverPath == '') {
      // use the first image in the first chapter as the cover
      var firstChapter = Directory('${directory.path}/${chapters.first}');
      await for(var entry in firstChapter.list()) {
        if(entry is File) {
          coverPath = entry.name;
          break;
        }
      }
    }
    if(coverPath == '') {
      Log.info("Import Comic", "Invalid Comic: $name\nNo cover image found.");
      return null;
    }
    return LocalComic(
      id: 0,
      title: name,
      subtitle: '',
      tags: [],
      directory: directory.name,
      chapters: Map.fromIterables(chapters, chapters),
      cover: coverPath,
      comicType: ComicType.local,
      createdAt: DateTime.now(),
    );
  }
}
