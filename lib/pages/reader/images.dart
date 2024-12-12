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
        return _GalleryMode(
            key: Key('${reader.mode.key}_${reader.imagesPerPage}'));
      } else {
        return _ContinuousMode(key: Key(reader.mode.key));
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

  int get totalPages => ((reader.images!.length + reader.imagesPerPage - 1) /
          reader.imagesPerPage)
      .ceil();

  @override
  void initState() {
    reader = context.reader;
    controller = PageController(initialPage: reader.page);
    reader._imageViewController = this;
    cached = List.filled(reader.maxPage + 2, false);
    Future.microtask(() {
      context.readerScaffold.setFloatingButton(0);
    });
    super.initState();
  }

  void cache(int current) {
    for (int i = current + 1; i <= current + preCacheCount; i++) {
      if (i <= totalPages && !cached[i]) {
        int startIndex = (i - 1) * reader.imagesPerPage;
        int endIndex =
            math.min(startIndex + reader.imagesPerPage, reader.images!.length);
        for (int i = startIndex; i < endIndex; i++) {
          precacheImage(
              _createImageProviderFromKey(reader.images![i], context), context);
        }
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
      itemCount: totalPages + 2,
      builder: (BuildContext context, int index) {
        if (index == 0 || index == totalPages + 1) {
          return PhotoViewGalleryPageOptions.customChild(
            scaleStateController: PhotoViewScaleStateController(),
            child: const SizedBox(),
          );
        } else {
          int pageIndex = index - 1;
          int startIndex = pageIndex * reader.imagesPerPage;
          int endIndex = math.min(
              startIndex + reader.imagesPerPage, reader.images!.length);
          List<String> pageImages =
              reader.images!.sublist(startIndex, endIndex);

          cached[index] = true;
          cache(index);

          photoViewControllers[index] = PhotoViewController();

          if (reader.imagesPerPage == 1) {
            return PhotoViewGalleryPageOptions(
              filterQuality: FilterQuality.medium,
              controller: photoViewControllers[index],
              imageProvider:
                  _createImageProviderFromKey(pageImages[0], context),
              fit: BoxFit.contain,
              errorBuilder: (_, error, s, retry) {
                return NetworkError(message: error.toString(), retry: retry);
              },
            );
          }

          return PhotoViewGalleryPageOptions.customChild(
            controller: photoViewControllers[index],
            minScale: PhotoViewComputedScale.contained * 1.0,
            maxScale: PhotoViewComputedScale.covered * 10.0,
            child: buildPageImages(pageImages),
          );
        }
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
          if (!reader.toPrevChapter()) {
            reader.toPage(1);
          }
        } else if (i == totalPages + 1) {
          if (!reader.toNextChapter()) {
            reader.toPage(totalPages);
          }
        } else {
          reader.setPage(i);
          context.readerScaffold.update();
        }
      },
    );
  }

  Widget buildPageImages(List<String> images) {
    Axis axis = (reader.mode == ReaderMode.galleryTopToBottom)
        ? Axis.vertical
        : Axis.horizontal;

    List<Widget> imageWidgets = images.map((imageKey) {
      ImageProvider imageProvider =
          _createImageProviderFromKey(imageKey, context);
      return Expanded(
        child: Image(
          image: imageProvider,
          fit: BoxFit.contain,
        ),
      );
    }).toList();

    return axis == Axis.vertical
        ? Column(children: imageWidgets)
        : Row(children: imageWidgets);
  }

  @override
  Future<void> animateToPage(int page) {
    if ((page - controller.page!.round()).abs() > 1) {
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

  @override
  void handleLongPressDown(Offset location) {
    if (!appdata.settings['enableLongPressToZoom']) {
      return;
    }
    var photoViewController = photoViewControllers[reader.page]!;
    double target = photoViewController.getInitialScale!.call()! * 1.75;
    var size = MediaQuery.of(context).size;
    photoViewController.animateScale?.call(
      target,
      Offset(size.width / 2 - location.dx, size.height / 2 - location.dy),
    );
  }

  @override
  void handleLongPressUp(Offset location) {
    if (!appdata.settings['enableLongPressToZoom']) {
      return;
    }
    var photoViewController = photoViewControllers[reader.page]!;
    double target = photoViewController.getInitialScale!.call()!;
    photoViewController.animateScale?.call(target);
  }

  @override
  void handleKeyEvent(KeyEvent event) {
    bool? forward;
    if (reader.mode == ReaderMode.galleryLeftToRight &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      forward = true;
    } else if (reader.mode == ReaderMode.galleryRightToLeft &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      forward = true;
    } else if (reader.mode == ReaderMode.galleryTopToBottom &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      forward = true;
    } else if (reader.mode == ReaderMode.galleryTopToBottom &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      forward = false;
    } else if (reader.mode == ReaderMode.galleryLeftToRight &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      forward = false;
    } else if (reader.mode == ReaderMode.galleryRightToLeft &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      forward = false;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (forward == true) {
        controller.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
        );
      } else if (forward == false) {
        controller.previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
        );
      }
    }
  }
}

