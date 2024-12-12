part of "components.dart";

const minFlyoutWidth = 256.0;
const minFlyoutHeight = 128.0;

class FlyoutController {
  Function? _show;

  void show() {
    if (_show == null) {
      throw "FlyoutController is not attached to a Flyout";
    }
    _show!();
  }
}

class Flyout extends StatefulWidget {
  const Flyout({
    super.key,
    required this.flyoutBuilder,
    required this.child,
    this.enableTap = false,
    this.enableDoubleTap = false,
    this.enableLongPress = false,
    this.enableSecondaryTap = false,
    this.withInkWell = false,
    this.borderRadius = 0,
    this.controller,
    this.navigator,
  });

  final WidgetBuilder flyoutBuilder;

  final Widget child;

  final bool enableTap;

  final bool enableDoubleTap;

  final bool enableLongPress;

  final bool enableSecondaryTap;

  final bool withInkWell;

  final double borderRadius;

  final NavigatorState? navigator;

  final FlyoutController? controller;

  @override
  State<Flyout> createState() => FlyoutState();

  static FlyoutState of(BuildContext context) {
    return context.findAncestorStateOfType<FlyoutState>()!;
  }
}

class FlyoutState extends State<Flyout> {
  @override
  void initState() {
    if (widget.controller != null) {
      widget.controller?._show = show;
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (widget.controller != null) {
      widget.controller?._show = show;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.withInkWell) {
      return InkWell(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        onTap: widget.enableTap ? show : null,
        onDoubleTap: widget.enableDoubleTap ? show : null,
        onLongPress: widget.enableLongPress ? show : null,
        onSecondaryTap: widget.enableSecondaryTap ? show : null,
        child: widget.child,
      );
    }
    return GestureDetector(
      onTap: widget.enableTap ? show : null,
      onDoubleTap: widget.enableDoubleTap ? show : null,
      onLongPress: widget.enableLongPress ? show : null,
      onSecondaryTap: widget.enableSecondaryTap ? show : null,
      child: widget.child,
    );
  }

  void show() {
    var renderBox = context.findRenderObject() as RenderBox;
    var rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    var navigator = widget.navigator ??
        Navigator.of(
          context,
          rootNavigator: true,
        );
    navigator.push(PageRouteBuilder(
        fullscreenDialog: true,
        barrierDismissible: true,
        opaque: false,
        transitionDuration: _fastAnimationDuration,
        reverseTransitionDuration: _fastAnimationDuration,
        pageBuilder: (context, animation, secondaryAnimation) {
          var left = rect.left;
          var top = rect.bottom;

          if (left + minFlyoutWidth > MediaQuery.of(context).size.width) {
            left = MediaQuery.of(context).size.width - minFlyoutWidth;
          }
          if (top + minFlyoutHeight > MediaQuery.of(context).size.height) {
            top = MediaQuery.of(context).size.height - minFlyoutHeight;
          }

          Widget transition(BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget flyout) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.05),
                end: const Offset(0, 0),
              ).animate(animation),
              child: flyout,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: navigator.pop,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, builder) {
                      return ColoredBox(
                        color: Colors.black.toOpacity(0.3 * animation.value),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: left,
                right: 0,
                top: top,
                bottom: 0,
                child: transition(
                    context,
                    animation,
                    secondaryAnimation,
                    Align(
                      alignment: Alignment.topLeft,
                      child: widget.flyoutBuilder(context),
                    )),
              )
            ],
          );
        }));
  }
}

class FlyoutContent extends StatelessWidget {
  const FlyoutContent(
      {super.key, required this.title, required this.actions, this.content});

  final String title;

  final Widget? content;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: BlurEffect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          borderRadius: BorderRadius.circular(8),
          type: MaterialType.card,
          color: context.colorScheme.surface.toOpacity(0.82),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: minFlyoutWidth,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: context.brightness == ui.Brightness.dark
                  ? Border.all(color: context.colorScheme.outlineVariant)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (content != null) content!,
                const SizedBox(
                  height: 12,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [const Spacer(), ...actions],
                ),
              ],
            ),
          ),
        ).paddingAll(4),
      ),
    );
  }
}
