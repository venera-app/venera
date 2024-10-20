part of 'favorites_page.dart';

Future<bool> _deleteComic(
  String cid,
  String? fid,
  String sourceKey,
  String? favId,
) async {
  var source = ComicSource.find(sourceKey);
  if (source == null) {
    return false;
  }

  var result = false;

  await showDialog(
    context: App.rootContext,
    builder: (context) {
      bool loading = false;
      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "Delete".tl,
          content: Text("Are you sure you want to delete this comic?".tl)
              .paddingHorizontal(16),
          actions: [
            Button.filled(
              isLoading: loading,
              color: context.colorScheme.error,
              onPressed: () async {
                setState(() {
                  loading = true;
                });
                var res = await source.favoriteData!.addOrDelFavorite!(
                  cid,
                  fid ?? '',
                  false,
                  favId,
                );
                if (res.success) {
                  context.showMessage(message: "Deleted".tl);
                  result = true;
                  context.pop();
                } else {
                  setState(() {
                    loading = false;
                  });
                  context.showMessage(message: res.errorMessage!);
                }
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );

  return result;
}

class NetworkFavoritePage extends StatelessWidget {
  const NetworkFavoritePage(this.data, {super.key});

  final FavoriteData data;

  @override
  Widget build(BuildContext context) {
    return data.multiFolder
        ? _MultiFolderFavoritesPage(data)
        : _NormalFavoritePage(data);
  }
}

class _NormalFavoritePage extends StatelessWidget {
  _NormalFavoritePage(this.data);

  final FavoriteData data;

  final comicListKey = GlobalKey<ComicListState>();

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      leadingSliver: SliverAppbar(
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= _kTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: context
                      .findAncestorStateOfType<_FavoritesPageState>()!
                      .showFolderSelector,
                )
              : null,
        ),
        title: Text(data.title),
      ),
      errorLeading: Appbar(
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= _kTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: context
                      .findAncestorStateOfType<_FavoritesPageState>()!
                      .showFolderSelector,
                )
              : null,
        ),
        title: Text(data.title),
      ),
      loadPage: (i) => data.loadComic(i),
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
    );
  }
}

class _MultiFolderFavoritesPage extends StatefulWidget {
  const _MultiFolderFavoritesPage(this.data);

  final FavoriteData data;

  @override
  State<_MultiFolderFavoritesPage> createState() =>
      _MultiFolderFavoritesPageState();
}

class _MultiFolderFavoritesPageState extends State<_MultiFolderFavoritesPage> {
  bool _loading = true;

  String? _errorMessage;

  Map<String, String>? folders;

  void loadPage() async {
    var res = await widget.data.loadFolders!();
    _loading = false;
    if (res.error) {
      setState(() {
        _errorMessage = res.errorMessage;
      });
    } else {
      setState(() {
        folders = res.data;
      });
    }
  }

  void openFolder(String key, String title) {
    context.to(() => _FavoriteFolder(widget.data, key, title));
  }

