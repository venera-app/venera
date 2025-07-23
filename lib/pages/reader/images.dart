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

  @override
  void dispose() {
    super.dispose();
    ImageDownloader.cancelAllLoadingImages();
  }

  void load() async {
    if (inProgress) return;
    inProgress = true;
    if (reader.type == ComicType.local ||
        (LocalManager().isDownloaded(
            reader.cid, reader.type, reader.chapter, reader.widget.chapters))) {
      try {
        var images = await LocalManager()
            .getImages(reader.cid, reader.type, reader.chapter);
        setState(() {
          reader.images = images;
          reader.isLoading = false;
          inProgress = false;
          Future.microtask(() {
            reader.updateHistory();
          });
        });
      } catch (e) {
        setState(() {
          error = e.toString();
          reader.isLoading = false;
          inProgress = false;
        });
      }
    } else {
      var cp = reader.widget.chapters?.ids.elementAtOrNull(reader.chapter - 1);
      var res = await reader.type.comicSource!.loadComicPages!(
        reader.widget.cid,
        cp,
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
          Future.microtask(() {
            reader.updateHistory();
          });
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
      return GestureDetector(
        onTap: () {
          context.readerScaffold.openOrClose();
        },
        child: SizedBox.expand(
          child: NetworkError(
            message: error!,
            retry: () {
              setState(() {
                reader.isLoading = true;
                error = null;
              });
            },
          ),
        ),
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

  int get preCacheCount => appdata.settings["preloadImageCount"];

  var photoViewControllers = <int, PhotoViewController>{};

  late _ReaderState reader;

  /// [totalPages] is the total number of pages in the current chapter.
  /// More than one images can be displayed on one page.
  int get totalPages {
    if (!reader.showSingleImageOnFirstPage) {
      return (reader.images!.length / reader.imagesPerPage).ceil();
    } else {
      return 1 +
          ((reader.images!.length - 1) / reader.imagesPerPage).ceil();
    }
  }

  var imageStates = <State<ComicImage>>{};

  bool isLongPressing = false;

  int fingers = 0;

  @override
  void initState() {
    reader = context.reader;
    controller = PageController(initialPage: reader.page);
    reader._imageViewController = this;
    Future.microtask(() {
      context.readerScaffold.setFloatingButton(0);
    });
    super.initState();
  }

  /// Get the range of images for the given page. [page] is 1-based.
  (int start, int end) getPageImagesRange(int page) {
    if (reader.showSingleImageOnFirstPage) {
      if (page == 1) {
        return (0, 1);
      } else {
        int startIndex = (page - 2) * reader.imagesPerPage + 1;
        int endIndex = math.min(
            startIndex + reader.imagesPerPage, reader.images!.length);
        return (startIndex, endIndex);
      }
    } else {
      int startIndex = (page - 1) * reader.imagesPerPage;
      int endIndex = math.min(
          startIndex + reader.imagesPerPage, reader.images!.length);
      return (startIndex, endIndex);
    }
  }

  /// [cache] is used to cache the images.
  /// The count of images to cache is determined by the [preCacheCount] setting.
  /// For previous page and next page, it will do a memory cache.
  /// For current page, it will do nothing because it is already on the screen.
  /// For other pages, it will do a pre-download cache.
  void cache(int startPage) {
    for (int i = startPage - 1; i <= startPage + preCacheCount; i++) {
      if (i == startPage || i <= 0 || i > totalPages) continue;
      bool shouldPreCache = i == startPage + 1 || i == startPage - 1;
      _cachePage(i, shouldPreCache);
    }
  }

  void _cachePage(int page, bool shouldPreCache) {
    var (startIndex, endIndex) = getPageImagesRange(page);
    for (int i = startIndex; i < endIndex; i++) {
      if (shouldPreCache) {
        _precacheImage(i+1, context);
      } else {
        _preDownloadImage(i+1, context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        fingers++;
      },
      onPointerUp: (event) {
        fingers--;
      },
      onPointerCancel: (event) {
        fingers--;
      },
      onPointerMove: (event) {
        if (isLongPressing) {
          var controller = photoViewControllers[reader.page]!;
          Offset value = event.delta;
          if (isLongPressing) {
            controller.updateMultiple(
              position: controller.position + value,
            );
          }
        }
      },
      child: PhotoViewGallery.builder(
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
              child: const SizedBox(),
            );
          } else {
            var (startIndex, endIndex) = getPageImagesRange(index);
            List<String> pageImages =
                reader.images!.sublist(startIndex, endIndex);

            cache(index);

            photoViewControllers[index] ??= PhotoViewController();

            if (reader.imagesPerPage == 1 || pageImages.length == 1) {
              return PhotoViewGalleryPageOptions(
                filterQuality: FilterQuality.medium,
                controller: photoViewControllers[index],
                imageProvider: _createImageProviderFromKey(
                  pageImages[0],
                  context,
                  startIndex + 1,
                ),
                fit: BoxFit.contain,
                errorBuilder: (_, error, s, retry) {
                  return NetworkError(message: error.toString(), retry: retry);
                },
              );
            }

            return PhotoViewGalleryPageOptions.customChild(
              childSize: reader.size * 2,
              controller: photoViewControllers[index],
              minScale: PhotoViewComputedScale.contained * 1.0,
              maxScale: PhotoViewComputedScale.covered * 10.0,
              child: buildPageImages(pageImages, startIndex),
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
            if (reader.isFirstChapterOfGroup || !reader.toPrevChapter()) {
              reader.toPage(1);
            }
          } else if (i == totalPages + 1) {
            if (reader.isLastChapterOfGroup || !reader.toNextChapter()) {
              reader.toPage(totalPages);
            }
          } else {
            reader.setPage(i);
            context.readerScaffold.update();
          }
          // Remove other pages' controllers to reset their state.
          var keys = photoViewControllers.keys.toList();
          for (var key in keys) {
            if (key != i) {
              photoViewControllers.remove(key);
            }
          }
        },
      ),
    );
  }

  Widget buildPageImages(List<String> images, int startIndex) {
    Axis axis = (reader.mode == ReaderMode.galleryTopToBottom)
        ? Axis.vertical
        : Axis.horizontal;

    bool reverse = reader.mode == ReaderMode.galleryRightToLeft;
    if (reverse) {
      images = images.reversed.toList();
    }

    List<Widget> imageWidgets;

    if (images.length == 2) {
      imageWidgets = [
        Expanded(
          child: ComicImage(
            width: double.infinity,
            height: double.infinity,
            image: _createImageProviderFromKey(
              images[0],
              context,
              startIndex + 1,
            ),
            fit: BoxFit.contain,
            alignment: axis == Axis.vertical
                ? Alignment.bottomCenter
                : Alignment.centerRight,
            onInit: (state) => imageStates.add(state),
            onDispose: (state) => imageStates.remove(state),
          ),
        ),
        Expanded(
          child: ComicImage(
            width: double.infinity,
            height: double.infinity,
            image: _createImageProviderFromKey(
              images[1],
              context,
              startIndex + 2,
            ),
            fit: BoxFit.contain,
            alignment: axis == Axis.vertical
                ? Alignment.topCenter
                : Alignment.centerLeft,
            onInit: (state) => imageStates.add(state),
            onDispose: (state) => imageStates.remove(state),
          ),
        )
      ];
    } else {
      imageWidgets = images.map((imageKey) {
        startIndex++;
        ImageProvider imageProvider =
            _createImageProviderFromKey(imageKey, context, startIndex);
        return Expanded(
          child: ComicImage(
            image: imageProvider,
            fit: BoxFit.contain,
            onInit: (state) => imageStates.add(state),
            onDispose: (state) => imageStates.remove(state),
          ),
        );
      }).toList();
    }

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
    if (appdata.settings['quickCollectImage'] == 'DoubleTap') {
      context.readerScaffold.addImageFavorite();
      return;
    }
    var controller = photoViewControllers[reader.page]!;
    controller.onDoubleClick?.call();
  }

  @override
  void handleLongPressDown(Offset location) {
    if (!appdata.settings['enableLongPressToZoom'] || fingers != 1) {
      return;
    }
    var photoViewController = photoViewControllers[reader.page]!;
    double target = photoViewController.getInitialScale!.call()! * 1.75;
    var size = reader.size;
    Offset zoomPosition;
    if (appdata.settings['longPressZoomPosition'] != 'center') {
      zoomPosition = Offset(
        size.width / 2 - location.dx,
        size.height / 2 - location.dy,
      );
    } else {
      zoomPosition = Offset(0, 0);
    }
    photoViewController.animateScale?.call(
      target,
      zoomPosition,
    );
    isLongPressing = true;
  }

  @override
  void handleLongPressUp(Offset location) {
    if (!appdata.settings['enableLongPressToZoom'] || !isLongPressing) {
      return;
    }
    var photoViewController = photoViewControllers[reader.page]!;
    double target = photoViewController.getInitialScale!.call()!;
    photoViewController.animateScale?.call(target);
    isLongPressing = false;
  }

  Timer? keyRepeatTimer;

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
    if (event is KeyDownEvent) {
      if (keyRepeatTimer != null) {
        keyRepeatTimer!.cancel();
        keyRepeatTimer = null;
      }
      if (forward == true) {
        reader.toPage(reader.page+1);
      } else if (forward == false) {
        reader.toPage(reader.page-1);
      }
    }
    if (event is KeyRepeatEvent && keyRepeatTimer == null) {
      keyRepeatTimer = Timer.periodic(
        reader.enablePageAnimation
            ? const Duration(milliseconds: 200)
            : const Duration(milliseconds: 50),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          } else if (forward == true) {
            reader.toPage(reader.page+1);
          } else if (forward == false) {
            reader.toPage(reader.page-1);
          }
        },
      );
    }
    if (event is KeyUpEvent && keyRepeatTimer != null) {
      keyRepeatTimer!.cancel();
      keyRepeatTimer = null;
    }
  }

  @override
  bool handleOnTap(Offset location) {
    return false;
  }

  @override
  Future<Uint8List?> getImageByOffset(Offset offset) async {
    var imageKey = getImageKeyByOffset(offset);
    if (imageKey == null) return null;
    if (imageKey.startsWith("file://")) {
      return await File(imageKey.substring(7)).readAsBytes();
    } else {
      return (await CacheManager().findCache(
              "$imageKey@${context.reader.type.sourceKey}@${context.reader.cid}@${context.reader.eid}"))!
          .readAsBytes();
    }
  }

  @override
  String? getImageKeyByOffset(Offset offset) {
    String? imageKey;
    if (reader.imagesPerPage == 1) {
      imageKey = reader.images![reader.page - 1];
    } else {
      for (var imageState in imageStates) {
        if ((imageState as _ComicImageState).containsPoint(offset)) {
          imageKey = (imageState.widget.image as ReaderImageProvider).imageKey;
        }
      }
    }
    return imageKey;
  }
}

