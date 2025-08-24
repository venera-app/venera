library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_memory_info/flutter_memory_info.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:venera/components/components.dart';
import 'package:venera/components/custom_slider.dart';
import 'package:venera/components/window_frame.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/global_state.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/reader_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/network/images.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/clipboard_image.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/file_type.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/translations.dart';
import 'package:venera/utils/volume.dart';
import 'package:window_manager/window_manager.dart';
import 'package:battery_plus/battery_plus.dart';

part 'scaffold.dart';

part 'images.dart';

part 'gesture.dart';

part 'comic_image.dart';

part 'loading.dart';

part 'chapters.dart';

extension _ReaderContext on BuildContext {
  _ReaderState get reader => findAncestorStateOfType<_ReaderState>()!;

  _ReaderScaffoldState get readerScaffold =>
      findAncestorStateOfType<_ReaderScaffoldState>()!;
}

class Reader extends StatefulWidget {
  const Reader({
    super.key,
    required this.type,
    required this.cid,
    required this.name,
    required this.chapters,
    required this.history,
    this.initialPage,
    this.initialChapter,
    this.initialChapterGroup,
    required this.author,
    required this.tags,
  });

  final ComicType type;

  final String author;

  final List<String> tags;

  final String cid;

  final String name;

  final ComicChapters? chapters;

  /// Starts from 1, invalid values equal to 1
  final int? initialPage;

  /// Starts from 1, invalid values equal to 1
  final int? initialChapter;

  /// Starts from 1, invalid values equal to 1
  final int? initialChapterGroup;

