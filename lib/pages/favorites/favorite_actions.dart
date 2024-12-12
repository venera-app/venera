part of 'favorites_page.dart';

/// Open a dialog to create a new favorite folder.
Future<void> newFolder() async {
  return showDialog(
      context: App.rootContext,
      builder: (context) {
        var controller = TextEditingController();
        String? error;

        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "New Folder".tl,
            content: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Folder Name".tl,
                    errorText: error,
                  ),
                  onChanged: (s) {
                    if (error != null) {
                      setState(() {
                        error = null;
                      });
                    }
                  },
                ),
              ],
            ).paddingHorizontal(16),
            actions: [
              TextButton(
                child: Text("Import from file".tl),
                onPressed: () async {
                  var file = await selectFile(ext: ['json']);
                  if (file == null) return;
                  var data = await file.readAsBytes();
                  try {
                    LocalFavoritesManager().fromJson(utf8.decode(data));
                  } catch (e) {
                    context.showMessage(message: "Failed to import".tl);
                    return;
                  }
                  context.pop();
                },
              ).paddingRight(4),
              FilledButton(
                onPressed: () {
                  var e = validateFolderName(controller.text);
                  if (e != null) {
                    setState(() {
                      error = e;
                    });
                  } else {
                    LocalFavoritesManager().createFolder(controller.text);
                    context.pop();
                  }
                },
                child: Text("Create".tl),
              ),
            ],
          );
        });
      });
}

String? validateFolderName(String newFolderName) {
  var folders = LocalFavoritesManager().folderNames;
  if (newFolderName.isEmpty) {
    return "Folder name cannot be empty".tl;
  } else if (newFolderName.length > 50) {
    return "Folder name is too long".tl;
  } else if (folders.contains(newFolderName)) {
    return "Folder already exists".tl;
  }
  return null;
}

