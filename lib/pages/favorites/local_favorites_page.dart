part of 'favorites_page.dart';

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  final Set<FavoriteItem> selectedComics = {};

  bool isSelectMode = false;

  bool enableLongPressed = false;

  int? lastSelectedIndex;
  bool isRangeSelecting = false;

  Timer? longPressTimer;

  void updateComics() {
    setState(() {
      comics = LocalFavoritesManager().getAllComics(widget.folder);
    });
  }

  @override
  void initState() {
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    comics = LocalFavoritesManager().getAllComics(widget.folder);
    var (a, b) = LocalFavoritesManager().findLinked(widget.folder);
    networkSource = a;
    networkFolder = b;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          leading: Tooltip(
            message: "Folders".tl,
            child: context.width <= _kTwoPanelChangeWidth
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    color: context.colorScheme.primary,
                    onPressed: favPage.showFolderSelector,
                  )
                : const SizedBox(),
          ),
          title: GestureDetector(
            onTap: context.width < _kTwoPanelChangeWidth
                ? favPage.showFolderSelector
                : null,
            child: isSelectMode
                ? Text('@num items selected'.tlParams({
                    'num': selectedComics.length,
                  }))
                : Text(favPage.folder ?? "Unselected".tl),
          ),
          actions: [
            if (networkSource != null)
              Tooltip(
                message: "Sync".tl,
                child: Flyout(
                  flyoutBuilder: (context) {
                    var sourceName = ComicSource.find(networkSource!)?.name ??
                        networkSource!;
                    var text = "The folder is Linked to @source".tlParams({
                      "source": sourceName,
                    });
                    if (networkFolder != null && networkFolder!.isNotEmpty) {
                      text += "\n${"Source Folder".tl}: $networkFolder";
                    }
                    return FlyoutContent(
                      title: "Sync".tl,
                      content: Text(text),
                      actions: [
                        Button.filled(
                          child: Text("Update".tl),
                          onPressed: () {
                            context.pop();
                            importNetworkFolder(
                              networkSource!,
                              widget.folder,
                              networkFolder!,
                            ).then(
                              (value) {
                                updateComics();
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                  child: Builder(builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: () {
                        Flyout.of(context).show();
                      },
                    );
                  }),
                ),
              ),
            MenuButton(
              entries: [
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      onClick: () {
                        showConfirmDialog(
                          context: App.rootContext,
                          title: "Delete".tl,
                          content:
                              "Are you sure you want to delete this folder?".tl,
                          onConfirm: () {
                            favPage.setFolder(false, null);
                            LocalFavoritesManager().deleteFolder(widget.folder);
                            favPage.folderList?.updateFolders();
                          },
                        );
                      }),
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.edit_outlined,
                      text: "Rename".tl,
                      onClick: () {
                        showInputDialog(
                          context: App.rootContext,
                          title: "Rename".tl,
                          hintText: "New Name".tl,
                          onConfirm: (value) {
                            var err = validateFolderName(value.toString());
                            if (err != null) {
                              return err;
                            }
                            LocalFavoritesManager().rename(
                              widget.folder,
                              value.toString(),
                            );
                            favPage.folderList?.updateFolders();
                            favPage.setFolder(false, value.toString());
                            return null;
                          },
                        );
                      }),
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.reorder,
                      text: "Reorder".tl,
                      onClick: () {
                        context.to(
                          () {
                            return _ReorderComicsPage(
                              widget.folder,
                              (comics) {
                                this.comics = comics;
                              },
                            );
                          },
                        ).then(
                          (value) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        );
                      }),
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export".tl,
                      onClick: () {
                        var json = LocalFavoritesManager().folderToJson(
                          widget.folder,
                        );
                        saveFile(
                          data: utf8.encode(json),
                          filename: "${widget.folder}.json",
                        );
                      }),
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.update,
                      text: "Update Comics Info".tl,
                      onClick: () {
                        updateComicsInfo(widget.folder).then((newComics) {
                          if (mounted) {
                            setState(() {
                              comics = newComics;
                            });
                          }
                        });
                      }),
                if (!isSelectMode)
                  MenuEntry(
                      icon: Icons.download,
                      text: "Download All".tl,
                      onClick: () async {
                        int count = 0;
                        for (var c in comics) {
                          if (await LocalManager().isDownloaded(c.id, c.type)) {
                            continue;
                          }
                          var comicSource = c.type.comicSource;
                          if (comicSource == null) {
                            continue;
                          }
                          LocalManager().addTask(ImagesDownloadTask(
                            source: comicSource,
                            comicId: c.id,
                            comic: null,
                            comicTitle: c.name,
                          ));
                          count++;
                        }
                        context.showMessage(
                            message: "Added @count comics to download queue."
                                .tlParams({
                          "count": count.toString(),
                        }));
                      }),
                if (isSelectMode)
                  MenuEntry(
                    icon: Icons.star,
                    text: 'Add to favorites'.tl,
                    onClick: () {
                      _addFavorite();
                    },
                  ),
                if (isSelectMode)
                  MenuEntry(
                    icon: Icons.select_all,
                    text: 'selectAll'.tl,
                    onClick: () {
                      _selectAll();
                    },
                  ),
                if (isSelectMode)
                  MenuEntry(
                    icon: Icons.deselect,
                    text: 'cancel'.tl,
                    onClick: () {
                      _cancel();
                    },
                  ),
                if (isSelectMode)
                  MenuEntry(
                    icon: Icons.delete_outline,
                    text: "Delete".tl,
                    onClick: () {
                      showConfirmDialog(
                        context: context,
                        title: "Delete".tl,
                        content:
                            "Are you sure you want to delete this comic?".tl,
                        onConfirm: () {
                          _deleteComicWithId();
                        },
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
        buildComicGrid(),
      ],
    );
  }

  void _addFavorite() {
    var folders = LocalFavoritesManager().folderNames;

    showDialog(
      context: App.rootContext,
      builder: (context) {
        String? selectedFolder;

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
                    for (var c in selectedComics) {
                      LocalFavoritesManager().addComic(
                        selectedFolder!,
                        FavoriteItem(
                          id: c.id,
                          name: c.title,
                          coverPath: c.cover,
                          author: c.subtitle ?? '',
                          type: ComicType((c.sourceKey == 'local'
                              ? 0
                              : c.sourceKey.hashCode)),
                          tags: c.tags ?? [],
                        ),
                      );
                    }
                    context.pop();
                    _cancel();
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

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        isSelectMode = false;
      });
    }
  }

  void _selectAll() {
    setState(() {
      isSelectMode = true;
      selectedComics.addAll(comics);
    });
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      isSelectMode = false;
    });
  }

  void _deleteComicWithId() {
    for (var a in selectedComics) {
      LocalFavoritesManager().deleteComicWithId(
        widget.folder,
        a.id,
        a.type,
      );
    }
    updateComics();
    _cancel();
  }

  Widget buildComicGrid() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          var comic = comics[index];
          bool isSelected = selectedComics.contains(comic);
          var type = appdata.settings['comicDisplayMode'];

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelectMode) {
                  if (isSelected) {
                    selectedComics.remove(comic);
                  } else {
                    selectedComics.add(comic);
                  }
                  enableLongPressed = false;
                  lastSelectedIndex = index;
                  _checkExitSelectMode();
                }
              });
            },
            onLongPressStart: (_) {
              setState(() {
                if (isSelected) {
                  enableLongPressed = true;
                }
              });
            },
            onLongPressEnd: (_) {
              longPressTimer = Timer(const Duration(milliseconds: 1000), () {
                setState(() {
                  enableLongPressed = false;
                });
              });
            },
            onLongPress: () {
              setState(() {
                if (!isSelectMode) {
                  isSelectMode = true;
                  if (!selectedComics.contains(comic)) {
                    selectedComics.add(comic);
                  }
                  lastSelectedIndex = index;
                } else {
                  if (isSelected) {}
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = index;
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }
                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;
                      if (selectedComics.contains(comics[i])) {
                        selectedComics.remove(comics[i]);
                      } else {
                        selectedComics.add(comics[i]);
                      }
                    }
                  }
                  lastSelectedIndex = index;
                }
                _checkExitSelectMode();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: Color(0xFFB0C6FF), width: 4)
                    : null,
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
              ),
              child: ComicTile(
                enableLongPressed:
                    (isSelectMode && isSelected && enableLongPressed)
                        ? true
                        : false,
                enableOnTap: isSelectMode ? false : true,
                key: Key(comic.hashCode.toString()),
                comic: Comic(
                  comic.name,
                  comic.coverPath,
                  comic.id,
                  comic.author,
                  comic.tags,
                  type == 'detailed'
                      ? "${comic.time} | ${comic.type.comicSource?.name ?? "Unknown"}"
                      : "${comic.type.comicSource?.name ?? "Unknown"} | ${comic.time}",
                  comic.type.comicSource?.key ?? "Unknown",
                  null,
                  null,
                ),
                menuOptions: [
                  MenuEntry(
                    icon: Icons.select_all,
                    text: 'selectAll'.tl,
                    onClick: () {
                      _selectAll();
                    },
                  ),
                  MenuEntry(
                    icon: Icons.deselect,
                    text: 'cancel'.tl,
                    onClick: () {
                      _cancel();
                    },
                  ),
                  MenuEntry(
                    icon: Icons.delete_outline,
                    text: "Delete".tl,
                    onClick: () {
                      showConfirmDialog(
                        context: context,
                        title: "Delete".tl,
                        content:
                            "Are you sure you want to delete this comic?".tl,
                        onConfirm: () {
                          _deleteComicWithId();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        childCount: comics.length,
      ),
      gridDelegate: SliverGridDelegateWithComics(),
    );
  }
}

class _ReorderComicsPage extends StatefulWidget {
  const _ReorderComicsPage(this.name, this.onReorder);

  final String name;

  final void Function(List<FavoriteItem>) onReorder;

  @override
  State<_ReorderComicsPage> createState() => _ReorderComicsPageState();
}

class _ReorderComicsPageState extends State<_ReorderComicsPage> {
  final _key = GlobalKey();
  var reorderWidgetKey = UniqueKey();
  final _scrollController = ScrollController();
  late var comics = LocalFavoritesManager().getAllComics(widget.name);
  bool changed = false;

  Color lightenColor(Color color, double lightenValue) {
    int red = (color.red + ((255 - color.red) * lightenValue)).round();
    int green = (color.green + ((255 - color.green) * lightenValue)).round();
    int blue = (color.blue + ((255 - color.blue) * lightenValue)).round();

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  @override
  void dispose() {
    if (changed) {
      LocalFavoritesManager().reorder(comics, widget.name);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['comicDisplayMode'];
    var tiles = comics.map(
      (e) {
        var comicSource = e.type.comicSource;
        return ComicTile(
          key: Key(e.hashCode.toString()),
          enableLongPressed: false,
          comic: Comic(
            e.name,
            e.coverPath,
            e.id,
            e.author,
            e.tags,
            type == 'detailed'
                ? "${e.time} | ${comicSource?.name ?? "Unknown"}"
                : "${e.type.comicSource?.name ?? "Unknown"} | ${e.time}",
            comicSource?.key ??
                (e.type == ComicType.local ? "local" : "Unknown"),
            null,
            null,
          ),
        );
      },
    ).toList();
    return Scaffold(
      appBar: Appbar(
        title: Text("Reorder".tl),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showInfoDialog(
                context: context,
                title: "Reorder".tl,
                content: "Long press and drag to reorder.".tl,
              );
            },
          ),
        ],
      ),
      body: ReorderableBuilder(
        key: reorderWidgetKey,
        scrollController: _scrollController,
        longPressDelay: App.isDesktop
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 500),
        onReorder: (reorderFunc) {
          changed = true;
          setState(() {
            comics = reorderFunc(comics) as List<FavoriteItem>;
          });
          widget.onReorder(comics);
        },
        dragChildBoxDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: lightenColor(
            Theme.of(context).splashColor.withOpacity(1),
            0.2,
          ),
        ),
        builder: (children) {
          return GridView(
            key: _key,
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithComics(),
            children: children,
          );
        },
        children: tiles,
      ),
    );
  }
}
