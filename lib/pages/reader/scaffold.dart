part of 'reader.dart';

class _ReaderScaffold extends StatefulWidget {
  const _ReaderScaffold({required this.child});

  final Widget child;

  @override
  State<_ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends State<_ReaderScaffold> {
  bool _isOpen = false;

  static const kTopBarHeight = 56.0;

  static const kBottomBarHeight = 105.0;

  bool get isOpen => _isOpen;

  bool get isReversed =>
      context.reader.mode == ReaderMode.galleryRightToLeft ||
      context.reader.mode == ReaderMode.continuousRightToLeft;

  int showFloatingButtonValue = 0;

  var lastValue = 0;

  _ReaderGestureDetectorState? _gestureDetectorState;

  void setFloatingButton(int value) {
    lastValue = showFloatingButtonValue;
    if (value == 0) {
      if (showFloatingButtonValue != 0) {
        showFloatingButtonValue = 0;
        update();
      }
    }
    if (value == 1 && showFloatingButtonValue == 0) {
      showFloatingButtonValue = 1;
      update();
    } else if (value == -1 && showFloatingButtonValue == 0) {
      showFloatingButtonValue = -1;
      update();
    }
  }

  _DragListener? _imageFavoriteDragListener;

  void addDragListener() async {
    if (!mounted) return;
    var readerMode = context.reader.mode;

    // 横向阅读的时候, 如果纵向滑就触发收藏, 纵向阅读的时候, 如果横向滑动就触发收藏
    if (appdata.settings['quickCollectImage'] == 'Swipe') {
      if (_imageFavoriteDragListener == null) {
        double distance = 0;
        _imageFavoriteDragListener = _DragListener(
          onMove: (offset) {
            switch (readerMode) {
              case ReaderMode.continuousTopToBottom:
              case ReaderMode.galleryTopToBottom:
                distance += offset.dx;
              case ReaderMode.continuousLeftToRight:
              case ReaderMode.galleryLeftToRight:
              case ReaderMode.galleryRightToLeft:
              case ReaderMode.continuousRightToLeft:
                distance += offset.dy;
            }
          },
          onEnd: () {
            if (distance.abs() > 150) {
              addImageFavorite();
            }
            distance = 0;
          },
        );
      }
      _gestureDetectorState!.addDragListener(_imageFavoriteDragListener!);
    } else if (_imageFavoriteDragListener != null) {
      _gestureDetectorState!.removeDragListener(_imageFavoriteDragListener!);
    }
  }

  @override
  void initState() {
    sliderFocus.canRequestFocus = false;
    sliderFocus.addListener(() {
      if (sliderFocus.hasFocus) {
        sliderFocus.nextFocus();
      }
    });
    if (rotation != null) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), addDragListener);
  }

  @override
  void dispose() {
    sliderFocus.dispose();
    super.dispose();
  }

  void openOrClose() {
    if (!_isOpen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      if (!appdata.settings['showSystemStatusBar']) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  bool? rotation;

  void update() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (appdata.settings['showPageNumberInReader'] == true)
          buildPageInfoText(),
        buildStatusInfo(),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          right: 16,
          bottom: showFloatingButtonValue == 0 ? -58 : 36,
          child: buildEpChangeButton(),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          top: _isOpen ? 0 : -(kTopBarHeight + context.padding.top),
          left: 0,
          right: 0,
          height: kTopBarHeight + context.padding.top,
          child: buildTop(),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          bottom: _isOpen
              ? 0
              : -(kBottomBarHeight + MediaQuery.of(context).padding.bottom),
          left: 0,
          right: 0,
          child: buildBottom(),
        ),
      ],
    );
  }

  Widget buildTop() {
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.92),
          border: Border(
            bottom: BorderSide(color: Colors.grey.toOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            const BackButton(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.reader.widget.name,
                style: ts.s18,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: "Settings".tl,
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: openSetting,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  bool isLiked() {
    return ImageFavoriteManager().has(
      context.reader.cid,
      context.reader.type.sourceKey,
      context.reader.eid,
      context.reader.page,
      context.reader.chapter,
    );
  }

  void addImageFavorite() async {
    try {
      if (context.reader.images![0].contains('file://')) {
        showToast(
          message: "Local comic collection is not supported at present".tl,
          context: context,
        );
        return;
      }
      String id = context.reader.cid;
      int ep = context.reader.chapter;
      String eid = context.reader.eid;
      String title = context.reader.history!.title;
      String subTitle = context.reader.history!.subtitle;
      int maxPage = context.reader.images!.length;
      int? page = await selectImage();
      if (page == null) return;
      page += 1;
      String sourceKey = context.reader.type.sourceKey;
      String imageKey = context.reader.images![page - 1];
      List<String> tags = context.reader.widget.tags;
      String author = context.reader.widget.author;

      var epName =
          context.reader.widget.chapters?.titles.elementAtOrNull(
            context.reader.chapter - 1,
          ) ??
          "E${context.reader.chapter}";
      var translatedTags = tags.map((e) => e.translateTagsToCN).toList();

      if (isLiked()) {
        if (page == firstPage) {
          showToast(
            message: "The cover cannot be uncollected here".tl,
            context: context,
          );
          return;
        }
        ImageFavoriteManager().deleteImageFavorite([
          ImageFavorite(page, imageKey, null, eid, id, ep, sourceKey, epName),
        ]);
        showToast(
          message: "Uncollected the image".tl,
          context: context,
          seconds: 1,
        );
      } else {
        var imageFavoritesComic =
            ImageFavoriteManager().find(id, sourceKey) ??
            ImageFavoritesComic(
              id,
              [],
              title,
              sourceKey,
              tags,
              translatedTags,
              DateTime.now(),
              author,
              {},
              subTitle,
              maxPage,
            );
        ImageFavorite imageFavorite = ImageFavorite(
          page,
          imageKey,
          null,
          eid,
          id,
          ep,
          sourceKey,
          epName,
        );
        ImageFavoritesEp? imageFavoritesEp = imageFavoritesComic
            .imageFavoritesEp
            .firstWhereOrNull((e) {
              return e.ep == ep;
            });
        if (imageFavoritesEp == null) {
          if (page != firstPage) {
            var copy = imageFavorite.copyWith(
              page: firstPage,
              isAutoFavorite: true,
              imageKey: context.reader.images![0],
            );
            // 不是第一页的话, 自动塞一个封面进去
            imageFavoritesEp = ImageFavoritesEp(
              eid,
              ep,
              [copy, imageFavorite],
              epName,
              maxPage,
            );
          } else {
            imageFavoritesEp = ImageFavoritesEp(
              eid,
              ep,
              [imageFavorite],
              epName,
              maxPage,
            );
          }
          imageFavoritesComic.imageFavoritesEp.add(imageFavoritesEp);
        } else {
          if (imageFavoritesEp.eid != eid) {
            // 空字符串说明是从pica导入的, 那我们就手动刷一遍保证一致
            if (imageFavoritesEp.eid == "") {
              imageFavoritesEp.eid == eid;
            } else {
              // 避免多章节漫画源的章节顺序发生变化, 如果情况比较多, 做一个以eid为准更新ep的功能
              showToast(
                message:
                    "The chapter order of the comic may have changed, temporarily not supported for collection"
                        .tl,
                context: context,
              );
              return;
            }
          }
          imageFavoritesEp.imageFavorites.add(imageFavorite);
        }

        ImageFavoriteManager().addOrUpdateOrDelete(imageFavoritesComic);
        showToast(
          message: "Successfully collected".tl,
          context: context,
          seconds: 1,
        );
      }
      update();
    } catch (e, stackTrace) {
      Log.error("Image Favorite", e, stackTrace);
      showToast(message: e.toString(), context: context, seconds: 1);
    }
  }

  Widget buildBottom() {
    var text = "E${context.reader.chapter} : P${context.reader.page}";
    if (context.reader.widget.chapters == null) {
      text = "P${context.reader.page}";
    }

    final buttons = [
      Tooltip(
        message: "Collect the image".tl,
        child: IconButton(
          icon: Icon(isLiked() ? Icons.favorite : Icons.favorite_border),
          onPressed: addImageFavorite,
        ),
      ),
      if (App.isDesktop)
        Tooltip(
          message: "${"Full Screen".tl}(F12)",
          child: IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              context.reader.fullscreen();
            },
          ),
        ),
      if (App.isAndroid)
        Tooltip(
          message: "Screen Rotation".tl,
          child: IconButton(
            icon: () {
              if (rotation == null) {
                return const Icon(Icons.screen_rotation);
              } else if (rotation == false) {
                return const Icon(Icons.screen_lock_portrait);
              } else {
                return const Icon(Icons.screen_lock_landscape);
              }
            }.call(),
            onPressed: () {
              if (rotation == null) {
                setState(() {
                  rotation = false;
                });
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              } else if (rotation == false) {
                setState(() {
                  rotation = true;
                });
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              } else {
                setState(() {
                  rotation = null;
                });
                SystemChrome.setPreferredOrientations(DeviceOrientation.values);
              }
            },
          ),
        ),
      Tooltip(
        message: "Auto Page Turning".tl,
        child: IconButton(
          icon: context.reader.autoPageTurningTimer != null
              ? const Icon(Icons.timer)
              : const Icon(Icons.timer_sharp),
          onPressed: () {
            context.reader.autoPageTurning(
              context.reader.cid,
              context.reader.type,
            );
            update();
          },
        ),
      ),
      if (context.reader.widget.chapters != null)
        Tooltip(
          message: "Chapters".tl,
          child: IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: openChapterDrawer,
          ),
        ),
      Tooltip(
        message: "Save Image".tl,
        child: IconButton(
          icon: const Icon(Icons.download),
          onPressed: saveCurrentImage,
        ),
      ),
      Tooltip(
        message: "Share".tl,
        child: IconButton(icon: const Icon(Icons.share), onPressed: share),
      ),
    ];

    Widget child = SizedBox(
      height: kBottomBarHeight,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => !isReversed
                    ? context.reader.chapter > 1
                          ? context.reader.toPrevChapter()
                          : context.reader.toPage(1)
                    : context.reader.chapter < context.reader.maxChapter
                    ? context.reader.toNextChapter()
                    : context.reader.toPage(context.reader.maxPage),
                icon: const Icon(Icons.first_page),
              ),
              Expanded(child: buildSlider()),
              IconButton.filledTonal(
                onPressed: () => !isReversed
                    ? context.reader.chapter < context.reader.maxChapter
                          ? context.reader.toNextChapter()
                          : context.reader.toPage(context.reader.maxPage)
                    : context.reader.chapter > 1
                    ? context.reader.toPrevChapter()
                    : context.reader.toPage(1),
                icon: const Icon(Icons.last_page),
              ),
              const SizedBox(width: 8),
            ],
          ),
          LayoutBuilder(
            builder: (context, constrains) {
              return Row(
                children: [
                  if ((constrains.maxWidth - buttons.length * 42) > 80)
                    Container(
                      height: 24,
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(text)),
                    ).paddingLeft(16),
                  const Spacer(),
                  ...buttons,
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
      ),
    );

    return BlurEffect(
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.92),
          border: isOpen
              ? Border(
                  top: BorderSide(
                    color: Colors.grey.toOpacity(0.5),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        padding: EdgeInsets.only(bottom: context.padding.bottom),
        child: child,
      ),
    );
  }

  var sliderFocus = FocusNode();

  Widget buildSlider() {
    return CustomSlider(
      focusNode: sliderFocus,
      value: context.reader.page.toDouble(),
      min: 1,
      max: context.reader.maxPage
          .clamp(context.reader.page, 1 << 16)
          .toDouble(),
      reversed: isReversed,
      divisions: (context.reader.maxPage - 1).clamp(2, 1 << 16),
      onChanged: (i) {
        context.reader.toPage(i.toInt());
      },
    );
  }

  Widget buildPageInfoText() {
    var epName =
        context.reader.widget.chapters?.titles.elementAtOrNull(
          context.reader.chapter - 1,
        ) ??
        "E${context.reader.chapter}";
    if (epName.length > 8) {
      epName = "${epName.substring(0, 8)}...";
    }
    var pageText = "${context.reader.page}/${context.reader.maxPage}";
    var text = context.reader.widget.chapters != null
        ? "$epName : $pageText"
        : pageText;

    return Positioned(
      bottom: 13,
      left: 25,
      child: Stack(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = context.colorScheme.onInverseSurface,
            ),
          ),
          Text(text),
        ],
      ),
    );
  }

  Widget buildStatusInfo() {
    if (appdata.settings['enableClockAndBatteryInfoInReader']) {
      return Positioned(
        bottom: 13,
        right: 25,
        child: Row(
          children: [
            _ClockWidget(),
            const SizedBox(width: 10),
            _BatteryWidget(),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void openChapterDrawer() {
    showSideBar(
      context,
      context.reader.widget.chapters!.isGrouped
          ? _GroupedChaptersView(context.reader)
          : _ChaptersView(context.reader),
      width: 400,
    );
  }

  void saveCurrentImage() async {
    var data = await selectImageToData();
    if (data == null) {
      return;
    }
    var fileType = detectFileType(data);
    var filename = "${context.reader.page}${fileType.ext}";
    saveFile(data: data, filename: filename);
  }

  void share() async {
    var data = await selectImageToData();
    if (data == null) {
      return;
    }
    var fileType = detectFileType(data);
    var filename = "${context.reader.page}${fileType.ext}";
    Share.shareFile(data: data, filename: filename, mime: fileType.mime);
  }

  void openSetting() {
    showSideBar(
      context,
      ReaderSettings(
        comicId: context.reader.cid,
        comicSource: context.reader.type.sourceKey,
        onChanged: (key) {
          if (key == "readerMode") {
            context.reader.mode = ReaderMode.fromKey(
              appdata.settings.getReaderSetting(
                context.reader.cid,
                context.reader.type.sourceKey,
                key,
              ),
            );
          }
          if (key == "enableTurnPageByVolumeKey") {
            if (appdata.settings.getReaderSetting(
              context.reader.cid,
              context.reader.type.sourceKey,
              key,
            )) {
              context.reader.handleVolumeEvent();
            } else {
              context.reader.stopVolumeEvent();
            }
          }
          if (key == "quickCollectImage") {
            addDragListener();
          }
          context.reader.update();
        },
      ),
      width: 400,
    );
  }

  Widget buildEpChangeButton() {
    if (context.reader.widget.chapters == null) return const SizedBox();
    switch (showFloatingButtonValue) {
      case 0:
        return Container(
          width: 58,
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            lastValue == 1
                ? Icons.arrow_forward_ios
                : Icons.arrow_back_ios_outlined,
            size: 24,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        );
      case -1:
      case 1:
        return SizedBox(
          width: 58,
          height: 58,
          child: Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: InkWell(
              onTap: () {
                if (showFloatingButtonValue == 1) {
                  context.reader.toNextChapter();
                } else if (showFloatingButtonValue == -1) {
                  context.reader.toPrevChapter();
                }
                setFloatingButton(0);
              },
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Icon(
                  showFloatingButtonValue == 1
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_back_ios_outlined,
                  size: 24,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        );
    }
    return const SizedBox();
  }

  /// If there is only one image on screen, return it.
  ///
  /// If there are multiple images on screen,
  /// show an overlay to let the user select an image.
  ///
  /// The return value is the index of the selected image.
  Future<int?> selectImage() async {
    var reader = context.reader;
    var imageViewController = context.reader._imageViewController;
    if (imageViewController is _GalleryModeState && reader.imagesPerPage == 1) {
      return reader.page - 1;
    } else {
      var location = await _showSelectImageOverlay();
      if (location == null) {
        return null;
      }
      var imageKey = imageViewController!.getImageKeyByOffset(location);
      if (imageKey == null) {
        return null;
      }
      return reader.images!.indexOf(imageKey);
    }
  }

  /// Same as [selectImage], but return the image data.
  Future<Uint8List?> selectImageToData() async {
    var i = await selectImage();
    if (i == null) {
      return null;
    }
    var imageKey = context.reader.images![i];
    if (imageKey.startsWith("file://")) {
      return await File(imageKey.substring(7)).readAsBytes();
    } else {
      return (await CacheManager().findCache(
        "$imageKey@${context.reader.type.sourceKey}@${context.reader.cid}@${context.reader.eid}",
      ))!.readAsBytes();
    }
  }

  Future<Offset?> _showSelectImageOverlay() {
    if (_isOpen) {
      openOrClose();
    }

    var completer = Completer<Offset?>();

    var overlay = Overlay.of(context);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: _SelectImageOverlayContent(
            onTap: (offset) {
              completer.complete(offset);
              entry!.remove();
            },
            onDispose: () {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            },
          ),
        );
      },
    );
    overlay.insert(entry);

    return completer.future;
  }
}

class _BatteryWidget extends StatefulWidget {
  @override
  _BatteryWidgetState createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<_BatteryWidget> {
  late Battery _battery;
  late int _batteryLevel = 100;
  Timer? _timer;
  bool _hasBattery = false;
  BatteryState state = BatteryState.unknown;

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      state = await _battery.batteryState;
      if (_batteryLevel > 0 && state != BatteryState.unknown) {
        setState(() {
          _hasBattery = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _battery.batteryLevel.then((level) {
            if (_batteryLevel != level) {
              setState(() {
                _batteryLevel = level;
              });
            }
          });
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBattery) {
      return const SizedBox.shrink(); //Empty Widget
    }
    return _batteryInfo(_batteryLevel);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _batteryInfo(int batteryLevel) {
    IconData batteryIcon;
    Color batteryColor = context.colorScheme.onSurface;

    if (state == BatteryState.charging) {
      batteryIcon = Icons.battery_charging_full;
    } else if (batteryLevel >= 96) {
      batteryIcon = Icons.battery_full_sharp;
    } else if (batteryLevel >= 84) {
      batteryIcon = Icons.battery_6_bar_sharp;
    } else if (batteryLevel >= 72) {
      batteryIcon = Icons.battery_5_bar_sharp;
    } else if (batteryLevel >= 60) {
      batteryIcon = Icons.battery_4_bar_sharp;
    } else if (batteryLevel >= 48) {
      batteryIcon = Icons.battery_3_bar_sharp;
    } else if (batteryLevel >= 36) {
      batteryIcon = Icons.battery_2_bar_sharp;
    } else if (batteryLevel >= 24) {
      batteryIcon = Icons.battery_1_bar_sharp;
    } else if (batteryLevel >= 12) {
      batteryIcon = Icons.battery_0_bar_sharp;
    } else {
      batteryIcon = Icons.battery_alert_sharp;
      batteryColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          batteryIcon,
          size: 16,
          color: batteryColor,
          // Stroke
          shadows: List.generate(9, (index) {
            if (index == 4) {
              return null;
            }
            double offsetX = (index % 3 - 1) * 0.8;
            double offsetY = ((index / 3).floor() - 1) * 0.8;
            return Shadow(
              color: context.colorScheme.onInverseSurface,
              offset: Offset(offsetX, offsetY),
            );
          }).whereType<Shadow>().toList(),
        ),
        Stack(
          children: [
            Text(
              '$batteryLevel%',
              style: TextStyle(
                fontSize: 14,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4
                  ..color = context.colorScheme.onInverseSurface,
              ),
            ),
            Text('$batteryLevel%'),
          ],
        ),
      ],
    );
  }
}

class _ClockWidget extends StatefulWidget {
  @override
  _ClockWidgetState createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late String _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = _getCurrentTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final time = _getCurrentTime();
      if (_currentTime != time) {
        setState(() {
          _currentTime = time;
        });
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          _currentTime,
          style: TextStyle(
            fontSize: 14,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = context.colorScheme.onInverseSurface,
          ),
        ),
        Text(_currentTime),
      ],
    );
  }
}

class _SelectImageOverlayContent extends StatefulWidget {
  const _SelectImageOverlayContent({
    required this.onTap,
    required this.onDispose,
  });

  final void Function(Offset) onTap;

  final void Function() onDispose;

  @override
  State<_SelectImageOverlayContent> createState() =>
      _SelectImageOverlayContentState();
}

class _SelectImageOverlayContentState
    extends State<_SelectImageOverlayContent> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        widget.onTap(details.globalPosition);
      },
      child: Container(
        color: Colors.black.withAlpha(50),
        child: Align(
          alignment: Alignment(0, -0.8),
          child: Container(
            width: 232,
            height: 42,
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.info_outline),
                const SizedBox(width: 16),
                Text(
                  "Click to select an image".tl,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
