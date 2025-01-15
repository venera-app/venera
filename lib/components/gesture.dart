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
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: context.colorScheme.outline,
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: context.colorScheme.outlineVariant,
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
