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
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/reader_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/file_type.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
import 'package:venera/utils/volume.dart';
import 'package:window_manager/window_manager.dart';
import 'package:battery_plus/battery_plus.dart';

part 'scaffold.dart';
part 'images.dart';
part 'gesture.dart';
part 'comic_image.dart';

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
  });

  final ComicType type;

  final String cid;

  final String name;

  /// key: Chapter ID, value: Chapter Name
  /// null if the comic is a gallery
  final Map<String, String>? chapters;

  /// Starts from 1, invalid values equal to 1
  final int? initialPage;

  /// Starts from 1, invalid values equal to 1
  final int? initialChapter;

  final History history;

  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> with _ReaderLocation, _ReaderWindow {
  @override
  void update() {
    setState(() {});
  }

  @override
  int get maxPage =>
      ((images?.length ?? 1) + imagesPerPage - 1) ~/ imagesPerPage;

  ComicType get type => widget.type;

  String get cid => widget.cid;

  String get eid => widget.chapters?.keys.elementAt(chapter - 1) ?? '0';

  List<String>? images;

  late ReaderMode mode;

  int get imagesPerPage => appdata.settings['readerScreenPicNumber'] ?? 1;

  int _lastImagesPerPage = appdata.settings['readerScreenPicNumber'] ?? 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkImagesPerPageChange();
  }

  void _checkImagesPerPageChange() {
    int currentImagesPerPage = imagesPerPage;
    if (_lastImagesPerPage != currentImagesPerPage) {
      _adjustPageForImagesPerPageChange(_lastImagesPerPage, currentImagesPerPage);
      _lastImagesPerPage = currentImagesPerPage;
    }
  }

  void _adjustPageForImagesPerPageChange(int oldImagesPerPage, int newImagesPerPage) {
    int previousImageIndex = (page - 1) * oldImagesPerPage;
    int newPage = (previousImageIndex ~/ newImagesPerPage) + 1;
    page = newPage;
  }

  History? history;

  @override
  bool isLoading = false;

  var focusNode = FocusNode();

  VolumeListener? volumeListener;

  @override
  void initState() {
    page = widget.initialPage ?? 1;
    chapter = widget.initialChapter ?? 1;
    mode = ReaderMode.fromKey(appdata.settings['readerMode']);
    history = widget.history;
    Future.microtask(() {
      updateHistory();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    if(appdata.settings['enableTurnPageByVolumeKey']) {
      handleVolumeEvent();
    }
    setImageCacheSize();
    super.initState();
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
    Log.info("Reader", "Detect available RAM: $availableRAM, set image cache size to $maxImageCacheSize");
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxImageCacheSize;
  }

  @override
  void dispose() {
    autoPageTurningTimer?.cancel();
    focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    stopVolumeEvent();
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _checkImagesPerPageChange();
    return KeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: _ReaderScaffold(
        child: _ReaderGestureDetector(
          child: _ReaderImages(key: Key(chapter.toString())),
        ),
      ),
    );
  }

  void onKeyEvent(KeyEvent event) {
    _imageViewController?.handleKeyEvent(event);
  }

  @override
  int get maxChapter => widget.chapters?.length ?? 1;

  @override
  void onPageChanged() {
    updateHistory();
  }

  void updateHistory() {
    if(history != null) {
      history!.page = page;
      history!.ep = chapter;
      history!.readEpisode.add(chapter);
      HistoryManager().addHistory(history!);
    }
  }

  void handleVolumeEvent() {
    if(!App.isAndroid) {
      // Currently only support Android
      return;
    }
    if(volumeListener != null) {
      volumeListener?.cancel();
    }
    volumeListener = VolumeListener(
      onDown: () {
        toNextPage();
      },
      onUp: () {
        toPrevPage();
      },
    )..listen();
  }

  void stopVolumeEvent() {
    if(volumeListener != null) {
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

  void update();

  bool get enablePageAnimation => appdata.settings['enablePageAnimation'];

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
      if (page == this.page) {
        if(!(chapter == 1 && page == 1) && !(chapter == maxChapter && page == maxPage)) {
          return false;
        }
      }
      this.page = page;
      update();
      if (enablePageAnimation) {
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

  void autoPageTurning() {
    if (autoPageTurningTimer != null) {
      autoPageTurningTimer!.cancel();
      autoPageTurningTimer = null;
    } else {
      int interval = appdata.settings['autoPageTurningInterval'];
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

  void fullscreen() {
    windowManager.setFullScreen(!isFullscreen);
    isFullscreen = !isFullscreen;
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
}
