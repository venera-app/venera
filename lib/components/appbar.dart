part of 'components.dart';

class Appbar extends StatefulWidget implements PreferredSizeWidget {
  const Appbar(
      {required this.title,
      this.leading,
      this.actions,
      this.backgroundColor,
      super.key});

  final Widget title;

  final Widget? leading;

  final List<Widget>? actions;

  final Color? backgroundColor;

  @override
  State<Appbar> createState() => _AppbarState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _AppbarState extends State<Appbar> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    _scrollNotificationObserver?.addListener(_handleScrollNotification);
  }

  @override
  void dispose() {
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.removeListener(_handleScrollNotification);
      _scrollNotificationObserver = null;
    }
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      final bool oldScrolledUnder = _scrolledUnder;
      final ScrollMetrics metrics = notification.metrics;
      switch (metrics.axisDirection) {
        case AxisDirection.up:
          // Scroll view is reversed
          _scrolledUnder = metrics.extentAfter > 0;
        case AxisDirection.down:
          _scrolledUnder = metrics.extentBefore > 0;
        case AxisDirection.right:
        case AxisDirection.left:
          // Scrolled under is only supported in the vertical axis, and should
          // not be altered based on horizontal notifications of the same
          // predicate since it could be a 2D scroller.
          break;
      }

      if (_scrolledUnder != oldScrolledUnder) {
        setState(() {
          // React to a change in MaterialState.scrolledUnder
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var content = SizedBox(
      height: _kAppBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 8),
          widget.leading ??
              Tooltip(
                message: "Back".tl,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          const SizedBox(
            width: 16,
          ),
          Expanded(
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 20),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: widget.title,
            ),
          ),
          ...?widget.actions,
          const SizedBox(
            width: 8,
          )
        ],
      ),
    ).paddingTop(context.padding.top);
    if (widget.backgroundColor != Colors.transparent) {
      return Material(
        elevation: (_scrolledUnder && context.width < changePoint) ? 1 : 0,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
        child: content,
      );
    }
    return content;
  }
}

class SliverAppbar extends StatelessWidget {
  const SliverAppbar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.color,
    this.radius = 0,
  });

  final Widget? leading;

  final Widget title;

  final List<Widget>? actions;

  final Color? color;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MySliverAppBarDelegate(
        leading: leading,
        title: title,
        actions: actions,
        topPadding: MediaQuery.of(context).padding.top,
        color: color,
        radius: radius,
      ),
    );
  }
}

const _kAppBarHeight = 58.0;

class _MySliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget? leading;

  final Widget title;

  final List<Widget>? actions;

  final double topPadding;

  final Color? color;

  final double radius;

  _MySliverAppBarDelegate(
      {this.leading,
      required this.title,
      this.actions,
      this.color,
      required this.topPadding,
      this.radius = 0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Material(
        color: color,
        elevation: 0,
        borderRadius: BorderRadius.circular(radius),
        child: Row(
          children: [
            const SizedBox(width: 8),
            leading ??
                (Navigator.of(context).canPop()
                    ? Tooltip(
                        message: "返回".tl,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      )
                    : const SizedBox()),
            const SizedBox(
              width: 24,
            ),
            Expanded(
              child: DefaultTextStyle(
                style:
                    DefaultTextStyle.of(context).style.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title,
              ),
            ),
            ...?actions,
            const SizedBox(
              width: 8,
            )
          ],
        ).paddingTop(topPadding),
      ),
    );
  }

  @override
  double get maxExtent => _kAppBarHeight + topPadding;

  @override
  double get minExtent => _kAppBarHeight + topPadding;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _MySliverAppBarDelegate ||
        leading != oldDelegate.leading ||
        title != oldDelegate.title ||
        actions != oldDelegate.actions;
  }
}

class FloatingSearchBar extends StatefulWidget {
  const FloatingSearchBar({
    super.key,
    this.height = 56,
    this.trailing,
    required this.onSearch,
    required this.controller,
    this.onChanged,
  });

  /// height of search bar
  final double height;

  /// end of search bar
  final Widget? trailing;

  /// callback when user do search
  final void Function(String) onSearch;

  /// controller of [TextField]
  final TextEditingController controller;

  final void Function(String)? onChanged;

  @override
  State<FloatingSearchBar> createState() => _FloatingSearchBarState();
}

class _FloatingSearchBarState extends State<FloatingSearchBar> {
  double get effectiveHeight {
    return math.max(widget.height, 53);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    var text = widget.controller.text;
    if (text.isEmpty) {
      text = "Search";
    }
    var padding = 12.0;
    return Container(
      padding: EdgeInsets.fromLTRB(padding, 9, padding, 0),
      width: double.infinity,
      height: effectiveHeight,
      child: Material(
        elevation: 0,
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(effectiveHeight / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Tooltip(
              message: "返回".tl,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: widget.controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  onSubmitted: (s) {
                    widget.onSearch(s);
                  },
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!
          ]),
        ),
      ),
    );
  }
}

class FilledTabBar extends StatefulWidget {
  const FilledTabBar({super.key, this.controller, required this.tabs});

  final TabController? controller;

  final List<Tab> tabs;

  @override
  State<FilledTabBar> createState() => _FilledTabBarState();
}

class _FilledTabBarState extends State<FilledTabBar> {
  late TabController _controller;

  late List<GlobalKey> keys;

  static const _kTabHeight = 48.0;