  @override
  Widget build(BuildContext context) {
    var sliverAppBar = SliverAppbar(
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= _kTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: context
                    .findAncestorStateOfType<_FavoritesPageState>()!
                    .showFolderSelector,
              )
            : null,
      ),
      title: Text(widget.data.title),
    );

    var appBar = Appbar(
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= _kTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: context
                    .findAncestorStateOfType<_FavoritesPageState>()!
                    .showFolderSelector,
              )
            : null,
      ),
      title: Text(widget.data.title),
    );

    if (_loading) {
      loadPage();
      return Column(
        children: [
          appBar,
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    } else if (_errorMessage != null) {
      return Column(
        children: [
          appBar,
          Expanded(
            child: NetworkError(
              message: _errorMessage!,
              withAppbar: false,
              retry: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
              },
            ),
          )
        ],
      );
    } else {
      var length = folders!.length;
      if (widget.data.allFavoritesId != null) length++;
      final keys = folders!.keys.toList();

      return SmoothCustomScrollView(
        slivers: [
          sliverAppBar,
          SliverGridViewWithFixedItemHeight(
            delegate:
                SliverChildBuilderDelegate(childCount: length, (context, i) {
              if (widget.data.allFavoritesId != null) {
                if (i == 0) {
                  return _FolderTile(
                      name: "All".tl,
                      onTap: () =>
                          openFolder(widget.data.allFavoritesId!, "All".tl));
                } else {
                  i--;
                  return _FolderTile(
                    name: folders![keys[i]]!,
                    onTap: () => openFolder(keys[i], folders![keys[i]]!),
                    deleteFolder: widget.data.deleteFolder == null
                        ? null
                        : () => widget.data.deleteFolder!(keys[i]),
                    updateState: () => setState(() {
                      _loading = true;
                    }),
                  );
                }
              } else {
                return _FolderTile(
                  name: folders![keys[i]]!,
                  onTap: () => openFolder(keys[i], folders![keys[i]]!),
                  deleteFolder: widget.data.deleteFolder == null
                      ? null
                      : () => widget.data.deleteFolder!(keys[i]),
                  updateState: () => setState(() {
                    _loading = true;
                  }),
                );
              }
            }),
            maxCrossAxisExtent: 450,
            itemHeight: 64,
          ),
          if (widget.data.addFolder != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: Center(
                  child: TextButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Create a folder".tl),
                        const Icon(
                          Icons.add,
                          size: 18,
                        ),
                      ],
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _CreateFolderDialog(
                            widget.data,
                            () => setState(() {
                              _loading = true;
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            )
        ],
      );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile(
      {required this.name,
      required this.onTap,
      this.deleteFolder,
      this.updateState});

  final String name;

  final Future<Res<bool>> Function()? deleteFolder;

  final void Function()? updateState;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
              ),
              Icon(
                Icons.folder,
                size: 35,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (deleteFolder != null)
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: () => onDeleteFolder(context),
                )
              else
                const Icon(Icons.arrow_right),
              if (deleteFolder == null)
                const SizedBox(
                  width: 8,
                )
            ],
          ),
        ),
      ),
    );
  }

  void onDeleteFolder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool loading = false;
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Delete".tl,
            content: Text("Are you sure you want to delete this folder?".tl).paddingHorizontal(16),
            actions: [
              Button.filled(
                isLoading: loading,
                color: context.colorScheme.error,
                onPressed: () async {
                  setState(() {
                    loading = true;
                  });
                  var res = await deleteFolder!();
                  if (res.success) {
                    context.showMessage(message: "Deleted".tl);
                    context.pop();
                    updateState?.call();
                  } else {
                    setState(() {
                      loading = false;
                    });
                    context.showMessage(message: res.errorMessage!);
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
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog(this.data, this.updateState);

  final FavoriteData data;

  final void Function() updateState;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  var controller = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text("Create a folder".tl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "name".tl,
            ),
          ),
        ),
        const SizedBox(
          width: 200,
          height: 10,
        ),
        if (loading)
          Center(
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ).fixWidth(24).fixHeight(24),
          )
        else
          SizedBox(
            height: 35,
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                  });
                  widget.data.addFolder!(controller.text).then((b) {
                    if (b.error) {
                      context.showMessage(message: b.errorMessage!);
                      setState(() {
                        loading = false;
                      });
                    } else {
                      context.pop();
                      context.showMessage(message: "Created successfully".tl);
                      widget.updateState();
                    }
                  });
                },
                child: Text("Submit".tl),
              ),
            ),
          )
      ],
    );
  }
}

class _FavoriteFolder extends StatelessWidget {
  _FavoriteFolder(this.data, this.folderID, this.title);

  final FavoriteData data;

  final String folderID;

  final String title;

  final comicListKey = GlobalKey<ComicListState>();

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      leadingSliver: SliverAppbar(
        title: Text(title),
      ),
      errorLeading: Appbar(
        title: Text(title),
      ),
      loadPage: (i) => data.loadComic(i, folderID),
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
    );
  }
}
