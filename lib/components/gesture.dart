part of 'components.dart';

class MouseBackDetector extends StatelessWidget {
  const MouseBackDetector(
      {super.key, required this.onTapDown, required this.child});

  final Widget child;

  final void Function() onTapDown;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kBackMouseButton) {
          onTapDown();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class AnimatedTapRegion extends StatefulWidget {
  const AnimatedTapRegion({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 0,
  });

  final Widget child;

  final void Function() onTap;

  final double borderRadius;

  @override
  State<AnimatedTapRegion> createState() => _AnimatedTapRegionState();
}

class _AnimatedTapRegionState extends State<AnimatedTapRegion> {
  bool isScaled = false;

  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        isHovered = true;
        if (!isScaled) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (isHovered) {
              setState(() => isScaled = true);
            }
          });
        }
      },
      onExit: (_) {
        isHovered = false;
        if(isScaled) {
          setState(() => isScaled = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: AnimatedScale(
            duration: _fastAnimationDuration,
            scale: isScaled ? 1.1 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