const Set<PointerDeviceKind> _kTouchLikeDeviceTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown
};

class _ContinuousMode extends StatefulWidget {
  const _ContinuousMode({super.key});

  @override
  State<_ContinuousMode> createState() => _ContinuousModeState();
}

class _ContinuousModeState extends State<_ContinuousMode>
    implements _ImageViewController {
  late _ReaderState reader;

  var itemScrollController = ItemScrollController();
  var itemPositionsListener = ItemPositionsListener.create();
  var photoViewController = PhotoViewController();
  late ScrollController scrollController;

  var isCTRLPressed = false;
  static var _isMouseScrolling = false;
  var fingers = 0;

  @override
  void initState() {
    reader = context.reader;
    reader._imageViewController = this;
    itemPositionsListener.itemPositions.addListener(onPositionChanged);
    super.initState();
  }

  void onPositionChanged() {
    var page = itemPositionsListener.itemPositions.value.first.index;
    page = page.clamp(1, reader.maxPage);
    if (page != reader.page) {
      reader.setPage(page);
      context.readerScaffold.update();
    }
  }

  double? futurePosition;

  void smoothTo(double offset) {
    futurePosition ??= scrollController.offset;
    if (futurePosition! > scrollController.position.maxScrollExtent &&
        offset > 0) {
      return;
    } else if (futurePosition! < scrollController.position.minScrollExtent &&
        offset < 0) {
      return;
    }
    futurePosition = futurePosition! + offset * 1.2;
    futurePosition = futurePosition!.clamp(
      scrollController.position.minScrollExtent,
      scrollController.position.maxScrollExtent,
    );
    scrollController.animateTo(
      futurePosition!,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  void onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (!_isMouseScrolling) {
        setState(() {
          _isMouseScrolling = true;
        });
      }
      if (isCTRLPressed) {
        return;
      }
      smoothTo(event.scrollDelta.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = ScrollablePositionedList.builder(
      initialScrollIndex: reader.page,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollControllerCallback: (scrollController) {
        this.scrollController = scrollController;
      },
      itemCount: reader.maxPage + 2,
      addSemanticIndexes: false,
      scrollDirection: reader.mode == ReaderMode.continuousTopToBottom
          ? Axis.vertical
          : Axis.horizontal,
      reverse: reader.mode == ReaderMode.continuousRightToLeft,
      physics: isCTRLPressed || _isMouseScrolling
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == 0 || index == reader.maxPage + 1) {
          return const SizedBox();
        }
        double? width, height;
        if (reader.mode == ReaderMode.continuousLeftToRight ||
            reader.mode == ReaderMode.continuousRightToLeft) {
          height = double.infinity;
        } else {
          width = double.infinity;
        }

        _precacheImage(index, context);

        ImageProvider image = _createImageProvider(index, context);

        return ComicImage(
          filterQuality: FilterQuality.medium,
          image: image,
          width: width,
          height: height,
          fit: BoxFit.contain,
        );
      },
      scrollBehavior: const MaterialScrollBehavior()
          .copyWith(scrollbars: false, dragDevices: _kTouchLikeDeviceTypes),
    );

    widget = Listener(
      onPointerDown: (event) {
        fingers++;
        futurePosition = null;
        if (_isMouseScrolling) {
          setState(() {
            _isMouseScrolling = false;
          });
        }
      },
      onPointerUp: (event) {
        fingers--;
      },
      onPointerPanZoomUpdate: (event) {
        if (event.scale == 1.0) {
          smoothTo(0 - event.panDelta.dy);
        }
      },
      onPointerMove: (event) {
        Offset value = event.delta;
        if (photoViewController.scale == 1 || fingers != 1) {
          return;
        }
        if (scrollController.offset !=
                scrollController.position.maxScrollExtent &&
            scrollController.offset !=
                scrollController.position.minScrollExtent) {
          if (reader.mode == ReaderMode.continuousTopToBottom) {
            value = Offset(value.dx, 0);
          } else {
            value = Offset(0, value.dy);
          }
        }
        photoViewController.updateMultiple(
            position: photoViewController.position + value);
      },
      onPointerSignal: onPointerSignal,
      child: widget,
    );

    widget = NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        var length = reader.maxChapter;
        if (!scrollController.hasClients) return false;
        if (scrollController.position.pixels <=
                scrollController.position.minScrollExtent &&
            reader.chapter != 1) {
          context.readerScaffold.setFloatingButton(-1);
        } else if (scrollController.position.pixels >=
                scrollController.position.maxScrollExtent &&
            reader.chapter < length) {
          context.readerScaffold.setFloatingButton(1);
        } else {
          context.readerScaffold.setFloatingButton(0);
        }

        return true;
      },
      child: widget,
    );
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    if (appdata.settings['limitImageWidth'] &&
        width / height > 0.7 &&
        reader.mode == ReaderMode.continuousTopToBottom) {
      width = height * 0.7;
    }

    return PhotoView.customChild(
      backgroundDecoration: BoxDecoration(
        color: context.colorScheme.surface,
      ),
      childSize: Size(width, height),
      minScale: 1.0,
      maxScale: 2.5,
      strictScale: true,
      controller: photoViewController,
      child: SizedBox(
        width: width,
        height: height,
        child: widget,
      ),
    );
  }

  @override
  Future<void> animateToPage(int page) {
    return itemScrollController.scrollTo(
      index: page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
  }

  @override
  void handleDoubleTap(Offset location) {
    double target;
    if (photoViewController.scale !=
        photoViewController.getInitialScale?.call()) {
      target = photoViewController.getInitialScale!.call()!;
    } else {
      target = photoViewController.getInitialScale!.call()! * 1.75;
    }
    var size = MediaQuery.of(context).size;
    photoViewController.animateScale?.call(
      target,
      Offset(size.width / 2 - location.dx, size.height / 2 - location.dy),
    );
  }

  @override
  void handleLongPressDown(Offset location) {
    if (!appdata.settings['enableLongPressToZoom']) {
      return;
    }
    double target = photoViewController.getInitialScale!.call()! * 1.75;
    var size = MediaQuery.of(context).size;
    photoViewController.animateScale?.call(
      target,
      Offset(size.width / 2 - location.dx, size.height / 2 - location.dy),
    );
  }

  @override
  void handleLongPressUp(Offset location) {
    if (!appdata.settings['enableLongPressToZoom']) {
      return;
    }
    double target = photoViewController.getInitialScale!.call()!;
    photoViewController.animateScale?.call(target);
  }

  @override
  void toPage(int page) {
    itemScrollController.jumpTo(index: page);
    futurePosition = null;
  }

  @override
  void handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      setState(() {
        if (event is KeyDownEvent) {
          isCTRLPressed = true;
        } else if (event is KeyUpEvent) {
          isCTRLPressed = false;
        }
      });
    }
    if (event is KeyUpEvent) {
      return;
    }
    bool? forward;
    if (reader.mode == ReaderMode.continuousLeftToRight &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      forward = true;
    } else if (reader.mode == ReaderMode.continuousRightToLeft &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      forward = true;
    } else if (reader.mode == ReaderMode.continuousTopToBottom &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      forward = true;
    } else if (reader.mode == ReaderMode.continuousTopToBottom &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      forward = false;
    } else if (reader.mode == ReaderMode.continuousLeftToRight &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      forward = false;
    } else if (reader.mode == ReaderMode.continuousRightToLeft &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      forward = false;
    }
    if (forward == true) {
      scrollController.animateTo(
        scrollController.offset + context.height,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    } else if (forward == false) {
      scrollController.animateTo(
        scrollController.offset - context.height,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
  }
}

ImageProvider _createImageProviderFromKey(
    String imageKey, BuildContext context) {
  var reader = context.reader;
  return ReaderImageProvider(
    imageKey,
    reader.type.comicSource?.key,
    reader.cid,
    reader.eid,
  );
}

ImageProvider _createImageProvider(int page, BuildContext context) {
  var reader = context.reader;
  var imageKey = reader.images![page - 1];
  return _createImageProviderFromKey(imageKey, context);
}

void _precacheImage(int page, BuildContext context) {
  precacheImage(
    _createImageProvider(page, context),
    context,
  );
}
