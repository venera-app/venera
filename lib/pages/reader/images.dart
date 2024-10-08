part of 'reader.dart';

class _ReaderImages extends StatefulWidget {
  const _ReaderImages({super.key});

  @override
  State<_ReaderImages> createState() => _ReaderImagesState();
}

class _ReaderImagesState extends State<_ReaderImages> {
  String? error;

  bool inProgress = false;

  late _ReaderState reader;

  @override
  void initState() {
    reader = context.reader;
    reader.isLoading = true;
    super.initState();
  }

  void load() async {
    if (inProgress) return;
    inProgress = true;
    if (reader.type == ComicType.local ||
        (await LocalManager()
            .isDownloaded(reader.cid, reader.type, reader.chapter))) {
      try {
        var images = await LocalManager()
            .getImages(reader.cid, reader.type, reader.chapter);
        setState(() {
          reader.images = images;
          reader.isLoading = false;
          inProgress = false;
        });
      } catch (e) {
        setState(() {
          error = e.toString();
          reader.isLoading = false;
          inProgress = false;
        });
      }
    } else {
      var res = await reader.type.comicSource!.loadComicPages!(
        reader.widget.cid,
        reader.widget.chapters?.keys.elementAt(reader.chapter - 1),
      );
      if (res.error) {
        setState(() {
          error = res.errorMessage;
          reader.isLoading = false;
          inProgress = false;
        });
      } else {
        setState(() {
          reader.images = res.data;
          reader.isLoading = false;
          inProgress = false;
        });
      }
    }
    context.readerScaffold.update();
  }

  @override
  Widget build(BuildContext context) {
    if (reader.isLoading) {
      load();
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (error != null) {
      return NetworkError(
        message: error!,
        retry: () {
          setState(() {
            reader.isLoading = true;
            error = null;
          });
        },
      );
    } else {
      if (reader.mode.isGallery) {
        return _GalleryMode(key: Key(reader.mode.key));
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

  late _ReaderState reader;

  @override
  void initState() {
    reader = context.reader;
    controller = PageController(initialPage: reader.page);
    reader._imageViewController = this;
    cached = List.filled(reader.maxPage + 2, false);
    super.initState();
  }

  void cache(int current) {
    for (int i = current + 1; i <= current + preCacheCount; i++) {
      if (i <= reader.maxPage && !cached[i]) {
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
      reverse: reader.mode == ReaderMode.galleryRightToLeft,
      scrollDirection: reader.mode == ReaderMode.galleryTopToBottom
          ? Axis.vertical
          : Axis.horizontal,
      itemCount: reader.images!.length + 2,
      builder: (BuildContext context, int index) {
        ImageProvider? imageProvider;
        if (index != 0 && index != reader.images!.length + 1) {
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
          if (!reader.toNextChapter()) {
            reader.toPage(1);
          }
        } else if (i == reader.maxPage + 1) {
          if (!reader.toPrevChapter()) {
            reader.toPage(reader.maxPage);
          }
        } else {
          reader.setPage(i);
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
    var controller = photoViewControllers[reader.page]!;
    controller.onDoubleClick?.call();
  }
}

ImageProvider _createImageProvider(int page, BuildContext context) {
  var reader = context.reader;
  var imageKey = reader.images![page - 1];
  if (imageKey.startsWith('file://')) {
    return FileImage(File(imageKey.replaceFirst("file://", '')));
  } else {
    return ReaderImageProvider(
      imageKey,
      reader.type.comicSource!.key,
      reader.cid,
      reader.eid,
    );
  }
}

void _precacheImage(int page, BuildContext context) {
  precacheImage(
    _createImageProvider(page, context),
    context,
  );
}
