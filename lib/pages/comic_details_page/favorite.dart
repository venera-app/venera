part of 'comic_page.dart';

class _FavoritePanel extends StatefulWidget {
  const _FavoritePanel({
    required this.cid,
    required this.type,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteItem,
    this.updateTime,
  });

  final String cid;

  final ComicType type;

  /// whether the comic is in the network favorite list
  ///
  /// if null, the comic source does not support favorite or support multiple favorite lists
  final bool? isFavorite;

  final void Function(bool?, bool?) onFavorite;

  final FavoriteItem favoriteItem;

  final String? updateTime;

  @override
  State<_FavoritePanel> createState() => _FavoritePanelState();
}

class _FavoritePanelState extends State<_FavoritePanel>
    with SingleTickerProviderStateMixin {
  late ComicSource comicSource;

  late TabController tabController;

  late bool hasNetwork;

  @override
  void initState() {
    comicSource = widget.type.comicSource!;
    localFolders = LocalFavoritesManager().folderNames;
    added = LocalFavoritesManager().find(widget.cid, widget.type);
    hasNetwork = comicSource.favoriteData != null && comicSource.isLogged;
    var initIndex = 0;
    if (appdata.implicitData['favoritePanelIndex'] is int) {
      initIndex = appdata.implicitData['favoritePanelIndex'];
    }
    initIndex = initIndex.clamp(0, hasNetwork ? 1 : 0);
    tabController = TabController(
      initialIndex: initIndex,
      length: hasNetwork ? 2 : 1,
      vsync: this,
    );
    super.initState();
  }

  @override
  void dispose() {
    var currentIndex = tabController.index;
    appdata.implicitData['favoritePanelIndex'] = currentIndex;
    appdata.writeImplicitData();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Favorite".tl),
      ),
      body: Column(
        children: [
          TabBar(
            controller: tabController,
            tabs: [
              Tab(text: "Local".tl),
              if (hasNetwork) Tab(text: "Network".tl),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                buildLocal(),
                if (hasNetwork) buildNetwork(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  late List<String> localFolders;

  late List<String> added;

  var selectedLocalFolders = <String>{};

  Widget buildLocal() {
    var isRemove = selectedLocalFolders.isNotEmpty &&
        added.contains(selectedLocalFolders.first);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: localFolders.length + 1,
            itemBuilder: (context, index) {
              if (index == localFolders.length) {
                return SizedBox(
                  height: 36,
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        newFolder().then((v) {
                          setState(() {
                            localFolders = LocalFavoritesManager().folderNames;
                          });
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 20),
                          const SizedBox(width: 4),
                          Text("New Folder".tl)
                        ],
                      ),
                    ),
                  ),
                );
              }
              var folder = localFolders[index];
              var disabled = false;
              if (selectedLocalFolders.isNotEmpty) {
                if (added.contains(folder) &&
                    !added.contains(selectedLocalFolders.first)) {
                  disabled = true;
                } else if (!added.contains(folder) &&
                    added.contains(selectedLocalFolders.first)) {
                  disabled = true;
                }
              }
              return CheckboxListTile(
                title: Row(
                  children: [
                    Text(folder),
                    const SizedBox(width: 8),
                    if (added.contains(folder))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("Added".tl, style: ts.s12),
                      ),
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
              if (isRemove) {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager()
                      .deleteComicWithId(folder, widget.cid, widget.type);
                }
                widget.onFavorite(false, null);
              } else {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager().addComic(
                    folder,
                    widget.favoriteItem,
                    null,
                    widget.updateTime,
                  );
                }
                widget.onFavorite(true, null);
              }
              context.pop();
            },
            child: isRemove ? Text("Remove".tl) : Text("Add".tl),
          ).paddingVertical(8),
        ),
      ],
    );
  }

  Widget buildNetwork() {
    return _NetworkFavorites(
      cid: widget.cid,
      comicSource: comicSource,
      isFavorite: widget.isFavorite,
      onFavorite: (network) {
        widget.onFavorite(null, network);
      },
    );
  }
}

class _NetworkFavorites extends StatefulWidget {
  const _NetworkFavorites({
    required this.cid,
    required this.comicSource,
    required this.isFavorite,
    required this.onFavorite,
  });

  final String cid;

  final ComicSource comicSource;

