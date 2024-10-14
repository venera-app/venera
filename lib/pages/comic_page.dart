import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/network/download.dart';
import 'package:venera/pages/favorites/favorites_page.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
import 'dart:math' as math;

import 'comments_page.dart';

class ComicPage extends StatefulWidget {
  const ComicPage({super.key, required this.id, required this.sourceKey});

  final String id;

  final String sourceKey;

  @override
  State<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends LoadingState<ComicPage, ComicDetails>
    with _ComicPageActions {
  bool showAppbarTitle = false;

  var scrollController = ScrollController();

  bool isDownloaded = false;

  @override
  void initState() {
    scrollController.addListener(onScroll);
    super.initState();
  }

  @override
  void update() {
    setState(() {});
  }

  @override
  ComicDetails get comic => data!;

  void onScroll() {
    if (scrollController.offset > 100) {
      if (!showAppbarTitle) {
        setState(() {
          showAppbarTitle = true;
        });
      }
    } else {
      if (showAppbarTitle) {
        setState(() {
          showAppbarTitle = false;
        });
      }
    }
  }

  @override
  Widget buildContent(BuildContext context, ComicDetails data) {
    return SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        ...buildTitle(),
        buildActions(),
        buildDescription(),
        buildInfo(),
        buildChapters(),
        buildThumbnails(),
        buildRecommend(),
        SliverPadding(padding: EdgeInsets.only(bottom: context.padding.bottom)),
      ],
    );
  }

  @override
  Future<Res<ComicDetails>> loadData() async {
    var comicSource = ComicSource.find(widget.sourceKey);
    isAddToLocalFav = LocalFavoritesManager().isExist(
      widget.id,
      ComicType(widget.sourceKey.hashCode),
    );
    history = await HistoryManager()
        .find(widget.id, ComicType(widget.sourceKey.hashCode));
    return comicSource!.loadComicInfo!(widget.id);
  }

  @override
  Future<void> onDataLoaded() async {
    isLiked = comic.isLiked ?? false;
    isFavorite = comic.isFavorite ?? false;
    if (comic.chapters == null) {
      isDownloaded = await LocalManager().isDownloaded(
        comic.id,
        comic.comicType,
        0,
      );
    }
  }

  Iterable<Widget> buildTitle() sync* {
    yield SliverAppbar(
      title: AnimatedOpacity(
        opacity: showAppbarTitle ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(comic.title),
      ),
      actions: [
        IconButton(
            onPressed: showMoreActions, icon: const Icon(Icons.more_horiz))
      ],
    );

    yield const SliverPadding(padding: EdgeInsets.only(top: 8));

    yield Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          height: 144,
          width: 144 * 0.72,
          clipBehavior: Clip.antiAlias,
          child: AnimatedImage(
            image: CachedImageProvider(
              comic.cover,
              sourceKey: comic.sourceKey,
            ),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comic.title, style: ts.s18),
              if (comic.subTitle != null) Text(comic.subTitle!, style: ts.s14),
              Text(
                (ComicSource.find(comic.sourceKey)?.name) ?? '',
                style: ts.s12,
              ),
            ],
          ),
        ),
      ],
    ).toSliver();
  }

  Widget buildActions() {
    bool isMobile = context.width < changePoint;
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              if (history != null && (history!.ep > 1 || history!.page > 1))
                _ActionButton(
                  icon: const Icon(Icons.menu_book),
                  text: 'Continue'.tl,
                  onPressed: continueRead,
                  iconColor: context.useTextColor(Colors.yellow),
                ),
              if (!isMobile)
                _ActionButton(
                  icon: const Icon(Icons.play_circle_outline),
                  text: 'Read'.tl,
                  onPressed: read,
                  iconColor: context.useTextColor(Colors.orange),
                ),
              if (!isMobile && !isDownloaded)
                _ActionButton(
                  icon: const Icon(Icons.download),
                  text: 'Download'.tl,
                  onPressed: download,
                  iconColor: context.useTextColor(Colors.cyan),
                ),
              if (data!.isLiked != null)
                _ActionButton(
                  icon: const Icon(Icons.favorite_border),
                  activeIcon: const Icon(Icons.favorite),
                  isActive: isLiked,
                  text: (data!.likesCount ?? (isLiked ? 'Liked'.tl : 'Like'.tl))
                      .toString(),
                  isLoading: isLiking,
                  onPressed: likeOrUnlike,
                  iconColor: context.useTextColor(Colors.red),
                ),
              _ActionButton(
                icon: const Icon(Icons.bookmark_border),
                activeIcon: const Icon(Icons.bookmark),
                isActive: isFavorite || isAddToLocalFav,
                text: 'Favorite'.tl,
                onPressed: openFavPanel,
                iconColor: context.useTextColor(Colors.purple),
              ),
              if (comicSource.commentsLoader != null)
                _ActionButton(
                  icon: const Icon(Icons.comment),
                  text: (comic.commentsCount ?? 'Comments'.tl).toString(),
                  onPressed: showComments,
                  iconColor: context.useTextColor(Colors.green),
                ),
              _ActionButton(
                icon: const Icon(Icons.share),
                text: 'Share'.tl,
                onPressed: share,
                iconColor: context.useTextColor(Colors.blue),
              ),
            ],
          ).fixHeight(48),
          if (isMobile)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: download,
                    child: Text("Download".tl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(onPressed: read, child: Text("Read".tl)),
                )
              ],
            ).paddingHorizontal(16).paddingVertical(8),
          const Divider(),
        ],
      ).paddingTop(16),
    );
  }

  Widget buildDescription() {
    if (comic.description == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ListTile(
            title: Text("Description".tl),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(comic.description!).fixWidth(double.infinity),
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  Widget buildInfo() {
    if (comic.tags.isEmpty &&
        comic.uploader == null &&
        comic.uploadTime == null &&
        comic.uploadTime == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }

    int i = 0;

    Widget buildTag({
      required String text,
      VoidCallback? onTap,
      bool isTitle = false,
    }) {
      Color color;
      if (isTitle) {
        const colors = [
          Colors.blue,
          Colors.cyan,
          Colors.red,
          Colors.pink,
          Colors.purple,
          Colors.indigo,
          Colors.teal,
          Colors.green,
          Colors.lime,
          Colors.yellow,
        ];
        color = context.useBackgroundColor(colors[(i++) % (colors.length)]);
      } else {
        color = context.colorScheme.surfaceContainer;
      }

      final borderRadius = BorderRadius.circular(12);

      const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);

      if (onTap != null) {
        return Material(
          color: color,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: Text(text).padding(padding),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
          ),
          child: Text(text).padding(padding),
        );
      }
    }

    Widget buildWrap({required List<Widget> children}) {
      return Wrap(
        runSpacing: 8,
        spacing: 8,
        children: children,
      ).paddingHorizontal(16).paddingBottom(8);
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text("Information".tl),
          ),
          for (var e in comic.tags.entries)
            buildWrap(
              children: [
                buildTag(text: e.key, isTitle: true),
                for (var tag in e.value)
                  buildTag(text: tag, onTap: () => onTapTag(tag, e.key)),
              ],
            ),
          if (comic.uploader != null)
            buildWrap(
              children: [
                buildTag(text: 'Uploader'.tl, isTitle: true),
                buildTag(text: comic.uploader!),
              ],
            ),
          if (comic.uploadTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Upload Time'.tl, isTitle: true),
                buildTag(text: comic.uploadTime!),
              ],
            ),
          if (comic.uploadTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Update Time'.tl, isTitle: true),
                buildTag(text: comicSource.name),
              ],
            ),
          const SizedBox(height: 12),
          const Divider(),
        ],
      ),
    );
  }

  Widget buildChapters() {
    if (comic.chapters == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return const _ComicChapters();
  }

  Widget buildThumbnails() {
    if (comic.thumbnails == null && comicSource.loadComicThumbnail == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return const _ComicThumbnails();
  }

  Widget buildRecommend() {
    if (comic.recommend == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: ListTile(
          title: Text("Related".tl),
        ),
      ),
      SliverGridComics(comics: comic.recommend!),
    ]);
  }
}