  final History history;

  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader>
    with _ReaderLocation, _ReaderWindow, _VolumeListener, _ImagePerPageHandler {
  @override
  void update() {
    setState(() {});
  }

  @override
  int get maxPage {
    if (images == null) {
      return 1;
    }
    if (!showSingleImageOnFirstPage()) {
      return (images!.length / imagesPerPage()).ceil();
    } else {
      return 1 + ((images!.length - 1) / imagesPerPage()).ceil();
    }
  }

  @override
  ComicType get type => widget.type;

  @override
  String get cid => widget.cid;

  String get eid => widget.chapters?.ids.elementAtOrNull(chapter - 1) ?? '0';

  List<String>? images;

  @override
  late ReaderMode mode;

  @override
  bool get isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  History? history;

  @override
  bool isLoading = false;

  var focusNode = FocusNode();

  @override
  void initState() {
    page = widget.initialPage ?? 1;
    if (page < 1) {
      page = 1;
    }
    chapter = widget.initialChapter ?? 1;
    if (chapter < 1) {
      chapter = 1;
    }
    if (widget.initialChapterGroup != null) {
      for (int i = 0; i < (widget.initialChapterGroup! - 1); i++) {
        chapter += widget.chapters!.getGroupByIndex(i).length;
      }
    }
    if (widget.initialPage != null) {
      page = widget.initialPage!;
    }
    // mode = ReaderMode.fromKey(appdata.settings['readerMode']);
    mode = ReaderMode.fromKey(appdata.settings.getReaderSetting(cid, type.sourceKey, 'readerMode'));
    history = widget.history;
    if (!appdata.settings.getReaderSetting(cid, type.sourceKey, 'showSystemStatusBar')) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
    if (appdata.settings.getReaderSetting(cid, type.sourceKey, 'enableTurnPageByVolumeKey')) {
      handleVolumeEvent();
    }
    setImageCacheSize();
    Future.delayed(const Duration(milliseconds: 200), () {
      LocalFavoritesManager().onRead(cid, type);
    });
    super.initState();
  }

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      initImagesPerPage(widget.initialPage ?? 1);
      _isInitialized = true;
    } else {
      // For orientation changed
      _checkImagesPerPageChange();
    }
    initReaderWindow();
  }

  void setImageCacheSize() async {
    var availableRAM = await MemoryInfo.getFreePhysicalMemorySize();
    if (availableRAM == null) return;
    int maxImageCacheSize;
    if (availableRAM < 1 << 30) {
      maxImageCacheSize = 100 << 20;
    } else if (availableRAM < 2 << 30) {
      maxImageCacheSize = 200 << 20;
    } else if (availableRAM < 4 << 30) {
      maxImageCacheSize = 300 << 20;
    } else {
      maxImageCacheSize = 500 << 20;
    }
    Log.info("Reader",
        "Detect available RAM: $availableRAM, set image cache size to $maxImageCacheSize");
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxImageCacheSize;
  }

  @override
  void dispose() {
    if (isFullscreen) {
      fullscreen();
    }
    autoPageTurningTimer?.cancel();
    focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    stopVolumeEvent();
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
    disposeReaderWindow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _checkImagesPerPageChange();
    return KeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: Overlay(
        initialEntries: [
          OverlayEntry(builder: (context) {
            return _ReaderScaffold(
              child: _ReaderGestureDetector(
                child: _ReaderImages(key: Key(chapter.toString())),
              ),
            );
          })
        ],
      ),
    );
  }

  void onKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.f12 && event is KeyUpEvent) {
      fullscreen();
    }
    _imageViewController?.handleKeyEvent(event);
  }

  @override
  int get maxChapter => widget.chapters?.length ?? 1;

  @override
  void onPageChanged() {
    updateHistory();
  }

  /// Prevent multiple history updates in a short time.
  /// `HistoryManager().addHistoryAsync` is a high-cost operation because it creates a new isolate.
  Timer? _updateHistoryTimer;

  void updateHistory() {
    if (history != null) {
      if (page == maxPage) {
        /// Record the last image of chapter
        history!.page = images?.length ?? 1;
      } else {
        /// Record the first image of the page
        if (!showSingleImageOnFirstPage() || imagesPerPage() == 1) {
          history!.page = (page - 1) * imagesPerPage() + 1;
        } else {
          if (page == 1) {
            history!.page = 1;
          } else {
            history!.page = (page - 2) * imagesPerPage() + 2;
          }
        }
      }
      history!.maxPage = images?.length ?? 1;
      if (widget.chapters?.isGrouped ?? false) {
        int g = 0;
        int c = chapter;
        while (c > widget.chapters!.getGroupByIndex(g).length) {
          c -= widget.chapters!.getGroupByIndex(g).length;
          g++;
        }
        history!.readEpisode.add('${g + 1}-$c');
        history!.ep = c;
        history!.group = g + 1;
      } else {
        history!.readEpisode.add(chapter.toString());
        history!.ep = chapter;
      }
      history!.time = DateTime.now();
      _updateHistoryTimer?.cancel();
      _updateHistoryTimer = Timer(const Duration(seconds: 1), () {
        HistoryManager().addHistoryAsync(history!);
        _updateHistoryTimer = null;
      });
    }
  }

  bool get isFirstChapterOfGroup {
    if (widget.chapters?.isGrouped ?? false) {
      int c = chapter - 1;
      int g = 1;
      while (c > 0) {
        c -= widget.chapters!.getGroupByIndex(g - 1).length;
        g++;
      }
      if (c == 0) {
        return true;
      } else {
        return false;
      }
    }
    return chapter == 1;
  }

  bool get isLastChapterOfGroup {
    if (widget.chapters?.isGrouped ?? false) {
      int c = chapter;
      int g = 1;
      while (c > 0) {
        c -= widget.chapters!.getGroupByIndex(g - 1).length;
        g++;
      }
      if (c == 0) {
        return true;
      } else {
        return false;
      }
    }
    return chapter == maxChapter;
  }

  /// Get the size of the reader.
  /// The size is not always the same as the size of the screen.
  Size get size {
    var renderBox = context.findRenderObject() as RenderBox;
    return renderBox.size;
  }
}

