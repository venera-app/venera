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

  @override
  Widget build(BuildContext context) {
    if (App.isMacOS) {
      return widget.builder(
        context,
        _controller,
        const BouncingScrollPhysics(),
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
        child: widget.builder(
          context,
          _controller,
          _isMouseScroll
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
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

  final _scrollIndicatorSize = App.isDesktop ? 42.0 : 64.0;

  late final VerticalDragGestureRecognizer _dragGestureRecognizer;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller;
    _scrollController.addListener(onChanged);
    Future.microtask(onChanged);
    _dragGestureRecognizer = VerticalDragGestureRecognizer()
      ..onUpdate = onUpdate;
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
    if (position.minScrollExtent != minExtent ||
        position.maxScrollExtent != maxExtent ||
        position.pixels != this.position) {
      setState(() {
        minExtent = position.minScrollExtent;
        maxExtent = position.maxScrollExtent;
        this.position = position.pixels;
      });
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
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _dragGestureRecognizer.addPointer(event);
                  },
                  child: SizedBox(
                    width: _scrollIndicatorSize/2,
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
    canvas.drawShadow(path, shadowColor, 4, true);
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