  final bool? isFavorite;

  final void Function(bool) onFavorite;

  @override
  State<_NetworkFavorites> createState() => _NetworkFavoritesState();
}

class _NetworkFavoritesState extends State<_NetworkFavorites> {
  @override
  Widget build(BuildContext context) {
    bool isMultiFolder = widget.comicSource.favoriteData!.loadFolders != null;

    return isMultiFolder ? buildMultiFolder() : buildSingleFolder();
  }

  bool isLoading = false;

  Widget buildSingleFolder() {
    var isFavorite = widget.isFavorite ?? false;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(isFavorite ? "Added to favorites".tl : "Not added".tl),
          ),
        ),
        Center(
          child: Button.filled(
            isLoading: isLoading,
            onPressed: () async {
              setState(() {
                isLoading = true;
              });

              var res = await widget.comicSource.favoriteData!
                  .addOrDelFavorite!(widget.cid, '', !isFavorite, null);
              if (res.success) {
                widget.onFavorite(!isFavorite);
                context.pop();
                App.rootContext.showMessage(
                    message: isFavorite ? "Removed".tl : "Added".tl);
              } else {
                setState(() {
                  isLoading = false;
                });
                context.showMessage(message: res.errorMessage!);
              }
            },
            child: isFavorite ? Text("Remove".tl) : Text("Add".tl),
          ).paddingVertical(8),
        ),
      ],
    );
  }

  Map<String, String>? folders;

  var addedFolders = <String>{};

  var isLoadingFolders = true;

  // for network favorites, only one selection is allowed
  String? selected;

  void loadFolders() async {
    var res = await widget.comicSource.favoriteData!.loadFolders!(widget.cid);
    if (res.error) {
      context.showMessage(message: res.errorMessage!);
    } else {
      folders = res.data;
      if (res.subData is List) {
        addedFolders = List<String>.from(res.subData).toSet();
      }
      setState(() {
        isLoadingFolders = false;
      });
    }
  }

  Widget buildMultiFolder() {
    if (widget.isFavorite == true &&
        widget.comicSource.favoriteData!.singleFolderForSingleComic) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Text("Added to favorites".tl),
            ),
          ),
          Center(
            child: Button.filled(
              isLoading: isLoading,
              onPressed: () async {
                setState(() {
                  isLoading = true;
                });

                var res = await widget.comicSource.favoriteData!
                    .addOrDelFavorite!(widget.cid, '', false, null);
                if (res.success) {
                  widget.onFavorite(false);
                  context.pop();
                  App.rootContext.showMessage(message: "Removed".tl);
                } else {
                  setState(() {
                    isLoading = false;
                  });
                  context.showMessage(message: res.errorMessage!);
                }
              },
              child: Text("Remove".tl),
            ).paddingVertical(8),
          ),
        ],
      );
    }
    if (isLoadingFolders) {
      loadFolders();
      return const Center(child: CircularProgressIndicator());
    } else {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: folders!.length,
              itemBuilder: (context, index) {
                var name = folders!.values.elementAt(index);
                var id = folders!.keys.elementAt(index);
                return CheckboxListTile(
                  title: Row(
                    children: [
                      Text(name),
                      const SizedBox(width: 8),
                      if (addedFolders.contains(id))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("Added".tl, style: ts.s12),
                        ),
                    ],
                  ),
                  value: selected == id,
                  onChanged: (v) {
                    setState(() {
                      selected = id;
                    });
                  },
                );
              },
            ),
          ),
          Center(
            child: Button.filled(
              isLoading: isLoading,
              onPressed: () async {
                if (selected == null) {
                  return;
                }
                setState(() {
                  isLoading = true;
                });
                var res =
                    await widget.comicSource.favoriteData!.addOrDelFavorite!(
                  widget.cid,
                  selected!,
                  !addedFolders.contains(selected!),
                  null,
                );
                if (res.success) {
                  context.showMessage(message: "Success".tl);
                  context.pop();
                } else {
                  context.showMessage(message: res.errorMessage!);
                  setState(() {
                    isLoading = false;
                  });
                }
              },
              child: selected != null && addedFolders.contains(selected!)
                  ? Text("Remove".tl)
                  : Text("Add".tl),
            ).paddingVertical(8),
          ),
        ],
      );
    }
  }
}
