part of 'components.dart';

class Select extends StatefulWidget {
  const Select({
    required this.initialValue,
    this.width = 120,
    required this.onChange,
    super.key,
    required this.values,
    this.disabledValues = const [],
    this.outline = false,
  });

  ///初始值, 提供values的下标
  final int? initialValue;

  ///可供选取的值
  final List<String> values;

  ///宽度
  final double width;

  ///发生改变时的回调
  final void Function(int) onChange;

  /// 禁用的值
  final List<int> disabledValues;

  /// 是否为边框模式
  final bool outline;

  @override
  State<Select> createState() => _SelectState();
}

class _SelectState extends State<Select> {
  late int? value = widget.initialValue;
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    if (value != null && value! < 0) value = null;
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (widget.values.isEmpty) {
            return;
          }
          final renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          var size = MediaQuery.of(context).size;
          showMenu<int>(
              context: App.rootNavigatorKey.currentContext!,
              initialValue: value,
              position: RelativeRect.fromLTRB(offset.dx, offset.dy,
                  offset.dx + widget.width, size.height - offset.dy),
              constraints: BoxConstraints(
                maxWidth: widget.width,
                minWidth: widget.width,
              ),
              color: context.colorScheme.surfaceContainerLowest,
              items: [
                for (int i = 0; i < widget.values.length; i++)
                  if (!widget.disabledValues.contains(i))
                    PopupMenuItem(
                      value: i,
                      height: App.isDesktop ? 38 : 42,
                      onTap: () {
                        setState(() {
                          value = i;
                          widget.onChange(i);
                        });
                      },
                      child: Text(widget.values[i]),
                    )
              ]);
        },
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.outline ? 4 : 8),
            border: widget.outline
                ? Border.all(
                    color: context.colorScheme.outline,
                    width: 1,
                  )
                : null,
          ),
          width: widget.width,
          height: 38,
          child: Row(
            children: [
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  value == null ? "" : widget.values[value!],
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down_sharp),
              const SizedBox(
                width: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get color {
    if (widget.outline) {
      return isHover
          ? context.colorScheme.outline.withOpacity(0.1)
          : Colors.transparent;
    } else {
      var color = context.colorScheme.surfaceContainerHigh;
      if (isHover) {
        color = color.withOpacity(0.8);
      }
      return color;
    }
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
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.primaryContainer
            : context.colorScheme.surface,
        border: isSelected
            ? Border.all(color: context.colorScheme.primaryContainer)
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