void addFavorite(Comic comic) {
  var folders = LocalFavoritesManager().folderNames;

  showDialog(
    context: App.rootContext,
    builder: (context) {
      String? selectedFolder = appdata.settings['quickFavorite'];

      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "Select a folder".tl,
          content: ListTile(
            title: Text("Folder".tl),
            trailing: Select(
              current: selectedFolder,
              values: folders,
              minWidth: 112,
              onTap: (v) {
                setState(() {
                  selectedFolder = folders[v];
                });
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (selectedFolder != null) {
                  LocalFavoritesManager().addComic(
                    selectedFolder!,
                    FavoriteItem(
                      id: comic.id,
                      name: comic.title,
                      coverPath: comic.cover,
                      author: comic.subtitle ?? '',
                      type: ComicType((comic.sourceKey == 'local'
                          ? 0
                          : comic.sourceKey.hashCode)),
                      tags: comic.tags ?? [],
                    ),
                  );
                  context.pop();
                }
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );
}

Future<List<FavoriteItem>> updateComicsInfo(String folder) async {
  var comics = LocalFavoritesManager().getAllComics(folder);

  Future<void> updateSingleComic(int index) async {
    int retry = 3;

    while (true) {
      try {
        var c = comics[index];
        var comicSource = c.type.comicSource;
        if (comicSource == null) return;

        var newInfo = (await comicSource.loadComicInfo!(c.id)).data;

        comics[index] = FavoriteItem(
          id: c.id,
          name: newInfo.title,
          coverPath: newInfo.cover,
          author: newInfo.subTitle ??
              newInfo.tags['author']?.firstOrNull ??
              c.author,
          type: c.type,
          tags: c.tags,
        );

        LocalFavoritesManager().updateInfo(folder, comics[index]);
        return;
      } catch (e) {
        retry--;
        if (retry == 0) {
          rethrow;
        }
        continue;
      }
    }
  }

  var finished = ValueNotifier(0);

  var errors = 0;

  var index = 0;

  bool isCanceled = false;

  showDialog(
    context: App.rootContext,
    builder: (context) {
      return ValueListenableBuilder(
        valueListenable: finished,
        builder: (context, value, child) {
          var isFinished = value == comics.length;
          return ContentDialog(
            title: isFinished ? "Finished".tl : "Updating".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: value / comics.length,
                ),
                const SizedBox(height: 4),
                Text("$value/${comics.length}"),
                const SizedBox(height: 4),
                if (errors > 0) Text("Errors: $errors"),
              ],
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                color: isFinished ? null : context.colorScheme.error,
                onPressed: () {
                  isCanceled = true;
                  context.pop();
                },
                child: isFinished ? Text("OK".tl) : Text("Cancel".tl),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    isCanceled = true;
  });

  while (index < comics.length) {
    var futures = <Future>[];
    const maxConcurrency = 4;

    if (isCanceled) {
      return comics;
    }

    for (var i = 0; i < maxConcurrency; i++) {
      if (index + i >= comics.length) break;
      futures.add(updateSingleComic(index + i).then((v) {
        finished.value++;
      }, onError: (_) {
        errors++;
        finished.value++;
      }));
    }

    await Future.wait(futures);
    index += maxConcurrency;
  }

  return comics;
}

Future<void> sortFolders() async {
  var folders = LocalFavoritesManager().folderNames;

  await showPopUpWidget(
    App.rootContext,
    StatefulBuilder(builder: (context, setState) {
      return PopUpWidgetScaffold(
        title: "Sort".tl,
        tailing: [
          Tooltip(
            message: "Help".tl,
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showInfoDialog(
                  context: context,
                  title: "Reorder".tl,
                  content: "Long press and drag to reorder.".tl,
                );
              },
            ),
          )
        ],
        body: ReorderableListView.builder(
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) {
              newIndex--;
            }
            setState(() {
              var item = folders.removeAt(oldIndex);
              folders.insert(newIndex, item);
            });
          },
          itemCount: folders.length,
          itemBuilder: (context, index) {
            return ListTile(
              key: ValueKey(folders[index]),
              title: Text(folders[index]),
            );
          },
        ),
      );
    }),
  );

  LocalFavoritesManager().updateOrder(folders);
}

Future<void> importNetworkFolder(
  String source,
  String? folder,
  String? folderID,
) async {
  var comicSource = ComicSource.find(source);
  if (comicSource == null) {
    return;
  }
  if(folder != null && folder.isEmpty) {
    folder = null;
  }
  var resultName = folder ?? comicSource.name;
  var exists = LocalFavoritesManager().existsFolder(resultName);
  if (exists) {
    if (!LocalFavoritesManager()
        .isLinkedToNetworkFolder(resultName, source, folderID ?? "")) {
      App.rootContext.showMessage(message: "Folder already exists".tl);
      return;
    }
  }
  if(!exists) {
    LocalFavoritesManager().createFolder(resultName);
    LocalFavoritesManager().linkFolderToNetwork(
      resultName,
      source,
      folderID ?? "",
    );
  }

  var current = 0;
  var isFinished = false;
  String? next;

  Future<void> fetchNext() async {
    var retry = 3;

    while (true) {
      try {
        if (comicSource.favoriteData?.loadComic != null) {
          next ??= '1';
          var page = int.parse(next!);
          var res = await comicSource.favoriteData!.loadComic!(page, folderID);
          var count = 0;
          for (var c in res.data) {
            var result = LocalFavoritesManager().addComic(
              resultName,
              FavoriteItem(
                id: c.id,
                name: c.title,
                coverPath: c.cover,
                type: ComicType(source.hashCode),
                author: c.subtitle ?? '',
                tags: c.tags ?? [],
              ),
            );
            if (result) {
              count++;
            }
          }
          current += count;
          if (res.data.isEmpty || res.subData == page) {
            isFinished = true;
            next = null;
          } else {
            next = (page + 1).toString();
          }
        } else if (comicSource.favoriteData?.loadNext != null) {
          var res = await comicSource.favoriteData!.loadNext!(next, folderID);
          var count = 0;
          for (var c in res.data) {
            var result = LocalFavoritesManager().addComic(
              resultName,
              FavoriteItem(
                id: c.id,
                name: c.title,
                coverPath: c.cover,
                type: ComicType(source.hashCode),
                author: c.subtitle ?? '',
                tags: c.tags ?? [],
              ),
            );
            if (result) {
              count++;
            }
          }
          current += count;
          if (res.data.isEmpty || res.subData == null) {
            isFinished = true;
            next = null;
          } else {
            next = res.subData;
          }
        } else {
          throw "Unsupported source";
        }
        return;
      } catch (e) {
        retry--;
        if (retry == 0) {
          rethrow;
        }
        continue;
      }
    }
  }

  bool isCanceled = false;
  String? errorMsg;
  bool isErrored() => errorMsg != null;

  void Function()? updateDialog;

  showDialog(
    context: App.rootContext,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          updateDialog = () => setState(() {});
          return ContentDialog(
            title: isFinished
                ? "Finished".tl
                : isErrored()
                    ? "Error".tl
                    : "Importing".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: isFinished ? 1 : null,
                ),
                const SizedBox(height: 4),
                Text("Imported @c comics".tlParams({
                  "c": current,
                })),
                const SizedBox(height: 4),
                if (isErrored()) Text("Error: $errorMsg"),
              ],
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                color: (isFinished || isErrored())
                    ? null
                    : context.colorScheme.error,
                onPressed: () {
                  isCanceled = true;
                  context.pop();
                },
                child: (isFinished || isErrored())
                    ? Text("OK".tl)
                    : Text("Cancel".tl),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    isCanceled = true;
  });

  while (!isFinished && !isCanceled) {
    try {
      await fetchNext();
      updateDialog?.call();
    } catch (e) {
      errorMsg = e.toString();
      updateDialog?.call();
      break;
    }
  }
}
