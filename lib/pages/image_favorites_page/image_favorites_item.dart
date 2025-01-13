part of 'image_favorites_page.dart';

class _ImageFavoritesItem extends StatefulWidget {
  const _ImageFavoritesItem({
    required this.imageFavoritesComic,
    required this.selectedImageFavorites,
    required this.addSelected,
    required this.multiSelectMode,
    required this.finalImageFavoritesComicList,
    this.imageFavoritesCompute,
  });

  final ImageFavoritesComic imageFavoritesComic;
  final Function(ImageFavorite) addSelected;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final List<ImageFavoritesComic> finalImageFavoritesComicList;
  final bool multiSelectMode;
  final ImageFavoritesCompute? imageFavoritesCompute;

  @override
  State<_ImageFavoritesItem> createState() => _ImageFavoritesItemState();
}

class _ImageFavoritesItemState extends State<_ImageFavoritesItem> {
  void goComicInfo(ImageFavoritesComic comic) {
    App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
          id: comic.id,
          sourceKey: comic.sourceKey,
        ));
  }

  void goReaderPage(ImageFavoritesComic comic, int ep, int page) {
    App.mainNavigatorKey?.currentContext?.to(
      () => ReaderWithLoading(
        id: comic.id,
        sourceKey: comic.sourceKey,
        initialEp: ep,
        initialPage: page,
      ),
    );
  }

  void goPhotoView(ImageFavorite imageFavorite) {
    // 双击浏览大图
    App.mainNavigatorKey?.currentContext?.to(
      () => ImageFavoritesPhotoView(
        imageFavoritesComic: widget.imageFavoritesComic,
        imageFavoritePro: imageFavorite,
        finalImageFavoritesComicList: widget.finalImageFavoritesComicList,
        goComicInfo: goComicInfo,
        goReaderPage: goReaderPage,
      ),
    );
  }

  void copyTitle() {
    Clipboard.setData(ClipboardData(text: widget.imageFavoritesComic.title));
    App.rootContext.showMessage(message: 'Copy the title successfully'.tl);
  }

  void onLongPress(BuildContext context) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    showMenuX(
      App.rootContext,
      location,
      [
        MenuEntry(
          icon: Icons.chrome_reader_mode_outlined,
          text: 'Details'.tl,
          onClick: () {
            goComicInfo(widget.imageFavoritesComic);
          },
        ),
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy Title'.tl,
          onClick: () {
            copyTitle();
          },
        ),
        MenuEntry(
          icon: Icons.select_all,
          text: 'Select All'.tl,
          onClick: () {
            for (var ele in widget.imageFavoritesComic.sortedImageFavorites) {
              widget.addSelected(ele);
            }
          },
        ),
        MenuEntry(
          icon: Icons.read_more,
          text: 'Photo View'.tl,
          onClick: () {
            goPhotoView(widget.imageFavoritesComic.sortedImageFavorites.first);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var enableTranslate = App.locale.languageCode == 'zh';
    String time =
        DateFormat('yyyy-MM-dd HH:mm').format(widget.imageFavoritesComic.time);
    List<String> hotTags = [];
    for (var textWithCount
        in widget.imageFavoritesCompute?.tags ?? <TextWithCount>[]) {
      if (widget.imageFavoritesComic.tags.contains(textWithCount.text)) {
        var enableTranslate = App.locale.languageCode == 'zh';
        var text = enableTranslate
            ? textWithCount.text.translateTagsToCN
            : textWithCount.text;
        if (text.contains(':')) {
          text = text.split(':').last;
        }
        hotTags.add(text);
      }
      if (hotTags.length == 5) {
        break;
      }
    }
    var imageFavorites = widget.imageFavoritesComic.sortedImageFavorites;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
        onLongPress: () => onLongPress(context),
        onDoubleTap: () {
          copyTitle();
        },
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele in widget.imageFavoritesComic.sortedImageFavorites) {
              widget.addSelected(ele);
            }
          } else {
            // 单击跳转漫画详情
            goComicInfo(widget.imageFavoritesComic);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.imageFavoritesComic.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        "${imageFavorites.length}/${widget.imageFavoritesComic.maxPageFromEp}",
                        style: ts.s12),
                  ),
                ],
              ),
            ).paddingHorizontal(16),
            SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  var imageFavorite = imageFavorites[index];
                  bool isSelected =
                      widget.selectedImageFavorites[imageFavorite] ?? false;
                  int curPage = imageFavorite.page;
                  String pageText = curPage == firstPage
                      ? '@a Cover'.tlParams({"a": imageFavorite.epName})
                      : curPage.toString();
                  return InkWell(
                    onDoubleTap: () {
                      goPhotoView(imageFavorite);
                    },
                    onTap: () {
                      // 单击去阅读页面, 跳转到当前点击的page
                      if (widget.multiSelectMode) {
                        widget.addSelected(imageFavorite);
                      } else {
                        goReaderPage(widget.imageFavoritesComic,
                            imageFavorite.ep, curPage);
                      }
                    },
                    onLongPress: () {
                      widget.addSelected(imageFavorite);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 98,
                        height: 128,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Container(
                                height: 128,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AnimatedImage(
                                  image: ImageFavoritesProvider(imageFavorite),
                                  width: 96,
                                  height: 128,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                )),
                            Text(
                              pageText,
                              style: ts.s10,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          ],
                        )),
                  ).paddingHorizontal(4);
                },
                itemCount: imageFavorites.length,
              ),
            ).paddingHorizontal(8),
            Row(
              children: [
                Text(
                  "${"Collection time".tl}:$time | ${widget.imageFavoritesComic.sourceKey}",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12.0,
                  ),
                ).paddingRight(8),
                if (hotTags.isNotEmpty)
                  Expanded(
                    child: Text(
                      hotTags
                          .map((e) => enableTranslate ? e.translateTagsToCN : e)
                          .join(" "),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.0,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
              ],
            ).paddingHorizontal(8).paddingBottom(8),
          ],
        ),
      ),
    );
  }
}
