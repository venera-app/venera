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

  Map<Comic, bool> selectedComics = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  String keyword = "";

  bool searchMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  void updateComics() {
    if (keyword.isEmpty) {
      setState(() {
        comics = LocalFavoritesManager().getAllComics(widget.folder);
      });
    } else {
      setState(() {
        comics = LocalFavoritesManager().search(keyword);
      });
    }
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
    void selectAll() {
      setState(() {
        selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
      });
    }

    void invertSelection() {
      setState(() {
        comics.asMap().forEach((k, v) {
          selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
        });
        selectedComics.removeWhere((k, v) => !v);
      });
    }

    var body = Scaffold(
      body: SmoothCustomScrollView(slivers: [
        if (!searchMode && !multiSelectMode)
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
              child: Text(favPage.folder ?? "Unselected".tl),
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
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      searchMode = true;
                    });
                  },
                ),
              ),
              MenuButton(
                entries: [
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
                ],
              ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
                "Selected @c comics".tlParams({"c": selectedComics.length})),
            actions: [
              MenuButton(entries: [
                MenuEntry(
                    icon: Icons.star,
                    text: "Add to favorites".tl,
                    onClick: () => favoriteOption('move')),
                MenuEntry(
                    icon: Icons.drive_file_move,
                    text: "Move to favorites".tl,
                    onClick: () => favoriteOption('add')),
                MenuEntry(
                    icon: Icons.select_all,
                    text: "Select All".tl,
                    onClick: selectAll),
                MenuEntry(
                    icon: Icons.deselect,
                    text: "Deselect".tl,
                    onClick: _cancel),
                MenuEntry(
                    icon: Icons.flip,
                    text: "Invert Selection".tl,
                    onClick: invertSelection),
                MenuEntry(
                    icon: Icons.delete_outline,
                    text: "Delete Folder".tl,
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
                    }),
              ]),
            ],
          )
        else if (searchMode)
          SliverAppbar(
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    searchMode = false;
                    keyword = "";
                    updateComics();
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: InputBorder.none,
              ),
              onChanged: (v) {
                keyword = v;
                updateComics();
              },
            ),
          ),
        SliverGridComics(
          comics: comics,
          selections: selectedComics,
          onTap: multiSelectMode
              ? (c) {
                  setState(() {
                    if (selectedComics.containsKey(c as FavoriteItem)) {
                      selectedComics.remove(c);
                      _checkExitSelectMode();
                    } else {
                      selectedComics[c] = true;
                    }
                    lastSelectedIndex = comics.indexOf(c);
                  });
                }
              : (c) {
                  App.mainNavigatorKey?.currentContext
                      ?.to(() => ComicPage(id: c.id, sourceKey: c.sourceKey));
                },
          onLongPressed: (c) {
            setState(() {
              if (!multiSelectMode) {
                multiSelectMode = true;
                if (!selectedComics.containsKey(c as FavoriteItem)) {
                  selectedComics[c] = true;
                }
                lastSelectedIndex = comics.indexOf(c);
              } else {
                if (lastSelectedIndex != null) {
                  int start = lastSelectedIndex!;
                  int end = comics.indexOf(c as FavoriteItem);
                  if (start > end) {
                    int temp = start;
                    start = end;
                    end = temp;
                  }

                  for (int i = start; i <= end; i++) {
                    if (i == lastSelectedIndex) continue;

                    var comic = comics[i];
                    if (selectedComics.containsKey(comic)) {
                      selectedComics.remove(comic);
                    } else {
                      selectedComics[comic] = true;
                    }
                  }
                }
                lastSelectedIndex = comics.indexOf(c as FavoriteItem);
              }
              _checkExitSelectMode();
            });
          },
        ),
      ]),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            updateComics();
          });
        }
      },
      child: body,
    );
  }

  void favoriteOption(String option) {
    var targetFolders = LocalFavoritesManager()
        .folderNames
        .where((folder) => folder != favPage.folder)
        .toList();

    showDialog(
      context: App.rootContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Container(
                    constraints:
                        const BoxConstraints(maxHeight: 700, maxWidth: 500),
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12.0),
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              favPage.folder ?? "Unselected".tl,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: targetFolders.length + 1,
                            itemBuilder: (context, index) {
                              if (index == targetFolders.length) {
                                return SizedBox(
                                  height: 36,
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () {
                                        newFolder().then((v) {
                                          setState(() {
                                            targetFolders =
                                                LocalFavoritesManager()
                                                    .folderNames
                                                    .where((folder) =>
                                                        folder !=
                                                        favPage.folder)
                                                    .toList();
                                          });
                                        });
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add, size: 20),
                                          const SizedBox(width: 4),
                                          Text("New Folder".tl),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              var folder = targetFolders[index];
                              var disabled = false;
                              if (selectedLocalFolders.isNotEmpty) {
                                if (added.contains(folder) &&
                                    !added
                                        .contains(selectedLocalFolders.first)) {
                                  disabled = true;
                                } else if (!added.contains(folder) &&
                                    added
                                        .contains(selectedLocalFolders.first)) {
                                  disabled = true;
                                }
                              }
                              return CheckboxListTile(
                                title: Row(
                                  children: [
                                    Text(folder),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                                value: selectedLocalFolders.contains(folder),
                                onChanged: disabled
                                    ? null
                                    : (v) {
                                        setState(() {
                                          if (v!) {
                                            selectedLocalFolders.add(folder);
                                          } else {
                                            selectedLocalFolders.remove(folder);
                                          }
                                        });
                                      },
                              );
                            },
                          ),
                        ),
                        Center(
                          child: FilledButton(
                            onPressed: () {
                              if (selectedLocalFolders.isEmpty) {
                                return;
                              }
                              if (option == 'move') {
                                for (var c in selectedComics.keys) {
                                  for (var s in selectedLocalFolders) {
                                    LocalFavoritesManager().moveFavorite(
                                        favPage.folder as String,
                                        s,
                                        c.id,
                                        (c as FavoriteItem).type);
                                  }
                                }
                              } else {
                                for (var c in selectedComics.keys) {
                                  for (var s in selectedLocalFolders) {
                                    LocalFavoritesManager().addComic(
                                      s,
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
                                }
                              }
                              context.pop();
                              updateComics();
                              _cancel();
                            },
                            child:
                                Text(option == 'move' ? "Move".tl : "Add".tl),
                          ).paddingVertical(16),
                        ),
                      ],
                    ),
                  ),
                ));
          },
        );
      },
    );
  }

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
    });
  }

  void _deleteComicWithId() {
    for (var c in selectedComics.keys) {
      LocalFavoritesManager().deleteComicWithId(
        widget.folder,
        c.id,
        (c as FavoriteItem).type,
      );
    }
    updateComics();
    _cancel();
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
