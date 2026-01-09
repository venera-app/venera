part of 'components.dart';

class SmoothCustomScrollView extends StatelessWidget {
  const SmoothCustomScrollView(
      {super.key, required this.slivers, this.controller});

  final ScrollController? controller;

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return SmoothScrollProvider(
      controller: controller,
      builder: (context, controller, physics) {
        return CustomScrollView(
          controller: controller,
          physics: physics,
          slivers: [
            ...slivers,
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: context.padding.bottom,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SmoothScrollProvider extends StatefulWidget {
  const SmoothScrollProvider(
      {super.key, this.controller, required this.builder});

  final ScrollController? controller;

  final Widget Function(BuildContext, ScrollController, ScrollPhysics) builder;

  static bool get isMouseScroll => _SmoothScrollProviderState._isMouseScroll;

  @override
  State<SmoothScrollProvider> createState() => _SmoothScrollProviderState();
}

class _SmoothScrollProviderState extends State<SmoothScrollProvider> {
  late final ScrollController _controller;

  double? _futurePosition;

  ScrollDirection _lastUserScrollDirection = ScrollDirection.idle;
  bool _isSnappingToPage = false;

  static bool _isMouseScroll = App.isDesktop;

  late int id;

  static int _id = 0;

  var activeChildren = <int>{};

  ScrollState? parent;

  @override
  void initState() {
    _controller = widget.controller ?? ScrollController();
    super.initState();
    id = _id;
    _id++;
  }

  @override
  void didChangeDependencies() {
    parent = ScrollState.maybeOf(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    parent?.onChildInactive(id);
    super.dispose();
  }

  double _pageFraction() {
    final value = appdata.settings['inkScrollPageFraction'];
    if (value is num) {
      return value.toDouble().clamp(0.1, 1.0);
    }
    return 0.9;
  }

  void _snapToPageIfNeeded() {
    if (_isSnappingToPage) return;
    if (!_controller.hasClients) return;

    final position = _controller.position;
    final viewportHeight = position.viewportDimension;
    if (viewportHeight <= 0) return;

    final pageSize = viewportHeight * _pageFraction();
    if (pageSize <= 0) return;

    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    final pixels = position.pixels.clamp(min, max);

    final relative = (pixels - min) / pageSize;
    final targetIndex = switch (_lastUserScrollDirection) {
      ScrollDirection.reverse => relative.ceil(),
      ScrollDirection.forward => relative.floor(),
      _ => relative.round(),
    };

    final target = (min + targetIndex * pageSize).clamp(min, max);
    if ((target - position.pixels).abs() < 0.5) return;

    _isSnappingToPage = true;
    _futurePosition = null;
    _controller.jumpTo(target);
    _isSnappingToPage = false;
  }

  @override
  Widget build(BuildContext context) {
    final disableInertialScrolling =
        appdata.settings['disableInertialScrolling'] as bool;
    
    if (App.isMacOS) {
      return widget.builder(
        context,
        _controller,
        disableInertialScrolling
            ? const NoInertialScrollPhysics()
            : const BouncingScrollPhysics(),
      );
    }
    var child = Listener(
      onPointerDown: (event) {
        _futurePosition = null;
        if (_isMouseScroll) {
          setState(() {
            _isMouseScroll = false;
          });
        }
      },
      onPointerSignal: (pointerSignal) {
        if (activeChildren.isNotEmpty) {
          return;
        }
        if (pointerSignal is PointerScrollEvent) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            return;
          }
          if (pointerSignal.kind == PointerDeviceKind.mouse &&
              !_isMouseScroll) {
            setState(() {
              _isMouseScroll = true;
            });
          }
          if (!_isMouseScroll) return;
          
          // If disabling inertial scrolling, jump by page size.
          if (disableInertialScrolling) {
            if (!_controller.hasClients) return;
            var currentLocation = _controller.position.pixels;
            var viewportHeight = _controller.position.viewportDimension;
            var scrollDelta = pointerSignal.scrollDelta.dy;

            if (viewportHeight <= 0) return;
            final pageSize = viewportHeight * _pageFraction();
            
            double targetPosition;
            if (scrollDelta > 0) {
              targetPosition = (currentLocation + pageSize).clamp(
                _controller.position.minScrollExtent,
                _controller.position.maxScrollExtent,
              );
            } else {
              targetPosition = (currentLocation - pageSize).clamp(
                _controller.position.minScrollExtent,
                _controller.position.maxScrollExtent,
              );
            }
            
            if (targetPosition != currentLocation) {
              _futurePosition = null;
              _controller.jumpTo(targetPosition);
            }
            return;
          }
          
          var currentLocation = _controller.position.pixels;
          var old = _futurePosition;
          _futurePosition ??= currentLocation;
          double k = (_futurePosition! - currentLocation).abs() / 1600 + 1;
          _futurePosition = _futurePosition! + pointerSignal.scrollDelta.dy * k;
          var beforeOffset = (_futurePosition! - currentLocation).abs();
          _futurePosition = _futurePosition!.clamp(
            _controller.position.minScrollExtent,
            _controller.position.maxScrollExtent,
          );
          var afterOffset = (_futurePosition! - currentLocation).abs();
          if (_futurePosition == old) return;
          var target = _futurePosition!;
          var duration = _fastAnimationDuration;
          if (afterOffset < beforeOffset) {
            duration = duration * (afterOffset / beforeOffset);
            if (duration < Duration(milliseconds: 10)) {
              duration = Duration(milliseconds: 10);
            }
          }
          _controller
              .animateTo(
            _futurePosition!,
            duration: duration,
            curve: Curves.linear,
          )
              .then((_) {
            var current = _controller.position.pixels;
            if (current == target && current == _futurePosition) {
              _futurePosition = null;
            }
          });
        }
      },
      child: ScrollState._(
        controller: _controller,
        onChildActive: (id) {
          activeChildren.add(id);
        },
        onChildInactive: (id) {
          activeChildren.remove(id);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!disableInertialScrolling) return false;
            // Mouse wheel paging is handled in onPointerSignal; this mainly covers Android touch dragging.
            if (_isMouseScroll) return false;
            if (activeChildren.isNotEmpty) return false;
            if (notification.depth != 0) return false;

            if (notification is UserScrollNotification) {
              _lastUserScrollDirection = notification.direction;
            }

            if (notification is ScrollEndNotification) {
              _snapToPageIfNeeded();
            }
            return false;
          },
          child: widget.builder(
            context,
            _controller,
            _isMouseScroll
                ? const NeverScrollableScrollPhysics()
                : (disableInertialScrolling
                    ? const NoInertialScrollPhysics()
                    : const BouncingScrollPhysics()),
          ),
        ),
      ),
    );

    if (parent != null) {
      return MouseRegion(
        onEnter: (_) {
          parent!.onChildActive(id);
        },
        onExit: (_) {
          parent!.onChildInactive(id);
        },
        child: child,
      );
    }

    return child;
  }
}

class ScrollState extends InheritedWidget {
  const ScrollState._({
    required this.controller,
    required super.child,
    required this.onChildActive,
    required this.onChildInactive,
  });

  final ScrollController controller;

  final void Function(int id) onChildActive;

  final void Function(int id) onChildInactive;

  static ScrollState of(BuildContext context) {
    final ScrollState? provider =
        context.dependOnInheritedWidgetOfExactType<ScrollState>();
    return provider!;
  }

  static ScrollState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScrollState>();
  }

  @override
  bool updateShouldNotify(ScrollState oldWidget) {
    return oldWidget.controller != controller;
  }
}

/// 禁用拖拽释放后的 ballistic（惯性/回弹）动画。
///
/// 适用于墨水屏等需要“停下即停下”的场景。
class NoInertialScrollPhysics extends ScrollPhysics {
  const NoInertialScrollPhysics({super.parent});

