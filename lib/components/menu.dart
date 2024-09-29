part of "components.dart";

void showDesktopMenu(
    BuildContext context, Offset location, List<DesktopMenuEntry> entries) {
  Navigator.of(context).push(DesktopMenuRoute(entries, location));
}

class DesktopMenuRoute<T> extends PopupRoute<T> {
  final List<DesktopMenuEntry> entries;

  final Offset location;

  DesktopMenuRoute(this.entries, this.location);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "menu";

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    const width = 196.0;
    final size = MediaQuery.of(context).size;
    var left = location.dx;
    if (left + width > size.width - 10) {
      left = size.width - width - 10;
    }
    var top = location.dy;
    var height = 16 + 32 * entries.length;
    if (top + height > size.height - 15) {
      top = size.height - height - 15;
    }
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]),
            child: Material(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: entries.map((e) => buildEntry(e, context)).toList(),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget buildEntry(DesktopMenuEntry entry, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        Navigator.of(context).pop();
        entry.onClick();
      },
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            const SizedBox(
              width: 4,
            ),
            if (entry.icon != null)
              Icon(
                entry.icon,
                size: 18,
              ),
            const SizedBox(
              width: 4,
            ),
            Text(entry.text),
          ],
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation.drive(Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Curves.ease))),
      child: child,
    );
  }
}

class DesktopMenuEntry {
  final String text;
  final IconData? icon;
  final void Function() onClick;

  DesktopMenuEntry({required this.text, this.icon, required this.onClick});
}
