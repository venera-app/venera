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

  @override
  void initState() {
    _controller = widget.controller ?? ScrollController();
    super.initState();
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _futurePosition = null;
        if (_isMouseScroll) {
          setState(() {
            _isMouseScroll = false;
          });
        }
      },
      onPointerSignal: (pointerSignal) {
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
          _futurePosition = _futurePosition!.clamp(
            _controller.position.minScrollExtent,
            _controller.position.maxScrollExtent,
          );
          if (_futurePosition == old) return;
          _controller.animateTo(_futurePosition!,
              duration: _fastAnimationDuration, curve: Curves.linear);
        }
      },
      child: widget.builder(
        context,
        _controller,
        _isMouseScroll
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
      ),
    );
  }
}
