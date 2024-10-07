part of 'components.dart';

class BlurEffect extends StatelessWidget {
  final Widget child;

  final double blur;

  const BlurEffect({
    required this.child,
    this.blur = 15,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.mirror,
        ),
        child: child,
      ),
    );
  }
}