// TODO: Implement the _ComicPageActions mixin
abstract mixin class _ComicPageActions {
  void update();

  ComicDetails get comic;

  ComicSource get comicSource => ComicSource.find(comic.sourceKey)!;

  History? history;

  bool isLiking = false;

  bool isLiked = false;

  void likeOrUnlike() async {
    if (isLiking) return;
    isLiking = true;
    update();
    var res = await comicSource.likeOrUnlikeComic!(comic.id, isLiked);
    if (res.error) {
      App.rootContext.showMessage(message: res.errorMessage!);
    } else {
      isLiked = !isLiked;
    }
    isLiking = false;
    update();
  }

  bool isAddToLocalFav = false;

  bool isFavorite = false;

  void openFavPanel() {
    var tags = <String>[];
    for (var e in comic.tags.entries) {
      tags.addAll(e.value.map((tag) => '${e.key}:$tag'));
    }

    showSideBar(
      App.rootContext,
      _FavoritePanel(
        cid: comic.id,
        type: comic.comicType,
        isFavorite: isFavorite,
        onFavorite: (b) {
          isFavorite = b;
          update();
        },
        favoriteItem: FavoriteItem(
          id: comic.id,
          name: comic.title,
          coverPath: comic.cover,
          author: comic.subTitle ?? comic.uploader ?? '',
          type: comic.comicType,
          tags: tags,
        ),
      ),
    );
  }

  void share() {
    Share.shareText(comic.title);
  }

  /// read the comic
  ///
  /// [ep] the episode number, start from 1
  ///
  /// [page] the page number, start from 1
  void read([int? ep, int? page]) {
    App.rootContext.to(
      () => Reader(
        type: comic.comicType,
        cid: comic.id,
        name: comic.title,
        chapters: comic.chapters,
        initialChapter: ep,
        initialPage: page,
        history: History.fromModel(model: comic, ep: 0, page: 0),
      ),
    );
  }

  void continueRead() {
    var ep = history?.ep ?? 1;
    var page = history?.page ?? 1;
    read(ep, page);
  }

  void download() async {
    if (LocalManager().isDownloading(comic.id, comic.comicType)) {
      App.rootContext.showMessage(message: "The comic is downloading".tl);
      return;
    }
    if (comic.chapters == null &&
        await LocalManager().isDownloaded(comic.id, comic.comicType, 0)) {
      App.rootContext.showMessage(message: "The comic is downloaded".tl);
      return;
    }
    if (comic.chapters == null) {
      LocalManager().addTask(ImagesDownloadTask(
        source: comicSource,
        comicId: comic.id,
        comic: comic,
      ));
    } else {
      List<int>? selected;
      var downloaded = <int>[];
      var localComic = LocalManager().find(comic.id, comic.comicType);
      if (localComic != null) {
        for (int i = 0; i < comic.chapters!.length; i++) {
          if (localComic.downloadedChapters
              .contains(comic.chapters!.keys.elementAt(i))) {
            downloaded.add(i);
          }
        }
      }
      await showSideBar(
        App.rootContext,
        _SelectDownloadChapter(
          comic.chapters!.values.toList(),
          (v) => selected = v,
          downloaded,
        ),
      );
      if (selected == null) return;
      LocalManager().addTask(ImagesDownloadTask(
        source: comicSource,
        comicId: comic.id,
        comic: comic,
        chapters: selected!.map((i) {
          return comic.chapters!.keys.elementAt(i);
        }).toList(),
      ));
    }
    App.rootContext.showMessage(message: "Download started".tl);
    update();
  }

  void onTapTag(String tag, String namespace) {}

  void showMoreActions() {}

  void showComments() {
    showSideBar(
      App.rootContext,
      CommentsPage(
        data: comic,
        source: comicSource,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.activeIcon,
    this.isActive,
    this.isLoading,
    this.iconColor,
  });

  final Widget icon;

  final Widget? activeIcon;

  final bool? isActive;

  final String text;

  final void Function() onPressed;

  final bool? isLoading;

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!(isLoading ?? false)) {
            onPressed();
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: IconTheme.merge(
          data: IconThemeData(size: 20, color: iconColor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading ?? false)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              else
                (isActive ?? false) ? (activeIcon ?? icon) : icon,
              const SizedBox(width: 8),
              Text(text),
            ],
          ).paddingHorizontal(16),
        ),
      ),
    );
  }
}