  @override
  NoInertialScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NoInertialScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // If we're out of range and not headed back in range, defer to the parent
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    return null;
  }
}

class AppScrollBar extends StatefulWidget {
  const AppScrollBar({
    super.key,
    required this.controller,
    required this.child,
    this.topPadding = 0,
  });

  final ScrollController controller;

  final Widget child;

  final double topPadding;

  @override
  State<AppScrollBar> createState() => _AppScrollBarState();
}

class _AppScrollBarState extends State<AppScrollBar> {
  late final ScrollController _scrollController;

  double minExtent = 0;
  double maxExtent = 0;
  double position = 0;

  double viewHeight = 0;

  final _scrollIndicatorSize = App.isDesktop ? 36.0 : 54.0;

  late final VerticalDragGestureRecognizer _dragGestureRecognizer;

  bool _isVisible = false;
  Timer? _hideTimer;
  static const _hideDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller;
    _scrollController.addListener(onChanged);
    Future.microtask(onChanged);
    _dragGestureRecognizer = VerticalDragGestureRecognizer()
      ..onUpdate = onUpdate
      ..onStart = (_) {
        _showScrollbar();
      }
      ..onEnd = (_) {
        _scheduleHide();
      };
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.removeListener(onChanged);
    _dragGestureRecognizer.dispose();
    super.dispose();
  }

  void _showScrollbar() {
    if (!_isVisible && mounted) {
      setState(() {
        _isVisible = true;
      });
    }
    _hideTimer?.cancel();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDuration, () {
      if (mounted && _isVisible) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void onUpdate(DragUpdateDetails details) {
    if (maxExtent - minExtent <= 0 ||
        viewHeight == 0 ||
        details.primaryDelta == null) {
      return;
    }
    var offset = details.primaryDelta!;
    var positionOffset =
        offset / (viewHeight - _scrollIndicatorSize) * (maxExtent - minExtent);
    _scrollController.jumpTo((position + positionOffset).clamp(
      minExtent,
      maxExtent,
    ));
  }

  void onChanged() {
    if (_scrollController.positions.isEmpty) return;
    var position = _scrollController.position;

    bool hasChanged = false;
    if (position.minScrollExtent != minExtent ||
        position.maxScrollExtent != maxExtent ||
        position.pixels != this.position) {
      hasChanged = true;
      minExtent = position.minScrollExtent;
      maxExtent = position.maxScrollExtent;
      this.position = position.pixels;
    }

    if (hasChanged) {
      _showScrollbar();
      _scheduleHide();
    }

    if (hasChanged && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        var scrollHeight = (maxExtent - minExtent);
        var height = constrains.maxHeight - widget.topPadding;
        viewHeight = height;
        var top = scrollHeight == 0
            ? 0.0
            : (position - minExtent) /
                scrollHeight *
                (height - _scrollIndicatorSize);
        return Stack(
          children: [
            Positioned.fill(
              child: widget.child,
            ),
            Positioned(
              top: top + widget.topPadding,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _showScrollbar(),
                  onExit: (_) => _scheduleHide(),
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      _dragGestureRecognizer.addPointer(event);
                    },
                    child: SizedBox(
                      width: _scrollIndicatorSize / 2,
                      height: _scrollIndicatorSize,
                      child: CustomPaint(
                        painter: _ScrollIndicatorPainter(
                          backgroundColor: context.colorScheme.surface,
                          shadowColor: context.colorScheme.shadow,
                        ),
                        child: Column(
                          children: [
                            const Spacer(),
                            Icon(Icons.arrow_drop_up, size: 18),
                            Icon(Icons.arrow_drop_down, size: 18),
                            const Spacer(),
                          ],
                        ).paddingLeft(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrollIndicatorPainter extends CustomPainter {
  final Color backgroundColor;

  final Color shadowColor;

  const _ScrollIndicatorPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
      );
    canvas.drawShadow(path, shadowColor, 2, true);
    var backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
      );
    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ScrollIndicatorPainter ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
