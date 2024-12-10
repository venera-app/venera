import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/network/download.dart';
import 'package:venera/pages/category_comics_page.dart';
import 'package:venera/pages/favorites/favorites_page.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/pages/search_result_page.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/tags_translation.dart';
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

  void updateHistory() async {
    var newHistory = await HistoryManager()
        .find(widget.id, ComicType(widget.sourceKey.hashCode));
    if (newHistory?.ep != history?.ep || newHistory?.page != history?.page) {
      history = newHistory;
      update();
    }
  }

  @override
  Widget buildLoading() {
    return Column(
      children: [
        const Appbar(title: Text("")),
        Expanded(
          child: super.buildLoading(),
        ),
      ],
    );
  }

  @override
  void initState() {
    scrollController.addListener(onScroll);
    HistoryManager().addListener(updateHistory);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    HistoryManager().removeListener(updateHistory);
    super.dispose();
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

  var isFirst = true;

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
        buildComments(),
        buildThumbnails(),
        buildRecommend(),
        SliverPadding(padding: EdgeInsets.only(bottom: context.padding.bottom)),
      ],
    );
  }

  @override
  Future<Res<ComicDetails>> loadData() async {
    if (widget.sourceKey == 'local') {
      var localComic = LocalManager().find(widget.id, ComicType.local);
      if (localComic == null) {
        return const Res.error('Local comic not found');
      }
      var history = await HistoryManager().find(widget.id, ComicType.local);
      if (isFirst) {
        Future.microtask(() {
          App.rootContext.to(() {
            return Reader(
              type: ComicType.local,
              cid: widget.id,
              name: localComic.title,
              chapters: localComic.chapters,
              history: history ??
                  History.fromModel(
                    model: localComic,
                    ep: 0,
                    page: 0,
                  ),
            );
          });
          App.mainNavigatorKey!.currentContext!.pop();
        });
        isFirst = false;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      return const Res.error('Local comic');
    }
    var comicSource = ComicSource.find(widget.sourceKey);
    if (comicSource == null) {
      return const Res.error('Comic source not found');
    }
    isAddToLocalFav = LocalFavoritesManager().isExist(
      widget.id,
      ComicType(widget.sourceKey.hashCode),
    );
    history = await HistoryManager()
        .find(widget.id, ComicType(widget.sourceKey.hashCode));
    return comicSource.loadComicInfo!(widget.id);
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
            color: context.colorScheme.primaryContainer,
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
              SelectableText(comic.title, style: ts.s18),
              if (comic.subTitle != null)
                SelectableText(comic.subTitle!, style: ts.s14)
                    .paddingVertical(4),
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
    bool hasHistory = history != null && (history!.ep > 1 || history!.page > 1);
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              if (hasHistory && !isMobile)
                _ActionButton(
                  icon: const Icon(Icons.menu_book),
                  text: 'Continue'.tl,
                  onPressed: continueRead,
                  iconColor: context.useTextColor(Colors.yellow),
                ),
              if (!isMobile || hasHistory)
                _ActionButton(
                  icon: const Icon(Icons.play_circle_outline),
                  text: 'Start'.tl,
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
                  text: ((data!.likesCount != null)
                          ? (data!.likesCount! + (isLiked ? 1 : 0))
                          : (isLiked ? 'Liked'.tl : 'Like'.tl))
                      .toString(),
                  isLoading: isLiking,
                  onPressed: likeOrUnlike,
                  iconColor: context.useTextColor(Colors.red),
                ),
              _ActionButton(
                icon: const Icon(Icons.bookmark_outline_outlined),
                activeIcon: const Icon(Icons.bookmark),
                isActive: isFavorite || isAddToLocalFav,
                text: 'Favorite'.tl,
                onPressed: openFavPanel,
                onLongPressed: quickFavorite,
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
                  child: hasHistory
                      ? FilledButton(
                          onPressed: continueRead, child: Text("Continue".tl))
                      : FilledButton(onPressed: read, child: Text("Read".tl)),
                )
              ],
            ).paddingHorizontal(16).paddingVertical(8),
          const Divider(),
        ],
      ).paddingTop(16),
    );
  }

  Widget buildDescription() {
    if (comic.description == null || comic.description!.trim().isEmpty) {
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
        color = context.colorScheme.surfaceContainerLow;
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
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: text));
              context.showMessage(message: "Copied".tl);
            },
            onSecondaryTapDown: (details) {
              showMenuX(context, details.globalPosition, [
                MenuEntry(
                  icon: Icons.remove_red_eye,
                  text: "View".tl,
                  onClick: onTap,
                ),
                MenuEntry(
                  icon: Icons.copy,
                  text: "Copy".tl,
                  onClick: () {
                    Clipboard.setData(ClipboardData(text: text));
                    context.showMessage(message: "Copied".tl);
                  },
                ),
              ]);
            },
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

    String formatTime(String time) {
      if (int.tryParse(time) != null) {
        var t = int.tryParse(time);
        if (t! > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(t)
              .toString()
              .substring(0, 19);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(t * 1000)
              .toString()
              .substring(0, 19);
        }
      }
      if (time.contains('T') || time.contains('Z')) {
        var t = DateTime.parse(time);
        return t.toString().substring(0, 19);
      }
      return time;
    }

    Widget buildWrap({required List<Widget> children}) {
      return Wrap(
        runSpacing: 8,
        spacing: 8,
        children: children,
      ).paddingHorizontal(16).paddingBottom(8);
    }

    bool enableTranslation =
        App.locale.languageCode == 'zh' && comicSource.enableTagsTranslate;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text("Information".tl),
          ),
          if (comic.stars != null)
            Row(
              children: [
                StarRating(
                  value: comic.stars!,
                  size: 24,
                  onTap: starRating,
                ),
                const SizedBox(width: 8),
                Text(comic.stars!.toStringAsFixed(2)),
              ],
            ).paddingLeft(16).paddingVertical(8),
          for (var e in comic.tags.entries)
            buildWrap(
              children: [
                if (e.value.isNotEmpty)
                  buildTag(text: e.key.ts(comicSource.key), isTitle: true),
                for (var tag in e.value)
                  buildTag(
                    text: enableTranslation
                        ? TagsTranslation.translationTagWithNamespace(
                            tag,
                            e.key.toLowerCase(),
                          )
                        : tag,
                    onTap: () => onTapTag(tag, e.key),
                  ),
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
                buildTag(text: formatTime(comic.uploadTime!)),
              ],
            ),
          if (comic.updateTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Update Time'.tl, isTitle: true),
                buildTag(text: formatTime(comic.updateTime!)),
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
    if (comic.recommend == null || comic.recommend!.isEmpty) {
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

  Widget buildComments() {
    if (comic.comments == null || comic.comments!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return _CommentsPart(
      comments: comic.comments!,
      showMore: showComments,
    );
  }
}

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

  FavoriteItem _toFavoriteItem() {
    var tags = <String>[];
    for (var e in comic.tags.entries) {
      tags.addAll(e.value.map((tag) => '${e.key}:$tag'));
    }
    return FavoriteItem(
      id: comic.id,
      name: comic.title,
      coverPath: comic.cover,
      author: comic.subTitle ?? comic.uploader ?? '',
      type: comic.comicType,
      tags: tags,
    );
  }

  void openFavPanel() {
    showSideBar(
      App.rootContext,
      _FavoritePanel(
        cid: comic.id,
        type: comic.comicType,
        isFavorite: isFavorite,
        onFavorite: (local, network) {
          isFavorite = network ?? isFavorite;
          isAddToLocalFav = local ?? isAddToLocalFav;
          update();
        },
        favoriteItem: _toFavoriteItem(),
      ),
    );
  }

  void quickFavorite() {
    var folder = appdata.settings['quickFavorite'];
    if (folder is! String) {
      return;
    }
    LocalFavoritesManager().addComic(
      folder,
      _toFavoriteItem(),
    );
    isAddToLocalFav = true;
    update();
    App.rootContext.showMessage(message: "Added".tl);
  }

  void share() {
    var text = comic.title;
    if (comic.url != null) {
      text += '\n${comic.url}';
    }
    Share.shareText(text);
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

    if (comicSource.archiveDownloader != null) {
      bool useNormalDownload = false;
      List<ArchiveInfo>? archives;
      int selected = -1;
      bool isLoading = false;
      bool isGettingLink = false;
      await showDialog(
        context: App.rootContext,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return ContentDialog(
                title: "Download".tl,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int>(
                      value: -1,
                      groupValue: selected,
                      title: Text("Normal".tl),
                      onChanged: (v) {
                        setState(() {
                          selected = v!;
                        });
                      },
                    ),
                    ExpansionTile(
                      title: Text("Archive".tl),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      collapsedShape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      onExpansionChanged: (b) {
                        if (!isLoading && b && archives == null) {
                          isLoading = true;
                          comicSource.archiveDownloader!
                              .getArchives(comic.id)
                              .then((value) {
                            if (value.success) {
                              archives = value.data;
                            } else {
                              App.rootContext
                                  .showMessage(message: value.errorMessage!);
                            }
                            setState(() {
                              isLoading = false;
                            });
                          });
                        }
                      },
                      children: [
                        if (archives == null)
                          const ListLoadingIndicator().toCenter()
                        else
                          for (int i = 0; i < archives!.length; i++)
                            RadioListTile<int>(
                              value: i,
                              groupValue: selected,
                              onChanged: (v) {
                                setState(() {
                                  selected = v!;
                                });
                              },
                              title: Text(archives![i].title),
                              subtitle: Text(archives![i].description),
                            )
                      ],
                    )
                  ],
                ),
                actions: [
                  Button.filled(
                    isLoading: isGettingLink,
                    onPressed: () async {
                      if (selected == -1) {
                        useNormalDownload = true;
                        context.pop();
                        return;
                      }
                      setState(() {
                        isGettingLink = true;
                      });
                      var res =
                          await comicSource.archiveDownloader!.getDownloadUrl(
                        comic.id,
                        archives![selected].id,
                      );
                      if (res.error) {
                        App.rootContext.showMessage(message: res.errorMessage!);
                        setState(() {
                          isGettingLink = false;
                        });
                      } else if (context.mounted) {
                        LocalManager()
                            .addTask(ArchiveDownloadTask(res.data, comic));
                        App.rootContext
                            .showMessage(message: "Download started".tl);
                        context.pop();
                      }
                    },
                    child: Text("Confirm".tl),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!useNormalDownload) {
        return;
      }
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

  void onTapTag(String tag, String namespace) {
    var config = comicSource.handleClickTagEvent?.call(namespace, tag) ??
        {
          'action': 'search',
          'keyword': tag,
        };
    var context = App.mainNavigatorKey!.currentContext!;
    if (config['action'] == 'search') {
      context.to(() => SearchResultPage(
            text: config['keyword'] ?? '',
            sourceKey: comicSource.key,
            options: const [],
          ));
    } else if (config['action'] == 'category') {
      context.to(
        () => CategoryComicsPage(
          category: config['keyword'] ?? '',
          categoryKey: comicSource.categoryData!.key,
          param: config['param'],
        ),
      );
    }
  }

  void showMoreActions() {
    var context = App.rootContext;
    showMenuX(
        context,
        Offset(
          context.width - 16,
          context.padding.top,
        ),
        [
          MenuEntry(
            icon: Icons.copy,
            text: "Copy Title".tl,
            onClick: () {
              Clipboard.setData(ClipboardData(text: comic.title));
              context.showMessage(message: "Copied".tl);
            },
          ),
          MenuEntry(
            icon: Icons.copy_rounded,
            text: "Copy ID".tl,
            onClick: () {
              Clipboard.setData(ClipboardData(text: comic.id));
              context.showMessage(message: "Copied".tl);
            },
          ),
          if (comic.url != null)
            MenuEntry(
              icon: Icons.link,
              text: "Copy URL".tl,
              onClick: () {
                Clipboard.setData(ClipboardData(text: comic.url!));
                context.showMessage(message: "Copied".tl);
              },
            ),
          if (comic.url != null)
            MenuEntry(
              icon: Icons.open_in_browser,
              text: "Open in Browser".tl,
              onClick: () {
                launchUrlString(comic.url!);
              },
            ),
        ]);
  }

  void showComments() {
    showSideBar(
      App.rootContext,
      CommentsPage(
        data: comic,
        source: comicSource,
      ),
    );
  }

  void starRating() {
    if (!comicSource.isLogged) {
      return;
    }
    var rating = 0.0;
    var isLoading = false;
    showDialog(
      context: App.rootContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => SimpleDialog(
          title: const Text("Rating"),
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 100,
              child: Center(
                child: SizedBox(
                  width: 210,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      RatingWidget(
                        padding: 2,
                        onRatingUpdate: (value) => rating = value,
                        value: 1,
                        selectable: true,
                        size: 40,
                      ),
                      const Spacer(),
                      Button.filled(
                        isLoading: isLoading,
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          comicSource.starRatingFunc!(comic.id, rating.round())
                              .then((value) {
                            if (value.success) {
                              App.rootContext
                                  .showMessage(message: "Success".tl);
                              Navigator.of(dialogContext).pop();
                            } else {
                              App.rootContext
                                  .showMessage(message: value.errorMessage!);
                              setState(() {
                                isLoading = false;
                              });
                            }
                          });
                        },
                        child: Text("Submit".tl),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.onLongPressed,
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

  final void Function()? onLongPressed;

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
        onLongPress: onLongPressed,
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
              child: Material(
                color: context.colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: InkWell(
                  onTap: () => state.read(i + 1),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                          color: visited ? context.colorScheme.outline : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          gridDelegate: const SliverGridDelegateWithFixedHeight(
              maxCrossAxisExtent: 200, itemHeight: 48),
        ).sliverPadding(const EdgeInsets.symmetric(horizontal: 8)),
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

  bool isInitialLoading = true;

  String? next;

  String? error;

  bool isLoading = false;

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_ComicPageState>()!;
    loadNext();
    thumbnails = List.from(state.comic.thumbnails ?? []);
    super.didChangeDependencies();
  }

  void loadNext() async {
    if (state.comicSource.loadComicThumbnail == null) return;
    if (!isInitialLoading && next == null) {
      return;
    }
    if (isLoading) return;
    Future.microtask(() {
      setState(() {
        isLoading = true;
      });
    });
    var res = await state.comicSource.loadComicThumbnail!(state.comic.id, next);
    if (res.success) {
      thumbnails.addAll(res.data);
      next = res.subData;
      isInitialLoading = false;
    } else {
      error = res.errorMessage;
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("Preview".tl),
          ),
        ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            childCount: thumbnails.length,
            (context, index) {
              if (index == thumbnails.length - 1 && error == null) {
                loadNext();
              }
              var url = thumbnails[index];
              ImagePart? part;
              if (url.contains('@')) {
                var params = url.split('@')[1].split('&');
                url = url.split('@')[0];
                double? x1, y1, x2, y2;
                try {
                  for (var p in params) {
                    if (p.startsWith('x')) {
                      var r = p.split('=')[1];
                      x1 = double.parse(r.split('-')[0]);
                      x2 = double.parse(r.split('-')[1]);
                    }
                    if (p.startsWith('y')) {
                      var r = p.split('=')[1];
                      y1 = double.parse(r.split('-')[0]);
                      y2 = double.parse(r.split('-')[1]);
                    }
                  }
                } finally {}
                part = ImagePart(x1: x1, y1: y1, x2: x2, y2: y2);
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
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
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
                                url,
                                sourceKey: state.widget.sourceKey,
                              ),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              part: part,
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
            },
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.65,
          ),
        ),
        if (error != null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Text(error!),
                Button.outlined(
                  onPressed: loadNext,
                  child: Text("Retry".tl),
                )
              ],
            ),
          )
        else if (isLoading)
          const SliverListLoadingIndicator(),
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

  final void Function(bool?, bool?) onFavorite;

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
        length: hasNetwork ? 2 : 1,
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
                widget.onFavorite(false, null);
              } else {
                for (var folder in selectedLocalFolders) {
                  LocalFavoritesManager().addComic(folder, widget.favoriteItem);
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
      appBar: Appbar(
        title: Text("Download".tl),
        backgroundColor: context.colorScheme.surfaceContainerLow,
      ),
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
                    onPressed: selected.isEmpty
                        ? null
                        : () {
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
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _CommentsPart extends StatefulWidget {
  const _CommentsPart({
    required this.comments,
    required this.showMore,
  });

  final List<Comment> comments;

  final void Function() showMore;

  @override
  State<_CommentsPart> createState() => _CommentsPartState();
}

class _CommentsPartState extends State<_CommentsPart> {
  final scrollController = ScrollController();

  late List<Comment> comments;

  @override
  void initState() {
    comments = widget.comments;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("Comments".tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.position.pixels - 340,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.position.pixels + 340,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 184,
                child: MediaQuery.removePadding(
                  removeTop: true,
                  context: context,
                  child: ListView.builder(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      return _CommentWidget(comment: comments[index]);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: const Icon(Icons.comment),
                text: "View more".tl,
                onPressed: widget.showMore,
                iconColor: context.useTextColor(Colors.green),
              ).fixHeight(48).paddingRight(8).toAlign(Alignment.centerRight),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: Divider(),
        ),
      ],
    );
  }
}

class _CommentWidget extends StatelessWidget {
  const _CommentWidget({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: 324,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (comment.avatar != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: context.colorScheme.surfaceContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image(
                    image: CachedImageProvider(comment.avatar!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ).paddingRight(8),
              Text(comment.userName, style: ts.bold),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RichCommentContent(text: comment.content).fixWidth(324),
          ),
          const SizedBox(height: 4),
          if (comment.time != null)
            Text(comment.time!, style: ts.s12).toAlign(Alignment.centerLeft),
        ],
      ),
    );
  }
}