const Set<PointerDeviceKind> _kTouchLikeDeviceTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown
};

const double _kChangeChapterOffset = 160;

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
  ScrollController? _scrollController;

  ScrollController get scrollController => _scrollController!;

  var isCTRLPressed = false;
  static var _isMouseScrolling = false;
  var fingers = 0;
  bool disableScroll = false;

  late List<bool> cached;

  int get preCacheCount => appdata.settings["preloadImageCount"];

  /// Whether the user was scrolling the page.
  /// The gesture detector has a delay to detect tap event.
  /// To handle the tap event, we need to know if the user was scrolling before the delay.
  bool delayedIsScrolling = false;

  var imageStates = <State<ComicImage>>{};

  void delayedSetIsScrolling(bool value) {
    Future.delayed(
      const Duration(milliseconds: 300),
      () => delayedIsScrolling = value,
    );
  }

  bool prepareToPrevChapter = false;
  bool prepareToNextChapter = false;
  bool jumpToNextChapter = false;
  bool jumpToPrevChapter = false;

  bool isZoomedIn = false;
  bool isLongPressing = false;

  @override
  void initState() {
    reader = context.reader;
    reader._imageViewController = this;
    itemPositionsListener.itemPositions.addListener(onPositionChanged);
    cached = List.filled(reader.maxPage + 2, false);
    Future.delayed(
      const Duration(milliseconds: 100),
      () => cacheImages(reader.page),
    );
    super.initState();
  }

  @override
  void dispose() {
    itemPositionsListener.itemPositions.removeListener(onPositionChanged);
    super.dispose();
  }

  void onPositionChanged() {
    if (itemPositionsListener.itemPositions.value.isEmpty) {
      return;
    }
    var page = itemPositionsListener.itemPositions.value.first.index;
    page = page.clamp(1, reader.maxPage);
    if (page != reader.page) {
      reader.setPage(page);
      context.readerScaffold.update();
    }
    cacheImages(page);
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

  void cacheImages(int current) {
    for (int i = current + 1; i <= current + preCacheCount; i++) {
      if (i <= reader.maxPage && !cached[i]) {
        _preDownloadImage(i, context);
        cached[i] = true;
      }
    }
  }

  void onScroll() {
    if (prepareToPrevChapter) {
      jumpToNextChapter = false;
      jumpToPrevChapter = scrollController.offset <
          scrollController.position.minScrollExtent - _kChangeChapterOffset;
    } else if (prepareToNextChapter) {
      jumpToNextChapter = scrollController.offset >
          scrollController.position.maxScrollExtent + _kChangeChapterOffset;
      jumpToPrevChapter = false;
    }
  }

  bool onScaleUpdate([double? scale]) {
    if (prepareToNextChapter || prepareToPrevChapter) {
      setState(() {
        prepareToPrevChapter = false;
        prepareToNextChapter = false;
      });
      context.readerScaffold.setFloatingButton(0);
    }
    var isZoomedIn = (scale ?? photoViewController.scale) != 1.0;
    if (isZoomedIn != this.isZoomedIn) {
      setState(() {
        this.isZoomedIn = isZoomedIn;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = ScrollablePositionedList.builder(
      initialScrollIndex: reader.page,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollControllerCallback: (scrollController) {
        if (_scrollController != null) {
          _scrollController!.removeListener(onScroll);
        }
        _scrollController = scrollController;
        _scrollController!.addListener(onScroll);
      },
      itemCount: reader.maxPage + 2,
      addSemanticIndexes: false,
      scrollDirection: reader.mode == ReaderMode.continuousTopToBottom
          ? Axis.vertical
          : Axis.horizontal,
      reverse: reader.mode == ReaderMode.continuousRightToLeft,
      physics: isCTRLPressed || _isMouseScrolling || disableScroll
          ? const NeverScrollableScrollPhysics()
          : isZoomedIn
              ? const ClampingScrollPhysics()
              : const BouncingScrollPhysics(),
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

        ImageProvider image = _createImageProvider(index, context);

        return ColoredBox(
          color: context.colorScheme.surface,
          child: ComicImage(
            filterQuality: FilterQuality.medium,
            image: image,
            width: width,
            height: height,
            fit: BoxFit.contain,
            onInit: (state) => imageStates.add(state),
            onDispose: (state) => imageStates.remove(state),
          ),
        );
      },
      scrollBehavior: const MaterialScrollBehavior()
          .copyWith(scrollbars: false, dragDevices: _kTouchLikeDeviceTypes),
    );

    widget = Stack(
      children: [
        Positioned.fill(child: buildBackground(context)),
        Positioned.fill(child: widget),
      ],
    );

    widget = Listener(
      onPointerDown: (event) {
        fingers++;
        if (fingers > 1 && !disableScroll) {
          setState(() {
            disableScroll = true;
          });
        }
        futurePosition = null;
        if (_isMouseScrolling) {
          setState(() {
            _isMouseScrolling = false;
          });
        }
      },
      onPointerUp: (event) {
        fingers--;
        if (fingers <= 1 && disableScroll) {
          setState(() {
            disableScroll = false;
          });
        }
        if (fingers == 0) {
          if (jumpToPrevChapter) {
            context.readerScaffold.setFloatingButton(0);
            reader.toPrevChapter();
          } else if (jumpToNextChapter) {
            context.readerScaffold.setFloatingButton(0);
            reader.toNextChapter();
          }
        }
      },
      onPointerCancel: (event) {
        fingers--;
        if (fingers <= 1 && disableScroll) {
          setState(() {
            disableScroll = false;
          });
        }
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
        Offset offset;
        var sp = scrollController.position;
        if (sp.pixels <= sp.minScrollExtent ||
            sp.pixels >= sp.maxScrollExtent) {
          offset = Offset(value.dx, value.dy);
        } else {
          if (reader.mode == ReaderMode.continuousTopToBottom) {
            offset = Offset(value.dx, 0);
          } else {
            offset = Offset(0, value.dy);
          }
        }
        if (isLongPressing) {
          offset += value;
        }
        photoViewController.updateMultiple(
          position: photoViewController.position + offset,
        );
      },
      onPointerSignal: onPointerSignal,
      child: widget,
    );

    widget = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          delayedSetIsScrolling(true);
        } else if (notification is ScrollEndNotification) {
          delayedSetIsScrolling(false);
        }

        var scale = photoViewController.scale ?? 1.0;

        if (notification is ScrollUpdateNotification &&
            (scale - 1).abs() < 0.05) {
          if (!scrollController.hasClients) return false;
          if (scrollController.position.pixels <=
                  scrollController.position.minScrollExtent &&
              !reader.isFirstChapterOfGroup) {
            if (!prepareToPrevChapter) {
              jumpToPrevChapter = false;
              jumpToNextChapter = false;
              context.readerScaffold.setFloatingButton(-1);
              setState(() {
                prepareToPrevChapter = true;
              });
            }
          } else if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent &&
              !reader.isLastChapterOfGroup) {
            if (!prepareToNextChapter) {
              jumpToPrevChapter = false;
              jumpToNextChapter = false;
              context.readerScaffold.setFloatingButton(1);
              setState(() {
                prepareToNextChapter = true;
              });
            }
          } else {
            context.readerScaffold.setFloatingButton(0);
            if (prepareToPrevChapter || prepareToNextChapter) {
              jumpToPrevChapter = false;
              jumpToNextChapter = false;
              setState(() {
                prepareToPrevChapter = false;
                prepareToNextChapter = false;
              });
            }
          }
        }

        return true;
      },
      child: widget,
    );
    var width = reader.size.width;
    var height = reader.size.height;
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
      onScaleUpdate: onScaleUpdate,
      child: SizedBox(
        width: width,
        height: height,
        child: widget,
      ),
    );
  }

  Widget buildBackground(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: context.padding.top + 16),
        if (prepareToPrevChapter)
          _SwipeChangeChapterProgress(
            controller: scrollController,
            isPrev: true,
          ),
        const Spacer(),
        if (prepareToNextChapter)
          _SwipeChangeChapterProgress(
            controller: scrollController,
            isPrev: false,
          ),
        SizedBox(height: 36),
      ],
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
    if (appdata.settings['quickCollectImage'] == 'DoubleTap') {
      context.readerScaffold.addImageFavorite();
      return;
    }
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
    onScaleUpdate(target);
  }

  @override
  void handleLongPressDown(Offset location) {
    if (!appdata.settings['enableLongPressToZoom'] || delayedIsScrolling) {
      return;
    }
    double target = photoViewController.getInitialScale!.call()! * 1.75;
    var size = reader.size;
    Offset zoomPosition;
    if (appdata.settings['longPressZoomPosition'] != 'center') {
      zoomPosition = Offset(
        size.width / 2 - location.dx,
        size.height / 2 - location.dy,
      );
    } else {
      zoomPosition = Offset(0, 0);
    }
    photoViewController.animateScale?.call(
      target,
      zoomPosition,
    );
    onScaleUpdate(target);
    isLongPressing = true;
  }

  @override
  void handleLongPressUp(Offset location) {
    if (!appdata.settings['enableLongPressToZoom']) {
      return;
    }
    double target = photoViewController.getInitialScale!.call()!;
    photoViewController.animateScale?.call(target);
    onScaleUpdate(target);
    isLongPressing = false;
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
        scrollController.offset + context.height * 0.25,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    } else if (forward == false) {
      scrollController.animateTo(
        scrollController.offset - context.height * 0.25,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
  }

  @override
  bool handleOnTap(Offset location) {
    if (delayedIsScrolling) {
      return true;
    }
    return false;
  }

  @override
  Future<Uint8List?> getImageByOffset(Offset offset) async {
    var imageKey = getImageKeyByOffset(offset);
    if (imageKey == null) return null;
    if (imageKey.startsWith("file://")) {
      return await File(imageKey.substring(7)).readAsBytes();
    } else {
      return (await CacheManager().findCache(
              "$imageKey@${context.reader.type.sourceKey}@${context.reader.cid}@${context.reader.eid}"))!
          .readAsBytes();
    }
  }

  @override
  String? getImageKeyByOffset(Offset offset) {
    String? imageKey;
    for (var imageState in imageStates) {
      if ((imageState as _ComicImageState).containsPoint(offset)) {
        imageKey = (imageState.widget.image as ReaderImageProvider).imageKey;
      }
    }
    return imageKey;
  }
}

