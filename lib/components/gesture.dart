part of 'components.dart';

class MouseBackRecognizer extends BaseTapGestureRecognizer {
  GestureTapDownCallback? onTapDown;

  MouseBackRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  void handleTapCancel({
    required PointerDownEvent down,
    PointerCancelEvent? cancel,
    required String reason,
  }) {}

  @override
  void handleTapDown({required PointerDownEvent down}) {
    final TapDownDetails details = TapDownDetails(
      globalPosition: down.position,
      localPosition: down.localPosition,
      kind: getKindForPointer(down.pointer),
    );

    if (down.buttons == kBackMouseButton && onTapDown != null) {
      invokeCallback<void>('onTapDown', () => onTapDown!(details));
    }
  }

  @override
  void handleTapUp({
    required PointerDownEvent down,
    required PointerUpEvent up,
  }) {}
}

class MouseBackDetector extends StatelessWidget {
  const MouseBackDetector({super.key, required this.onTapDown, required this.child});

  final Widget child;

  final GestureTapDownCallback onTapDown;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        MouseBackRecognizer: GestureRecognizerFactoryWithHandlers<MouseBackRecognizer>(
          () => MouseBackRecognizer(),
          (MouseBackRecognizer instance) {
            instance.onTapDown = onTapDown;
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
