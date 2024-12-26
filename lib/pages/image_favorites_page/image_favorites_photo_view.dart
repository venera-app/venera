part of 'image_favorites_page.dart';

class ImageFavoritesPhotoView extends StatefulWidget {
  const ImageFavoritesPhotoView(
      {super.key,
      required this.imageFavoritesGroup,
      required this.page,
      required this.curImageFavoritesGroup});
  final ImageFavoritesGroup imageFavoritesGroup;
  final int page;
  final List<ImageFavoritesGroup> curImageFavoritesGroup;
  @override
  State<ImageFavoritesPhotoView> createState() =>
      ImageFavoritesPhotoViewState();
}

class ImageFavoritesPhotoViewState extends State<ImageFavoritesPhotoView> {
  late PageController controller;
  Map<ImageFavorite, bool> cancelImageFavorites = {};
  // 图片当前的 index
  late int curIndex;
  late int curImageFavoritesGroupIndex;
  @override
  void initState() {
    curIndex = widget.imageFavoritesGroup.imageFavorites.indexWhere((ele) {
      return ele.page == widget.page;
    });
    controller = PageController(initialPage: curIndex);
    curImageFavoritesGroupIndex =
        widget.curImageFavoritesGroup.indexWhere((ele) {
      return ele.id == widget.imageFavoritesGroup.id;
    });
    super.initState();
  }

  void onPop() {}
  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final ImageFavorite curImageFavorite = widget
        .curImageFavoritesGroup[curImageFavoritesGroupIndex]
        .imageFavorites[index];
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

  @override
  Widget build(BuildContext context) {
    ImageFavoritesGroup curGroup =
        widget.curImageFavoritesGroup[curImageFavoritesGroupIndex];
    ImageFavorite curImageFavorite = curGroup.imageFavorites[curIndex];
    int curPage = curImageFavorite.page;
    String pageText = curPage == 0 ? 'cover'.tl : (curPage + 1).toString();
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
          itemCount: curGroup.imageFavorites.length,
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
          customSize: MediaQuery.of(context)
              .size, //定义图片默认缩放基础的大小,默认全屏 MediaQuery.of(context).size
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
            child: Text(
              curGroup.title,
              style: ts.s18,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ).paddingTop(20),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: Icon(Icons.arrow_circle_left),
              onPressed: () {
                if (curImageFavoritesGroupIndex == 0) {
                  curImageFavoritesGroupIndex =
                      widget.curImageFavoritesGroup.length - 1;
                } else {
                  curImageFavoritesGroupIndex -= 1;
                }
                curIndex = 0;
                controller.jumpToPage(0);
                setState(() {});
              },
            ),
            IconButton(
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
            Text(
              pageText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.arrow_circle_right),
              onPressed: () {
                if (curImageFavoritesGroupIndex ==
                    widget.curImageFavoritesGroup.length - 1) {
                  curImageFavoritesGroupIndex = 0;
                } else {
                  curImageFavoritesGroupIndex += 1;
                }
                curIndex = 0;
                controller.jumpToPage(0);
                setState(() {});
              },
            ),
          ]),
        ),
        Positioned(
            bottom: 33,
            right: 20,
            child: IntrinsicWidth(
              stepWidth: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("${curIndex + 1}/${curGroup.imageFavorites.length}",
                    style: ts.s12),
              ),
            ))
      ]),
    );
  }
}