ImageProvider _createImageProviderFromKey(
  String imageKey,
  BuildContext context,
  int page,
) {
  var reader = context.reader;
  return ReaderImageProvider(
    imageKey,
    reader.type.comicSource?.key,
    reader.cid,
    reader.eid,
    reader.page,
  );
}

ImageProvider _createImageProvider(int page, BuildContext context) {
  var reader = context.reader;
  var imageKey = reader.images![page - 1];
  return _createImageProviderFromKey(imageKey, context, page);
}

/// [_precacheImage] is used to precache the image for the given page.
/// The image is cached using the flutter's [precacheImage] method.
/// The image will be downloaded and decoded into memory.
void _precacheImage(int page, BuildContext context) {
  if (page <= 0 || page > context.reader.images!.length) {
    return;
  }
  precacheImage(
    _createImageProvider(page, context),
    context,
  );
}

/// [_preDownloadImage] is used to download the image for the given page.
/// The image is downloaded using the [CacheManager] and saved to the local storage.
void _preDownloadImage(int page, BuildContext context) {
  if (page <= 0 || page > context.reader.images!.length) {
    return;
  }
  var reader = context.reader;
  var imageKey = reader.images![page - 1];
  if (imageKey.startsWith("file://")) {
    return;
  }
  var cid = reader.cid;
  var eid = reader.eid;
  var sourceKey = reader.type.comicSource?.key;
  ImageDownloader.loadComicImage(imageKey, sourceKey, cid, eid);
}