class _ComicChapters extends StatefulWidget {
  const _ComicChapters();

  @override
  State<_ComicChapters> createState() => _ComicChaptersState();
}

class _ComicChaptersState extends State<_ComicChapters> {
  late _ComicPageState state;

  bool reverse = false;

  bool showAll = false;

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_ComicPageState>()!;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final eps = state.comic.chapters!;

    int length = eps.length;

    if (!showAll) {
      length = math.min(length, 20);
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("Chapters".tl),
            trailing: Tooltip(
              message: "Order".tl,
              child: IconButton(
                icon: Icon(reverse
                    ? Icons.vertical_align_top
                    : Icons.vertical_align_bottom_outlined),
                onPressed: () {
                  setState(() {
                    reverse = !reverse;
                  });
                },
              ),
            ),
          ),
        ),
        SliverGrid(
          delegate:
              SliverChildBuilderDelegate(childCount: length, (context, i) {
            if (reverse) {
              i = eps.length - i - 1;
            }
            var key = eps.keys.elementAt(i);
            var value = eps[key]!;
            bool visited =
                (state.history?.readEpisode ?? const {}).contains(i + 1);
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: Material(
                  elevation: 5,
                  color: context.colorScheme.surface,
                  surfaceTintColor: context.colorScheme.surfaceTint,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  shadowColor: Colors.transparent,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Center(
                      child: Text(
                        value,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                visited ? context.colorScheme.outline : null),
                      ),
                    ),
                  ),
                ),
                onTap: () => state.read(i + 1),
              ),
            );
          }),
          gridDelegate: const SliverGridDelegateWithFixedHeight(
              maxCrossAxisExtent: 200, itemHeight: 48),
        ),
        if (eps.length > 20 && !showAll)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.center,
              child: FilledButton.tonal(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)))),
                ),
                onPressed: () {
                  setState(() {
                    showAll = true;
                  });
                },
                child: Text("${"Show all".tl} (${eps.length})"),
              ).paddingTop(12),
            ),
          ),
        const SliverToBoxAdapter(
          child: Divider(),
        ),
      ],
    );
  }
}

