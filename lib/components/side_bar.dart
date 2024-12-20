part of 'components.dart';

class SideBarRoute<T> extends PopupRoute<T> {
  SideBarRoute(this.title, this.widget,
      {this.showBarrier = true,
      this.useSurfaceTintColor = false,
      required this.width,
      this.addBottomPadding = true,
      this.addTopPadding = true});

  final String? title;

  final Widget widget;

  final bool showBarrier;

  final bool useSurfaceTintColor;

  final double width;

  final bool addTopPadding;

  final bool addBottomPadding;

  @override
  Color? get barrierColor => showBarrier ? Colors.black54 : Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "exit";

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    bool showSideBar = MediaQuery.of(context).size.width > width;

    Widget body = SidebarBody(
      title: title,
      widget: widget,
      autoChangeTitleBarColor: !useSurfaceTintColor,
    );

    if (addTopPadding) {
      body = Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: body,
        ),
      );
    }

    final sideBarWidth = math.min(width, MediaQuery.of(context).size.width);

    body = Container(
      decoration: BoxDecoration(
        borderRadius: showSideBar
            ? const BorderRadius.horizontal(left: Radius.circular(16))
            : null,
        color: Theme.of(context).colorScheme.surfaceTint,
        boxShadow: context.brightness == ui.Brightness.dark ? [
          BoxShadow(
            color: Colors.white.withAlpha(50),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ] : null,
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxWidth: sideBarWidth),
      height: MediaQuery.of(context).size.height,
      child: GestureDetector(
        child: Material(
          child: ClipRect(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  MediaQuery.of(context).padding.right,
                  addBottomPadding
                      ? MediaQuery.of(context).padding.bottom +
                          MediaQuery.of(context).viewInsets.bottom
                      : 0),
              color: useSurfaceTintColor
                  ? Theme.of(context).colorScheme.surfaceTint.withAlpha(20)
                  : null,
              child: body,
            ),
          ),
        ),
      ),
    );

    if (App.isIOS) {
      body = IOSBackGestureDetector(
        enabledCallback: () => true,
        gestureWidth: 20.0,
        onStartPopGesture: () =>
            IOSBackGestureController(controller!, navigator!),
        child: body,
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: body,
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    var offset =
        Tween<Offset>(begin: const Offset(1, 0), end: const Offset(0, 0));
    return SlideTransition(
      position: offset.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
      )),
      child: child,
    );
  }
}

class SidebarBody extends StatefulWidget {
  const SidebarBody(
      {required this.title,
      required this.widget,
      required this.autoChangeTitleBarColor,
      super.key});

  final String? title;
  final Widget widget;
  final bool autoChangeTitleBarColor;

  @override
  State<SidebarBody> createState() => _SidebarBodyState();
}

class _SidebarBodyState extends State<SidebarBody> {
  bool top = true;

  @override
  Widget build(BuildContext context) {
    Widget body = Expanded(child: widget.widget);

    if (widget.autoChangeTitleBarColor) {
      body = NotificationListener<ScrollNotification>(
        onNotification: (notifications) {
          if (notifications.metrics.pixels ==
                  notifications.metrics.minScrollExtent &&
              !top) {
            setState(() {
              top = true;
            });
          } else if (notifications.metrics.pixels !=
                  notifications.metrics.minScrollExtent &&
              top) {
            setState(() {
              top = false;
            });
          }
          return false;
        },
        child: body,
      );
    }

    return Column(
      children: [
        if (widget.title != null)
          Container(
            height: 60 + MediaQuery.of(context).padding.top,
            color: top
                ? null
                : Theme.of(context).colorScheme.surfaceTint.withAlpha(20),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                const SizedBox(
                  width: 8,
                ),
                Tooltip(
                  message: "Back".tl,
                  child: IconButton(
                    iconSize: 25,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  widget.title!,
                  style: const TextStyle(fontSize: 22),
                )
              ],
            ),
          ),
        body
      ],
    );
  }
}

Future<void> showSideBar(BuildContext context, Widget widget,
    {String? title,
    bool showBarrier = true,
    bool useSurfaceTintColor = false,
    double width = 500,
    bool addTopPadding = false}) {
  return Navigator.of(context).push(
    SideBarRoute(
      title,
      widget,
      showBarrier: showBarrier,
      useSurfaceTintColor: useSurfaceTintColor,
      width: width,
      addTopPadding: addTopPadding,
      addBottomPadding: true,
    ),
  );
}
