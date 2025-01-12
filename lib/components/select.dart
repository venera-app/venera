part of 'components.dart';

class Select extends StatelessWidget {
  const Select({
    super.key,
    required this.current,
    required this.values,
    this.onTap,
    this.minWidth,
  });

  final String? current;

  final List<String> values;

  final void Function(int index)? onTap;

  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          var renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          var size = renderBox.size;
          showMenu(
            elevation: 3,
            color: context.brightness == Brightness.light
                ? const Color(0xFFF6F6F6)
                : const Color(0xFF1E1E1E),
            context: context,
            useRootNavigator: true,
            constraints: BoxConstraints(
              minWidth: size.width,
              maxWidth: size.width,
            ),
            position: RelativeRect.fromLTRB(
              offset.dx,
              offset.dy + size.height + 2,
              offset.dx + size.height + 2,
              offset.dy,
            ),
            items: values
                .map((e) => PopupMenuItem(
                      height: App.isMobile ? 46 : 40,
                      value: e,
                      child: Text(e),
                    ))
                .toList(),
          ).then((value) {
            if (value != null) {
              onTap?.call(values.indexOf(value));
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth != null ? (minWidth! - 32) : 0,
              ),
              child: Text(current ?? ' ', style: ts.s14),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: context.colorScheme.primary),
          ],
        ).padding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      ),
    );
  }
}

class FilterChipFixedWidth extends StatefulWidget {
  const FilterChipFixedWidth(
      {required this.label,
      required this.selected,
      required this.onSelected,
      super.key});

  final Widget label;

  final bool selected;

  final void Function(bool) onSelected;

  @override
  State<FilterChipFixedWidth> createState() => _FilterChipFixedWidthState();
}

class _FilterChipFixedWidthState extends State<FilterChipFixedWidth> {
  get selected => widget.selected;

  double? labelWidth;

  double? labelHeight;

  var key = GlobalKey();

  @override
  void initState() {
    Future.microtask(measureSize);
    super.initState();
  }

  void measureSize() {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    labelWidth = renderBox.size.width;
    labelHeight = renderBox.size.height;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      textStyle: Theme.of(context).textTheme.labelLarge,
      child: InkWell(
        onTap: () => widget.onSelected(true),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: labelWidth == null ? firstBuild() : buildContent(),
        ),
      ),
    );
  }

  Widget firstBuild() {
    return Center(
      child: SizedBox(
        key: key,
        child: widget.label,
      ),
    );
  }

  Widget buildContent() {
    const iconSize = 18.0;
    const gap = 4.0;
    return SizedBox(
      width: iconSize + labelWidth! + gap,
      height: math.max(iconSize, labelHeight!),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _fastAnimationDuration,
            left: selected ? (iconSize + gap) : (iconSize + gap) / 2,
            child: widget.label,
          ),
          if (selected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: labelWidth! + gap,
              child: const AnimatedCheckIcon(size: iconSize).toCenter(),
            )
        ],
      ),
    );
  }
}

class AnimatedCheckWidget extends AnimatedWidget {
  const AnimatedCheckWidget({
    super.key,
    required Animation<double> animation,
    this.size,
  }) : super(listenable: animation);

  final double? size;

  @override
  Widget build(BuildContext context) {
    var iconSize = size ?? IconTheme.of(context).size ?? 25;
    final animation = listenable as Animation<double>;
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: animation.value,
          child: ClipRRect(
            child: Icon(
              Icons.check,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCheckIcon extends StatefulWidget {
  const AnimatedCheckIcon({this.size, super.key});

  final double? size;

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: _fastAnimationDuration,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCheckWidget(
      animation: animation,
      size: widget.size,
    );
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip(
      {super.key,
      required this.text,
      required this.isSelected,
      required this.onTap});

  final String text;

  final bool isSelected;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _fastAnimationDuration,
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.secondaryContainer
            : context.colorScheme.surface,
        border: isSelected
            ? Border.all(color: context.colorScheme.secondaryContainer)
            : Border.all(color: context.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
