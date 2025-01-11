part of 'image_favorites_page.dart';

class ImageFavoritesPhotoView extends StatefulWidget {
  const ImageFavoritesPhotoView(
      {super.key,
      required this.imageFavoritesComic,
      required this.imageFavoritePro,
      required this.finalImageFavoritesComicList,
      required this.goComicInfo,
      required this.goReaderPage});

  final ImageFavoritesComic imageFavoritesComic;
  final ImageFavorite imageFavoritePro;
  final List<ImageFavoritesComic> finalImageFavoritesComicList;
  final Function(ImageFavoritesComic) goComicInfo;
  final Function(ImageFavoritesComic, int, int) goReaderPage;

  @override
  State<ImageFavoritesPhotoView> createState() =>
      ImageFavoritesPhotoViewState();
}

class ImageFavoritesPhotoViewState extends State<ImageFavoritesPhotoView> {
  late PageController controller;
  Map<ImageFavorite, bool> cancelImageFavorites = {};

  // 图片当前的 index
  late int curIndex;
  late int curImageFavoritesComicIndex;

  @override
  void initState() {
    curIndex =
        widget.imageFavoritesComic.sortedImageFavorites.indexWhere((ele) {
      return ele.page == widget.imageFavoritePro.page &&
          ele.ep == widget.imageFavoritePro.ep;
    });
    controller = PageController(initialPage: curIndex);
    curImageFavoritesComicIndex =
        widget.finalImageFavoritesComicList.indexWhere((ele) {
      return ele.id == widget.imageFavoritesComic.id;
    });
    super.initState();
  }

  void onPop() {
    List<ImageFavorite> tempList = cancelImageFavorites.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();
    ImageFavoriteManager().deleteImageFavorite(tempList);
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final ImageFavorite curImageFavorite = widget
        .finalImageFavoritesComicList[curImageFavoritesComicIndex]
        .sortedImageFavorites[index];
    return PhotoViewGalleryPageOptions(
        // 图片加载器 支持本地、网络
        imageProvider: ImageFavoritesProvider(curImageFavorite),
        // 初始化大小 全部展示
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.covered * 10.0,
        onTapUp: (context, details, controllerValue) {
          Navigator.pop(context);
          onPop();
        });
  }

  Future<Uint8List?> _getCurrentImageData(ImageFavorite temp) async {
    return (await CacheManager()
            .findCache(ImageFavoritesProvider.getImageKey(temp)))!
        .readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    ImageFavoritesComic curComic =
        widget.finalImageFavoritesComicList[curImageFavoritesComicIndex];
    ImageFavorite curImageFavorite = curComic.sortedImageFavorites[curIndex];
    int curPage = curImageFavorite.page;
    String pageText =
        curPage == firstPage ? 'Cover'.tl : "Page @a".tlParams({'a': curPage});
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          onPop();
        }
      },
      child: Stack(children: [
        PhotoViewGallery.builder(
          backgroundDecoration: BoxDecoration(
            color: context.colorScheme.surface,
          ),
          builder: _buildItem,
          itemCount: curComic.sortedImageFavorites.length,
          loadingBuilder: (context, event) => Center(
            child: SizedBox(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(
                backgroundColor: context.colorScheme.surfaceContainerHigh,
                value: event == null || event.expectedTotalBytes == null
                    ? null
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              ),
            ),
          ),
          enableRotation: true,
          customSize: MediaQuery.of(context).size,
          //定义图片默认缩放基础的大小,默认全屏 MediaQuery.of(context).size
          pageController: controller,
          onPageChanged: (index) {
            setState(() {
              curIndex = index;
            });
          },
        ),
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () {
                widget.goComicInfo(curComic);
              },
              onDoubleTap: () {
                Clipboard.setData(ClipboardData(text: curComic.title));
                showToast(
                    message: "Copy the title successfully".tl,
                    context: context);
              },
              child: Text(
                curComic.title,
                style: ts.s18,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).paddingTop(20),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(children: [
              Text(
                  "${curImageFavorite.epName} : $pageText : ${curIndex + 1}/${curComic.sortedImageFavorites.length}",
                  style: ts.s12),
              Spacer(),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: Icon(Icons.arrow_circle_left),
                  onPressed: () {
                    if (curImageFavoritesComicIndex == 0) {
                      curImageFavoritesComicIndex =
                          widget.finalImageFavoritesComicList.length - 1;
                    } else {
                      curImageFavoritesComicIndex -= 1;
                    }
                    curIndex = 0;
                    controller.jumpToPage(0);
                    setState(() {});
                  },
                ),
              ),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: cancelImageFavorites[curImageFavorite] == true
                      ? Icon(Icons.favorite_border)
                      : Icon(Icons.favorite),
                  onPressed: () {
                    if (cancelImageFavorites[curImageFavorite] == true) {
                      cancelImageFavorites[curImageFavorite] = false;
                    } else {
                      cancelImageFavorites[curImageFavorite] = true;
                    }

                    setState(() {});
                  },
                ),
              ),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () {
                    widget.goReaderPage(curComic, curImageFavorite.ep, curPage);
                  },
                ),
              ),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: Icon(Icons.menu_book),
                  onPressed: () {
                    widget.goComicInfo(curComic);
                  },
                ),
              ),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    var data = await _getCurrentImageData(curImageFavorite);
                    if (data == null) {
                      return;
                    }
                    var fileType = detectFileType(data);
                    var filename = "${curImageFavorite.page}${fileType.ext}";
                    saveFile(data: data, filename: filename);
                  },
                ),
              ),
              Flexible(
                flex: 1,
                child: IconButton(
                  icon: Icon(Icons.arrow_circle_right),
                  onPressed: () {
                    if (curImageFavoritesComicIndex ==
                        widget.finalImageFavoritesComicList.length - 1) {
                      curImageFavoritesComicIndex = 0;
                    } else {
                      curImageFavoritesComicIndex += 1;
                    }
                    curIndex = 0;
                    controller.jumpToPage(0);
                    setState(() {});
                  },
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