class _ComicThumbnails extends StatefulWidget {
  const _ComicThumbnails();

  @override
  State<_ComicThumbnails> createState() => _ComicThumbnailsState();
}

class _ComicThumbnailsState extends State<_ComicThumbnails> {
  late _ComicPageState state;

  late List<String> thumbnails;

  bool isInitialLoading = false;

  String? next;

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_ComicPageState>()!;
    thumbnails = List.from(state.comic.thumbnails ?? []);
    super.didChangeDependencies();
  }

  bool isLoading = false;

  void loadNext() async {
    if (state.comicSource.loadComicThumbnail == null || isLoading) return;
    if (!isInitialLoading && next == null) {
      return;
    }
    setState(() {
      isLoading = true;
    });
    var res = await state.comicSource.loadComicThumbnail!(state.comic.id, next);
    if (res.success) {
      thumbnails.addAll(res.data);
      next = res.subData;
      isInitialLoading = false;
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) {
      Future.microtask(loadNext);
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("Preview".tl),
          ),
        ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(childCount: thumbnails.length,
              (context, index) {
            if (index == thumbnails.length - 1) {
              loadNext();
            }
            return Padding(
              padding: context.width < changePoint
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => state.read(null, index + 1),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        width: double.infinity,
                        height: double.infinity,
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                          child: AnimatedImage(
                            image: CachedImageProvider(
                              thumbnails[index],
                              sourceKey: state.widget.sourceKey,
                            ),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text((index + 1).toString()),
                ],
              ),
            );
          }),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.65,
          ),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: ListLoadingIndicator(),
          ),
        const SliverToBoxAdapter(
          child: Divider(),
        ),
      ],
    );
  }
}