  static const tabPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);

  static const tabRadius = 12.0;

  _IndicatorPainter? painter;

  var scrollController = ScrollController();

  var tabBarKey = GlobalKey();

  var offsets = <double>[];

  @override
  void initState() {
    keys = widget.tabs.map((e) => GlobalKey()).toList();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _controller = widget.controller ?? DefaultTabController.of(context);
    _controller.animation!.addListener(onTabChanged);
    initPainter();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant FilledTabBar oldWidget) {
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? DefaultTabController.of(context);
      _controller.animation!.addListener(onTabChanged);
      initPainter();
    }
    super.didUpdateWidget(oldWidget);
  }

  void initPainter() {
    var old = painter;
    painter = _IndicatorPainter(
      controller: _controller,
      color: context.colorScheme.primary,
      padding: tabPadding,
      radius: tabRadius,
    );
    if (old != null) {
      painter!.update(old.offsets!, old.itemHeight!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: buildTabBar,
    );
  }

  void _tabLayoutCallback(List<double> offsets, double itemHeight) {
    painter!.update(offsets, itemHeight);
    this.offsets = offsets;
  }

  Widget buildTabBar(BuildContext context, Widget? _) {
    var child = SmoothScrollProvider(
      controller: scrollController,
      builder: (context, controller, physics) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          controller: controller,
          physics: physics,
          child: CustomPaint(
            painter: painter,
            child: _TabRow(
              callback: _tabLayoutCallback,
              children: List.generate(widget.tabs.length, buildTab),
            ),
          ).paddingHorizontal(4),
        );
      },
    );
    return Container(
      key: tabBarKey,
      height: _kTabHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: widget.tabs.isEmpty
          ? const SizedBox()
          : child
    );
  }

  int? previousIndex;

  void onTabChanged() {
    final int i = _controller.index;
    if (i == previousIndex) {
      return;
    }
    updateScrollOffset(i);
    previousIndex = i;
  }

  void updateScrollOffset(int i) {
    // try to scroll to center the tab
    final RenderBox tabBarBox =
        tabBarKey.currentContext!.findRenderObject() as RenderBox;
    final double tabLeft = offsets[i];
    final double tabRight = offsets[i + 1];
    final double tabWidth = tabRight - tabLeft;
    final double tabCenter = tabLeft + tabWidth / 2;
    final double tabBarWidth = tabBarBox.size.width;
    final double scrollOffset = tabCenter - tabBarWidth / 2;
    if (scrollOffset == scrollController.offset) {
      return;
    }
    scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void onTabClicked(int i) {
    _controller.animateTo(i);
  }

  Widget buildTab(int i) {
    return InkWell(
      onTap: () => onTabClicked(i),
      borderRadius: BorderRadius.circular(tabRadius),
      child: KeyedSubtree(
        key: keys[i],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
              color: i == _controller.index
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            child: widget.tabs[i],
          ),
        ),
      ),
    ).padding(tabPadding);
  }
}

typedef _TabRenderCallback = void Function(
  List<double> offsets,
  double itemHeight,
);

class _TabRow extends Row {
  const _TabRow({required this.callback, required super.children});

  final _TabRenderCallback callback;

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return _RenderTabFlex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: Directionality.of(context),
        verticalDirection: VerticalDirection.down,
        callback: callback);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTabFlex renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.callback = callback;
  }
}

class _RenderTabFlex extends RenderFlex {
  _RenderTabFlex({
    required super.direction,
    required super.mainAxisSize,
    required super.mainAxisAlignment,
    required super.crossAxisAlignment,
    required TextDirection super.textDirection,
    required super.verticalDirection,
    required this.callback,
  });

  _TabRenderCallback callback;

  @override
  void performLayout() {
    super.performLayout();
    RenderBox? child = firstChild;
    final List<double> xOffsets = <double>[];
    while (child != null) {
      final FlexParentData childParentData =
          child.parentData! as FlexParentData;
      xOffsets.add(childParentData.offset.dx);
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    xOffsets.add(size.width);
    callback(xOffsets, firstChild!.size.height);
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.controller,
    required this.color,
    required this.padding,
    this.radius = 4.0,
  }) : super(repaint: controller.animation);

  final TabController controller;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  List<double>? offsets;
  double? itemHeight;
  Rect? _currentRect;

  void update(List<double> offsets, double itemHeight) {
    this.offsets = offsets;
    this.itemHeight = itemHeight;
  }

  int get maxTabIndex => offsets!.length - 2;

  Rect indicatorRect(Size tabBarSize, int tabIndex) {
    assert(offsets != null);
    assert(offsets!.isNotEmpty);
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    var (tabLeft, tabRight) = (offsets![tabIndex], offsets![tabIndex + 1]);

    const horizontalPadding = 12.0;

    var rect = Rect.fromLTWH(
      tabLeft + padding.left + horizontalPadding,
      _FilledTabBarState._kTabHeight - 3.6,
      tabRight - tabLeft - padding.horizontal - horizontalPadding * 2,
      3,
    );

    return rect;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets == null || itemHeight == null) {
      return;
    }
    final double index = controller.index.toDouble();
    final double value = controller.animation!.value;
    final bool ltr = index > value;
    final int from = (ltr ? value.floor() : value.ceil()).clamp(0, maxTabIndex);
    final int to = (ltr ? from + 1 : from - 1).clamp(0, maxTabIndex);
    final Rect fromRect = indicatorRect(size, from);
    final Rect toRect = indicatorRect(size, to);
    _currentRect = Rect.lerp(fromRect, toRect, (value - from).abs());
    final Paint paint = Paint()..color = color;
    final RRect rrect =
        RRect.fromRectAndCorners(_currentRect!, topLeft: Radius.circular(radius), topRight: Radius.circular(radius));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
