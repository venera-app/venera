part of 'reader.dart';

class _ReaderImages extends StatefulWidget {
  const _ReaderImages({super.key});

  @override
  State<_ReaderImages> createState() => _ReaderImagesState();
}

class _ReaderImagesState extends State<_ReaderImages> {
  String? error;

  bool inProgress = false;

  @override
  void initState() {
    context.reader.isLoading = true;
    super.initState();
  }

  void load() async {
    if (inProgress) return;
    inProgress = true;
    if (context.reader.type == ComicType.local ||
        (await LocalManager().isDownloaded(
            context.reader.cid, context.reader.type, context.reader.chapter))) {
      try {
        var images = await LocalManager().getImages(
            context.reader.cid, context.reader.type, context.reader.chapter);
        setState(() {
          context.reader.images = images;
          context.reader.isLoading = false;
          inProgress = false;
        });
      } catch (e) {
        setState(() {
          error = e.toString();
          context.reader.isLoading = false;
          inProgress = false;
        });
      }
    } else {
      var res = await context.reader.type.comicSource!.loadComicPages!(
        context.reader.widget.cid,
        context.reader.widget.chapters?.keys
            .elementAt(context.reader.chapter - 1),
      );
      if (res.error) {
        setState(() {
          error = res.errorMessage;
          context.reader.isLoading = false;
          inProgress = false;
        });
      } else {
        setState(() {
          context.reader.images = res.data;
          context.reader.isLoading = false;
          inProgress = false;
        });
      }
    }
    context.readerScaffold.update();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reader.isLoading) {
      load();
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (error != null) {
      return NetworkError(
        message: error!,
        retry: () {
          setState(() {
            context.reader.isLoading = true;
            error = null;
          });
        },
      );
    } else {
      if (context.reader.mode.isGallery) {
        return _GalleryMode(key: Key(context.reader.mode.key));
      } else {
        // TODO: Implement other modes
        throw UnimplementedError();
      }
    }
  }
}

class _GalleryMode extends StatefulWidget {
  const _GalleryMode({super.key});

  @override
  State<_GalleryMode> createState() => _GalleryModeState();
}

class _GalleryModeState extends State<_GalleryMode>
    implements _ImageViewController {
  late PageController controller;

  late List<bool> cached;

  int get preCacheCount => 4;

  var photoViewControllers = <int, PhotoViewController>{};

  @override
  void initState() {
    controller = PageController(initialPage: context.reader.page);
    context.reader._imageViewController = this;
    cached = List.filled(context.reader.maxPage + 2, false);
    super.initState();
  }

  void cache(int current) {
    for (int i = current + 1; i <= current + preCacheCount; i++) {
      if (i <= context.reader.maxPage && !cached[i]) {
        _precacheImage(i, context);
        cached[i] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      backgroundDecoration: BoxDecoration(
        color: context.colorScheme.surface,
      ),
      reverse: context.reader.mode == ReaderMode.galleryRightToLeft,
      scrollDirection: context.reader.mode == ReaderMode.galleryTopToBottom
          ? Axis.vertical
          : Axis.horizontal,
      itemCount: context.reader.images!.length + 2,
      builder: (BuildContext context, int index) {
        ImageProvider? imageProvider;
        if (index != 0 && index != context.reader.images!.length + 1) {
          imageProvider = _createImageProvider(index, context);
        } else {
          return PhotoViewGalleryPageOptions.customChild(
            scaleStateController: PhotoViewScaleStateController(),
            child: const SizedBox(),
          );
        }

        cached[index] = true;
        cache(index);

        photoViewControllers[index] ??= PhotoViewController();

        return PhotoViewGalleryPageOptions(
          filterQuality: FilterQuality.medium,
          controller: photoViewControllers[index],
          imageProvider: imageProvider,
          fit: BoxFit.contain,
          errorBuilder: (_, error, s, retry) {
            return NetworkError(message: error.toString(), retry: retry);
          },
        );
      },
      pageController: controller,
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
      onPageChanged: (i) {
        if (i == 0) {
          if (!context.reader.toNextChapter()) {
            context.reader.toPage(1);
          }
        } else if (i == context.reader.maxPage + 1) {
          if (!context.reader.toPrevChapter()) {
            context.reader.toPage(context.reader.maxPage);
          }
        } else {
          context.reader.setPage(i);
          context.readerScaffold.update();
        }
      },
    );
  }

  @override
  Future<void> animateToPage(int page) {
    if ((page - controller.page!).abs() > 1) {
      controller.jumpToPage(page > controller.page! ? page - 1 : page + 1);
    }
    return controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }

  @override
  void toPage(int page) {
    controller.jumpToPage(page);
  }

  @override
  void handleDoubleTap(Offset location) {
    var controller = photoViewControllers[context.reader.page]!;
    controller.onDoubleClick?.call();
  }
}

ImageProvider _createImageProvider(int page, BuildContext context) {
  var imageKey = context.reader.images![page-1];
  if(imageKey.startsWith('file://')) {
    return FileImage(File(imageKey.replaceFirst("file://", '')));
  } else {
    return ReaderImageProvider(
      imageKey,
      context.reader.type.comicSource!.key,
      context.reader.cid,
      context.reader.eid,
    );
  }
}

void _precacheImage(int page, BuildContext context) {
  precacheImage(
    _createImageProvider(page, context),
    context,
  );
}
