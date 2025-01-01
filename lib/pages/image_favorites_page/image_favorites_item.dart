part of 'image_favorites_page.dart';

class ImageFavoritesItem extends StatefulWidget {
  const ImageFavoritesItem(
      {super.key,
      required this.imageFavoritesComic,
      required this.selectedImageFavorites,
      required this.addSelected,
      required this.multiSelectMode,
      required this.finalImageFavoritesComicList});
  final ImageFavoritesComic imageFavoritesComic;
  final Function(ImageFavoritePro) addSelected;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final List<ImageFavoritesComic> finalImageFavoritesComicList;
  final bool multiSelectMode;
  @override
  State<ImageFavoritesItem> createState() => ImageFavoritesItemState();
}

class ImageFavoritesItemState extends State<ImageFavoritesItem> {
  bool isImageKeyLoading = false;
  // 刷新 imageKey 失败的场景再刷新一次, 再次失败了就不重试了
  bool hasRefreshImageKeyOnErr = false;
  // 如果 imageKey 失效了, 或者刚从pica导入(没有imageKey)
  void refreshImageKey(ImageFavoritesEp imageFavoritesEp) async {
    if (isImageKeyLoading || hasRefreshImageKeyOnErr) return;
    isImageKeyLoading = true;
    ComicSource? comicSource =
        ComicSource.find(widget.imageFavoritesComic.sourceKey);
    var resArr = await Future.wait([
      comicSource!.loadComicPages!(
        widget.imageFavoritesComic.id,
        imageFavoritesEp.eid,
      ),
      comicSource.loadComicInfo!(
        widget.imageFavoritesComic.id,
      )
    ]);
    Res<List<String>> comicPagesRes = resArr[0] as Res<List<String>>;
    Res<ComicDetails> comicInfoRes = resArr[1] as Res<ComicDetails>;
    if (!comicPagesRes.error && !comicInfoRes.error) {
      List<String> images = comicPagesRes.data;
      ImageFavoritesSomething something =
          ImageFavoritesComic.getSomethingFromComicDetails(
              comicInfoRes.data, imageFavoritesEp.ep);
      // 刷新一下值, 保存最新的
      widget.imageFavoritesComic.author = something.author;
      widget.imageFavoritesComic.maxPage = images.length;
      widget.imageFavoritesComic.subTitle = something.subTitle;
      widget.imageFavoritesComic.tags = something.tags;
      widget.imageFavoritesComic.translatedTags = something.translatedTags;
      imageFavoritesEp.maxPage = images.length;
      imageFavoritesEp.epName = something.epName;
      // 塞一个封面进去
      if (!imageFavoritesEp.isHasFirstPage) {
        ImageFavoritePro copy =
            ImageFavoritePro.copy(imageFavoritesEp.imageFavorites[0]);
        copy.page = ImageFavoritesEp.firstPage;
        copy.imageKey = images[0];
        copy.isAutoFavorite = true;
        imageFavoritesEp.imageFavorites.insert(0, copy);
      }
      for (var ele in imageFavoritesEp.imageFavorites) {
        ele.imageKey = images[ele.page - 1];
      }
      ImageFavoriteManager.addOrUpdateOrDelete(widget.imageFavoritesComic);
      if (mounted) {
        setState(() {});
      }
    }
    isImageKeyLoading = false;
  }

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

  @override
  Widget build(BuildContext context) {
    int count = widget.imageFavoritesComic.sortedImageFavoritePros.length;
    if (!widget.imageFavoritesComic.isAllHasImageKey ||
        !widget.imageFavoritesComic.isAllHasFirstPage) {
      for (var e in widget.imageFavoritesComic.imageFavoritesEp) {
        refreshImageKey(e);
      }
    }
    String time = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(widget.imageFavoritesComic.time);
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
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele
                in widget.imageFavoritesComic.sortedImageFavoritePros) {
              widget.addSelected(ele);
            }
          } else {
            // 单击跳转漫画详情
            goComicInfo(widget.imageFavoritesComic);
          }
        },
        onLongPress: () {
          for (var ele in widget.imageFavoritesComic.sortedImageFavoritePros) {
            widget.addSelected(ele);
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
                        "$count/${widget.imageFavoritesComic.maxPageFromEp}",
                        style: ts.s12),
                  ),
                ],
              ),
            ).paddingHorizontal(16),
            SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                itemBuilder: (context, index) {
                  ImageFavoritePro curImageFavorite =
                      widget.imageFavoritesComic.sortedImageFavoritePros[index];
                  ImageFavoritesEp curImageFavoritesEp = widget
                      .imageFavoritesComic.imageFavoritesEp
                      .firstWhere((e) {
                    return e.eid == curImageFavorite.eid;
                  });
                  ImageProvider image =
                      ImageFavoritesProvider(curImageFavorite);
                  bool isSelected =
                      widget.selectedImageFavorites[curImageFavorite] ?? false;
                  Widget imageWidget = AnimatedImage(
                    image: image,
                    width: 96,
                    height: 128,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    onError: (Object error, StackTrace? stackTrace) {
                      refreshImageKey(curImageFavoritesEp);
                      hasRefreshImageKeyOnErr = true;
                    },
                  );
                  int curPage = curImageFavorite.page;
                  String pageText = curPage == ImageFavoritesEp.firstPage
                      ? '@a cover'.tlParams({"a": curImageFavorite.epName})
                      : curPage.toString();
                  return InkWell(
                    onDoubleTap: () {
                      // 双击浏览大图
                      App.mainNavigatorKey?.currentContext?.to(
                        () => ImageFavoritesPhotoView(
                          imageFavoritesComic: widget.imageFavoritesComic,
                          imageFavoritePro: curImageFavorite,
                          finalImageFavoritesComicList:
                              widget.finalImageFavoritesComicList,
                          goComicInfo: goComicInfo,
                          goReaderPage: goReaderPage,
                        ),
                      );
                    },
                    onTap: () {
                      // 单击去阅读页面, 跳转到当前点击的page
                      if (widget.multiSelectMode) {
                        widget.addSelected(curImageFavorite);
                      } else {
                        goReaderPage(widget.imageFavoritesComic,
                            curImageFavorite.ep, curPage);
                      }
                    },
                    onLongPress: () {
                      widget.addSelected(curImageFavorite);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 98,
                        height: 128,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondaryContainer
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
                                child: imageWidget),
                            Text(
                              pageText,
                              style: ts.s10,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          ],
                        )),
                  );
                },
              ),
            ).paddingHorizontal(8),
            Row(
              children: [
                Text(
                  "最早收藏时间: $time | ${widget.imageFavoritesComic.sourceKey}",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12.0,
                  ),
                )
              ],
            ).paddingHorizontal(16).paddingBottom(8),
          ],
        ),
      ),
    );
  }
}