abstract mixin class _ImagePerPageHandler {
  late int _lastImagesPerPage;

  late bool _lastOrientation;

  bool get isPortrait;

  int get page;

  set page(int value);

  ReaderMode get mode;

  String get cid;

  ComicType get type;

  void initImagesPerPage(int initialPage) {
    _lastImagesPerPage = imagesPerPage();
    _lastOrientation = isPortrait;
    if (imagesPerPage() != 1) {
      if (showSingleImageOnFirstPage()) {
        page = ((initialPage - 1) / imagesPerPage()).ceil() + 1;
      } else {
        page = (initialPage / imagesPerPage()).ceil();
      }
    }
  }

  bool showSingleImageOnFirstPage() =>
      appdata.settings.getReaderSetting(cid, type.sourceKey, 'showSingleImageOnFirstPage');

  /// The number of images displayed on one screen
  int imagesPerPage() {
    if (mode.isContinuous) return 1;
    if (isPortrait) {
      return appdata.settings.getReaderSetting(cid, type.sourceKey, 'readerScreenPicNumberForPortrait') ?? 1;
    } else {
      return appdata.settings.getReaderSetting(cid, type.sourceKey, 'readerScreenPicNumberForLandscape') ?? 1;
    }
  }

  /// Check if the number of images per page has changed
  void _checkImagesPerPageChange() {
    int currentImagesPerPage = imagesPerPage();
    bool currentOrientation = isPortrait;

    if (_lastImagesPerPage != currentImagesPerPage || _lastOrientation != currentOrientation) {
      _adjustPageForImagesPerPageChange(_lastImagesPerPage, currentImagesPerPage);
      _lastImagesPerPage = currentImagesPerPage;
      _lastOrientation = currentOrientation;
    }
  }

  /// Adjust the page number when the number of images per page changes
  void _adjustPageForImagesPerPageChange(int oldImagesPerPage, int newImagesPerPage) {
    int previousImageIndex = 1;
    if (!showSingleImageOnFirstPage() || oldImagesPerPage == 1) {
      previousImageIndex = (page - 1) * oldImagesPerPage + 1;
    } else {
      if (page == 1) {
        previousImageIndex = 1;
      } else {
        previousImageIndex = (page - 2) * oldImagesPerPage + 2;
      }
    }

    int newPage;
    if (newImagesPerPage != 1) {
      if (showSingleImageOnFirstPage()) {
        newPage = ((previousImageIndex - 1) / newImagesPerPage).ceil() + 1;
      } else {
        newPage = (previousImageIndex / newImagesPerPage).ceil();
      }
    } else {
      newPage = previousImageIndex;
    }

    page = newPage>0 ? newPage : 1;
  }
}

abstract mixin class _VolumeListener {
  bool toNextPage();

  bool toPrevPage();

  bool toNextChapter();

  bool toPrevChapter();

  VolumeListener? volumeListener;

  void onDown() {
    if (!toNextPage()) {
      toNextChapter();
    }
  }

  void onUp() {
    if (!toPrevPage()) {
      toPrevChapter();
    }
  }

  void handleVolumeEvent() {
    if (!App.isAndroid) {
      // Currently only support Android
      return;
    }
    if (volumeListener != null) {
      volumeListener?.cancel();
    }
    volumeListener = VolumeListener(
      onDown: onDown,
      onUp: onUp,
    )..listen();
  }

  void stopVolumeEvent() {
    if (volumeListener != null) {
      volumeListener?.cancel();
      volumeListener = null;
    }
  }
}

