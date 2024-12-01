part of 'reader.dart';

class _ReaderGestureDetector extends StatefulWidget {
  const _ReaderGestureDetector({required this.child});

  final Widget child;

  @override
  State<_ReaderGestureDetector> createState() => _ReaderGestureDetectorState();
}

class _ReaderGestureDetectorState extends State<_ReaderGestureDetector> {
  late TapGestureRecognizer _tapGestureRecognizer;

  static const _kDoubleTapMaxTime = Duration(milliseconds: 200);

  static const _kLongPressMinTime = Duration(milliseconds: 250);

  static const _kDoubleTapMaxDistanceSquared = 20.0 * 20.0;

  static const _kTapToTurnPagePercent = 0.3;

  _DragListener? dragListener;

  int fingers = 0;

  @override
  void initState() {
    _tapGestureRecognizer = TapGestureRecognizer()
      ..onTapUp = onTapUp
      ..onSecondaryTapUp = (details) {
        onSecondaryTapUp(details.globalPosition);
      };
    super.initState();
    context.readerScaffold._gestureDetectorState = this;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        fingers++;
        _lastTapPointer = event.pointer;
        _lastTapMoveDistance = Offset.zero;
        _tapGestureRecognizer.addPointer(event);
        if(_dragInProgress) {
          dragListener?.onEnd?.call();
          _dragInProgress = false;
        }
        Future.delayed(_kLongPressMinTime, () {
          if (_lastTapPointer == event.pointer && fingers == 1) {
            if(_lastTapMoveDistance!.distanceSquared < 20.0 * 20.0) {
              onLongPressedDown(event.position);
              _longPressInProgress = true;
            } else {
              _dragInProgress = true;
              dragListener?.onStart?.call(event.position);
              dragListener?.onMove?.call(_lastTapMoveDistance!);
            }
          }
        });
      },
      onPointerMove: (event) {
        if (event.pointer == _lastTapPointer) {
          _lastTapMoveDistance = event.delta + _lastTapMoveDistance!;
        }
        if(_dragInProgress) {
          dragListener?.onMove?.call(event.delta);
        }
      },
      onPointerUp: (event) {
        fingers--;
        if (_longPressInProgress) {
          onLongPressedUp(event.position);
        }
        if(_dragInProgress) {
          dragListener?.onEnd?.call();
          _dragInProgress = false;
        }
        _lastTapPointer = null;
        _lastTapMoveDistance = null;
      },
      onPointerCancel: (event) {
        fingers--;
        if (_longPressInProgress) {
          onLongPressedUp(event.position);
        }
        if(_dragInProgress) {
          dragListener?.onEnd?.call();
          _dragInProgress = false;
        }
        _lastTapPointer = null;
        _lastTapMoveDistance = null;
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          onMouseWheel(event.scrollDelta.dy > 0);
        }
      },
      child: widget.child,
    );
  }

  void onMouseWheel(bool forward) {
    if (HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    if (context.reader.mode.key.startsWith('gallery')) {
      if (forward) {
        if (!context.reader.toNextPage()) {
          context.reader.toNextChapter();
        }
      } else {
        if (!context.reader.toPrevPage()) {
          context.reader.toPrevChapter();
        }
      }
    }
  }

  TapUpDetails? _previousEvent;

  int? _lastTapPointer;

  Offset? _lastTapMoveDistance;

  bool _longPressInProgress = false;

  bool _dragInProgress = false;

  void onTapUp(TapUpDetails event) {
    if (_longPressInProgress) {
      _longPressInProgress = false;
      return;
    }
    final location = event.globalPosition;
    final previousLocation = _previousEvent?.globalPosition;
    if (previousLocation != null) {
      if ((location - previousLocation).distanceSquared <
          _kDoubleTapMaxDistanceSquared) {
        onDoubleTap(location);
        _previousEvent = null;
        return;
      } else {
        onTap(previousLocation);
      }
    }
    _previousEvent = event;
    Future.delayed(_kDoubleTapMaxTime, () {
      if (_previousEvent == event) {
        onTap(location);
        _previousEvent = null;
      }
    });
  }

  void onTap(Offset location) {
    if (context.readerScaffold.isOpen) {
      context.readerScaffold.openOrClose();
    } else {
      if (appdata.settings['enableTapToTurnPages']) {
        bool isLeft = false, isRight = false, isTop = false, isBottom = false;
        final width = context.width;
        final height = context.height;
        final x = location.dx;
        final y = location.dy;
        if (x < width * _kTapToTurnPagePercent) {
          isLeft = true;
        } else if (x > width * (1 - _kTapToTurnPagePercent)) {
          isRight = true;
        }
        if (y < height * _kTapToTurnPagePercent) {
          isTop = true;
        } else if (y > height * (1 - _kTapToTurnPagePercent)) {
          isBottom = true;
        }
        bool isCenter = false;
        switch (context.reader.mode) {
          case ReaderMode.galleryLeftToRight:
          case ReaderMode.continuousLeftToRight:
            if (isLeft) {
              context.reader.toPrevPage();
            } else if (isRight) {
              context.reader.toNextPage();
            } else {
              isCenter = true;
            }
          case ReaderMode.galleryRightToLeft:
          case ReaderMode.continuousRightToLeft:
            if (isLeft) {
              context.reader.toNextPage();
            } else if (isRight) {
              context.reader.toPrevPage();
            } else {
              isCenter = true;
            }
          case ReaderMode.galleryTopToBottom:
          case ReaderMode.continuousTopToBottom:
            if (isTop) {
              context.reader.toPrevPage();
            } else if (isBottom) {
              context.reader.toNextPage();
            } else {
              isCenter = true;
            }
        }
        if (!isCenter) {
          return;
        }
      }
      context.readerScaffold.openOrClose();
    }
  }

  void onDoubleTap(Offset location) {
    context.reader._imageViewController?.handleDoubleTap(location);
  }

  void onSecondaryTapUp(Offset location) {
    showMenuX(
      context,
      location,
      [
        MenuEntry(
          icon: Icons.settings,
          text: "Settings".tl,
          onClick: () {
            context.readerScaffold.openSetting();
          },
        ),
        MenuEntry(
          icon: Icons.menu,
          text: "Chapters".tl,
          onClick: () {
            context.readerScaffold.openChapterDrawer();
          },
        ),
        MenuEntry(
          icon: Icons.fullscreen,
          text: "Fullscreen".tl,
          onClick: () {
            context.reader.fullscreen();
          },
        ),
        MenuEntry(
          icon: Icons.exit_to_app,
          text: "Exit".tl,
          onClick: () {
            context.pop();
          },
        ),
      ],
    );
  }

  void onLongPressedUp(Offset location) {
    context.reader._imageViewController?.handleLongPressUp(location);
  }

  void onLongPressedDown(Offset location) {
    context.reader._imageViewController?.handleLongPressDown(location);
  }
}

class _DragListener {
  void Function(Offset point)? onStart;
  void Function(Offset offset)? onMove;
  void Function()? onEnd;

  _DragListener({this.onStart, this.onMove, this.onEnd});
}