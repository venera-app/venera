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

  bool get isReversed => context.reader.mode == ReaderMode.galleryRightToLeft ||
                       context.reader.mode == ReaderMode.continuousRightToLeft;

  int showFloatingButtonValue = 0;

  var lastValue = 0;

  var fABValue = ValueNotifier<double>(0);

  _ReaderGestureDetectorState? _gestureDetectorState;

  void setFloatingButton(int value) {
    lastValue = showFloatingButtonValue;
    if (value == 0) {
      if (showFloatingButtonValue != 0) {
        showFloatingButtonValue = 0;
        fABValue.value = 0;
        update();
      }
      _gestureDetectorState!.dragListener = null;
    }
    var readerMode = context.reader.mode;
    if (value == 1 && showFloatingButtonValue == 0) {
      showFloatingButtonValue = 1;
      _gestureDetectorState!.dragListener = _DragListener(
        onMove: (offset) {
          if (readerMode == ReaderMode.continuousTopToBottom) {
            fABValue.value -= offset.dy;
          } else if (readerMode == ReaderMode.continuousLeftToRight) {
            fABValue.value -= offset.dx;
          } else if (readerMode == ReaderMode.continuousRightToLeft) {
            fABValue.value += offset.dx;
          }
        },
        onEnd: () {
          if (fABValue.value.abs() > 58 * 3) {
            setState(() {
              showFloatingButtonValue = 0;
            });
            context.reader.toNextChapter();
          }
          fABValue.value = 0;
        },
      );
      update();
    } else if (value == -1 && showFloatingButtonValue == 0) {
      showFloatingButtonValue = -1;
      _gestureDetectorState!.dragListener = _DragListener(
        onMove: (offset) {
          if (readerMode == ReaderMode.continuousTopToBottom) {
            fABValue.value += offset.dy;
          } else if (readerMode == ReaderMode.continuousLeftToRight) {
            fABValue.value += offset.dx;
          } else if (readerMode == ReaderMode.continuousRightToLeft) {
            fABValue.value -= offset.dx;
          }
        },
        onEnd: () {
          if (fABValue.value.abs() > 58 * 3) {
            setState(() {
              showFloatingButtonValue = 0;
            });
            context.reader.toPrevChapter();
          }
          fABValue.value = 0;
        },
      );
      update();
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
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
        Positioned.fill(
          child: widget.child,
        ),
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
          color: context.colorScheme.surface.toOpacity(0.82),
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.toOpacity(0.5),
              width: 0.5,
            ),
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

  Widget buildBottom() {
    var text = "E${context.reader.chapter} : P${context.reader.page}";
    if (context.reader.widget.chapters == null) {
      text = "P${context.reader.page}";
    }

    Widget child = SizedBox(
      height: kBottomBarHeight,
      child: Column(
        children: [
          const SizedBox(
            height: 8,
          ),
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
              Expanded(
                child: buildSlider(),
              ),
              IconButton.filledTonal(
                onPressed: () => !isReversed
                    ? context.reader.chapter < context.reader.maxChapter
                        ? context.reader.toNextChapter()
                        : context.reader.toPage(context.reader.maxPage)
                  : context.reader.chapter > 1
                        ? context.reader.toPrevChapter()
                        : context.reader.toPage(1),
                  icon: const Icon(Icons.last_page)),
              const SizedBox(
                width: 8,
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 16,
              ),
              Container(
                height: 24,
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(text),
                ),
              ),
              const Spacer(),
              if (App.isWindows)
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
                          DeviceOrientation.landscapeRight
                        ]);
                      } else {
                        setState(() {
                          rotation = null;
                        });
                        SystemChrome.setPreferredOrientations(
                            DeviceOrientation.values);
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
                    context.reader.autoPageTurning();
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
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: share,
                ),
              ),
              const SizedBox(width: 4)
            ],
          )
        ],
      ),
    );

    return BlurEffect(
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.82),
          border: Border(
            top: BorderSide(
              color: Colors.grey.toOpacity(0.5),
              width: 0.5,
            ),
          ),
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
      max:
          context.reader.maxPage.clamp(context.reader.page, 1 << 16).toDouble(),
      reversed: isReversed,
      divisions: (context.reader.maxPage - 1).clamp(2, 1 << 16),
      onChanged: (i) {
        context.reader.toPage(i.toInt());
      },
    );
  }

  Widget buildPageInfoText() {
    var epName = context.reader.widget.chapters?.values
            .elementAtOrNull(context.reader.chapter - 1) ??
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
      _ChaptersView(context.reader),
      width: 400,
    );
  }

  Future<Uint8List?> _getCurrentImageData() async {
    var imageKey = context.reader.images![context.reader.page - 1];
    var reader = context.reader;
    if (context.reader.mode.isContinuous) {
      var continuesState =
          context.reader._imageViewController as _ContinuousModeState;
      var imagesOnScreen =
          continuesState.itemPositionsListener.itemPositions.value;
      var images = imagesOnScreen
          .map((e) => context.reader.images![e.index - 1])
          .toList();
      String? selected;
      await showPopUpWidget(
        context,
        PopUpWidgetScaffold(
          title: "Select an image on screen".tl,
          body: GridView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              ImageProvider image;
              var imageKey = images[index];
              if (imageKey.startsWith('file://')) {
                image = FileImage(File(imageKey.replaceFirst("file://", '')));
              } else {
                image = ReaderImageProvider(
                  imageKey,
                  reader.type.comicSource!.key,
                  reader.cid,
                  reader.eid,
                );
              }
              return InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                onTap: () {
                  selected = images[index];
                  App.rootContext.pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  width: double.infinity,
                  height: double.infinity,
                  child: Image(
                    width: double.infinity,
                    height: double.infinity,
                    image: image,
                  ),
                ),
              ).padding(const EdgeInsets.all(8));
            },
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.7,
            ),
          ),
        ),
      );
      if (selected == null) {
        return null;
      } else {
        imageKey = selected!;
      }
    }
    if (imageKey.startsWith("file://")) {
      return await File(imageKey.substring(7)).readAsBytes();
    } else {
      return (await CacheManager().findCache(
              "$imageKey@${context.reader.type.sourceKey}@${context.reader.cid}@${context.reader.eid}"))!
          .readAsBytes();
    }
  }

  void saveCurrentImage() async {
    var data = await _getCurrentImageData();
    if (data == null) {
      return;
    }
    var fileType = detectFileType(data);
    var filename = "${context.reader.page}${fileType.ext}";
    saveFile(data: data, filename: filename);
  }

  void share() async {
    var data = await _getCurrentImageData();
    if (data == null) {
      return;
    }
    var fileType = detectFileType(data);
    var filename = "${context.reader.page}${fileType.ext}";
    Share.shareFile(
      data: data,
      filename: filename,
      mime: fileType.mime,
    );
  }

  void openSetting() {
    showSideBar(
      context,
      ReaderSettings(
        onChanged: (key) {
          if (key == "readerMode") {
            context.reader.mode = ReaderMode.fromKey(appdata.settings[key]);
            App.rootContext.pop();
          }
          if (key == "enableTurnPageByVolumeKey") {
            if (appdata.settings[key]) {
              context.reader.handleVolumeEvent();
            } else {
              context.reader.stopVolumeEvent();
            }
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
        return Container(
          width: 58,
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ValueListenableBuilder(
            valueListenable: fABValue,
            builder: (context, value, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: value.clamp(0, 58 * 3) / 3,
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceTint
                          .toOpacity(0.2),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              );
            },
          ),
        );
    }
    return const SizedBox();
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

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      if (_batteryLevel != -1) {
        setState(() {
          _hasBattery = true;
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            _battery.batteryLevel.then((level) => {
                  if (_batteryLevel != level)
                    {
                      setState(() {
                        _batteryLevel = level;
                      })
                    }
                });
          });
        });
      } else {
        setState(() {
          _hasBattery = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasBattery = false;
      });
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

    if (batteryLevel >= 96) {
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
          shadows: List.generate(
            9,
            (index) {
              if (index == 4) {
                return null;
              }
              double offsetX = (index % 3 - 1) * 0.8;
              double offsetY = ((index / 3).floor() - 1) * 0.8;
              return Shadow(
                color: context.colorScheme.onInverseSurface,
                offset: Offset(offsetX, offsetY),
              );
            },
          ).whereType<Shadow>().toList(),
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

class _ChaptersView extends StatefulWidget {
  const _ChaptersView(this.reader);

  final _ReaderState reader;

  @override
  State<_ChaptersView> createState() => _ChaptersViewState();
}

class _ChaptersViewState extends State<_ChaptersView> {
  bool desc = false;

  @override
  Widget build(BuildContext context) {
    var chapters = widget.reader.widget.chapters!;
    var current = widget.reader.chapter - 1;
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            title: Text("Chapters".tl),
            actions: [
              Tooltip(
                message: "Click to change the order".tl,
                child: TextButton.icon(
                  icon: Icon(
                    !desc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                  ),
                  label: Text(!desc ? "Ascending".tl : "Descending".tl),
                  onPressed: () {
                    setState(() {
                      desc = !desc;
                    });
                  },
                ),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (desc) {
                  index = chapters.length - 1 - index;
                }
                var chapter = chapters.values.elementAt(index);
                return ListTile(
                  shape: Border(
                    left: BorderSide(
                      color: current == index
                          ? context.colorScheme.primary
                          : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  title: Text(
                    chapter,
                    style: current == index
                        ? ts.withColor(context.colorScheme.primary).bold
                        : null,
                  ),
                  onTap: () {
                    widget.reader.toChapter(index + 1);
                    Navigator.of(context).pop();
                  },
                );
              },
              childCount: chapters.length,
            ),
          ),
        ],
      ),
    );
  }
}