class _FavoritePanel extends StatefulWidget {
  const _FavoritePanel({
    required this.cid,
    required this.type,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteItem,
  });

  final String cid;

  final ComicType type;

  /// whether the comic is in the network favorite list
  ///
  /// if null, the comic source does not support favorite or support multiple favorite lists
  final bool? isFavorite;

  final void Function(bool) onFavorite;

  final FavoriteItem favoriteItem;

  @override
  State<_FavoritePanel> createState() => _FavoritePanelState();
}

class _FavoritePanelState extends State<_FavoritePanel> {
  late ComicSource comicSource;

  @override
  void initState() {
    comicSource = widget.type.comicSource!;
    localFolders = LocalFavoritesManager().folderNames;
    added = LocalFavoritesManager().find(widget.cid, widget.type);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var hasNetwork = comicSource.favoriteData != null && comicSource.isLogged;
    return Scaffold(
      appBar: Appbar(
        title: Text("Favorite".tl),
      ),
      body: DefaultTabController(
        length: comicSource.favoriteData == null ? 1 : 2,
        child: Column(
          children: [
            TabBar(tabs: [
              Tab(text: "Local".tl),
              if (hasNetwork) Tab(text: "Network".tl),
            ]),
            Expanded(
              child: TabBarView(
                children: [
                  buildLocal(),
                  if (hasNetwork) buildNetwork(),
                ],
              ),
            ),
          ],
        ),
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
              } else {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager().addComic(folder, widget.favoriteItem);
                }
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
    );
  }
}

class _NetworkFavorites extends StatefulWidget {
  const _NetworkFavorites(
      {required this.cid, required this.comicSource, required this.isFavorite});

  final String cid;

  final ComicSource comicSource;

  final bool? isFavorite;

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
                  .addOrDelFavorite!(widget.cid, '', !isFavorite);
              if (res.success) {
                context.pop();
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
            child: FilledButton(
              onPressed: () {
                if (selected == null) {
                  return;
                }
                widget.comicSource.favoriteData!.addOrDelFavorite!(
                    widget.cid, selected!, !addedFolders.contains(selected!));
                context.pop();
              },
              child: addedFolders.contains(selected!)
                  ? Text("Remove".tl)
                  : Text("Add".tl),
            ).paddingVertical(8),
          ),
        ],
      );
    }
  }
}

class _SelectDownloadChapter extends StatefulWidget {
  const _SelectDownloadChapter(this.eps, this.finishSelect, this.downloadedEps);

  final List<String> eps;
  final void Function(List<int>) finishSelect;
  final List<int> downloadedEps;

  @override
  State<_SelectDownloadChapter> createState() => _SelectDownloadChapterState();
}

class _SelectDownloadChapterState extends State<_SelectDownloadChapter> {
  List<int> selected = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text("Download".tl), backgroundColor: context.colorScheme.surfaceContainerLow,),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.eps.length,
              itemBuilder: (context, i) {
                return CheckboxListTile(
                    title: Text(widget.eps[i]),
                    value: selected.contains(i) ||
                        widget.downloadedEps.contains(i),
                    onChanged: widget.downloadedEps.contains(i)
                        ? null
                        : (v) {
                      setState(() {
                        if (selected.contains(i)) {
                          selected.remove(i);
                        } else {
                          selected.add(i);
                        }
                      });
                    });
              },
            ),
          ),
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      var res = <int>[];
                      for (int i = 0; i < widget.eps.length; i++) {
                        if (!widget.downloadedEps.contains(i)) {
                          res.add(i);
                        }
                      }
                      widget.finishSelect(res);
                      context.pop();
                    },
                    child: Text("Download All".tl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.finishSelect(selected);
                      context.pop();
                    },
                    child: Text("Download Selected".tl),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }
}