class _SwipeChangeChapterProgress extends StatefulWidget {
  const _SwipeChangeChapterProgress({
    this.controller,
    required this.isPrev,
  });

  final ScrollController? controller;

  final bool isPrev;

  @override
  State<_SwipeChangeChapterProgress> createState() =>
      _SwipeChangeChapterProgressState();
}

class _SwipeChangeChapterProgressState
    extends State<_SwipeChangeChapterProgress> {
  double value = 0;

  late final isPrev = widget.isPrev;

  ScrollController? controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      controller = widget.controller;
      controller!.addListener(onScroll);
    }
  }

  @override
  void didUpdateWidget(covariant _SwipeChangeChapterProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      controller?.removeListener(onScroll);
      controller = widget.controller;
      controller?.addListener(onScroll);
      if (value != 0) {
        setState(() {
          value = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller?.removeListener(onScroll);
  }

  void onScroll() {
    var position = controller!.position.pixels;
    var offset = isPrev
        ? controller!.position.minScrollExtent - position
        : position - controller!.position.maxScrollExtent;
    var newValue = offset / _kChangeChapterOffset;
    newValue = newValue.clamp(0.0, 1.0);
    if (newValue != value) {
      setState(() {
        value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.isPrev
        ? "Swipe down for previous chapter".tl
        : "Swipe up for next chapter".tl;

    return CustomPaint(
      painter: _ProgressPainter(
        value: value,
        backgroundColor: context.colorScheme.surfaceContainerLow,
        color: context.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isPrev ? Icons.arrow_downward : Icons.arrow_upward,
            color: context.colorScheme.onSurface,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(msg),
        ],
      ).paddingVertical(6).paddingHorizontal(16),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double value;

  final Color backgroundColor;

  final Color color;

  const _ProgressPainter({
    required this.value,
    required this.backgroundColor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(16)),
      paint,
    );

    paint.color = color;
    canvas.drawRRect(
      RRect.fromLTRBR(
          0, 0, size.width * value, size.height, Radius.circular(16)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ProgressPainter ||
        oldDelegate.value != value ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.color != color;
  }
}