abstract mixin class _ReaderLocation {
  int _page = 1;

  int get page => _page;

  set page(int value) {
    _page = value;
    onPageChanged();
  }

  int chapter = 1;

  int get maxPage;

  int get maxChapter;

  bool get isLoading;

  String get cid;

  ComicType get type;

  void update();

  bool enablePageAnimation(String cid, ComicType type) => appdata.settings.getReaderSetting(cid, type.sourceKey, 'enablePageAnimation');

  _ImageViewController? _imageViewController;

  void onPageChanged();

  void setPage(int page) {
    // Prevent page change during animation
    if (_animationCount > 0) {
      return;
    }
    this.page = page;
  }

  bool _validatePage(int page) {
    return page >= 1 && page <= maxPage;
  }

  /// Returns true if the page is changed
  bool toNextPage() {
    return toPage(page + 1);
  }

  /// Returns true if the page is changed
  bool toPrevPage() {
    return toPage(page - 1);
  }

  int _animationCount = 0;

  bool toPage(int page) {
    if (_validatePage(page)) {
      if (page == this.page && page != 1 && page != maxPage) {
        return false;
      }
      this.page = page;
      update();
      if (enablePageAnimation(cid, type)) {
        _animationCount++;
        _imageViewController!.animateToPage(page).then((_) {
          _animationCount--;
        });
      } else {
        _imageViewController!.toPage(page);
      }
      return true;
    }
    return false;
  }

  bool _validateChapter(int chapter) {
    return chapter >= 1 && chapter <= maxChapter;
  }

  /// Returns true if the chapter is changed
  bool toNextChapter() {
    return toChapter(chapter + 1);
  }

  /// Returns true if the chapter is changed
  bool toPrevChapter() {
    return toChapter(chapter - 1);
  }

  bool toChapter(int c) {
    if (_validateChapter(c) && !isLoading) {
      chapter = c;
      page = 1;
      update();
      return true;
    }
    return false;
  }

  Timer? autoPageTurningTimer;

  void autoPageTurning(String cid, ComicType type) {
    if (autoPageTurningTimer != null) {
      autoPageTurningTimer!.cancel();
      autoPageTurningTimer = null;
    } else {
      int interval = appdata.settings.getReaderSetting(cid, type.sourceKey, 'autoPageTurningInterval');
      autoPageTurningTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (page == maxPage) {
          autoPageTurningTimer!.cancel();
        }
        toNextPage();
      });
    }
  }
}

mixin class _ReaderWindow {
  bool isFullscreen = false;

  late WindowFrameController windowFrame;

  bool _isInit = false;

  void initReaderWindow() {
    if (!App.isDesktop || _isInit) return;
    windowFrame = WindowFrame.of(App.rootContext);
    windowFrame.addCloseListener(onWindowClose);
    _isInit = true;
  }

  void fullscreen() async {
    if (!App.isDesktop) return;
    await windowManager.hide();
    await windowManager.setFullScreen(!isFullscreen);
    await windowManager.show();
    isFullscreen = !isFullscreen;
    WindowFrame.of(App.rootContext).setWindowFrame(!isFullscreen);
  }

  bool onWindowClose() {
    if (Navigator.of(App.rootContext).canPop()) {
      Navigator.of(App.rootContext).pop();
      return false;
    } else {
      return true;
    }
  }

  void disposeReaderWindow() {
    if (!App.isDesktop) return;
    windowFrame.removeCloseListener(onWindowClose);
  }
}

enum ReaderMode {
  galleryLeftToRight('galleryLeftToRight'),
  galleryRightToLeft('galleryRightToLeft'),
  galleryTopToBottom('galleryTopToBottom'),
  continuousTopToBottom('continuousTopToBottom'),
  continuousLeftToRight('continuousLeftToRight'),
  continuousRightToLeft('continuousRightToLeft');

  final String key;

  bool get isGallery => key.startsWith('gallery');

  bool get isContinuous => key.startsWith('continuous');

  const ReaderMode(this.key);

  static ReaderMode fromKey(String key) {
    for (var mode in values) {
      if (mode.key == key) {
        return mode;
      }
    }
    return galleryLeftToRight;
  }
}

abstract interface class _ImageViewController {
  void toPage(int page);

  Future<void> animateToPage(int page);

  void handleDoubleTap(Offset location);

  void handleLongPressDown(Offset location);

  void handleLongPressUp(Offset location);

  void handleKeyEvent(KeyEvent event);

  /// Returns true if the event is handled.
  bool handleOnTap(Offset location);

  Future<Uint8List?> getImageByOffset(Offset offset);

  String? getImageKeyByOffset(Offset offset);
}
