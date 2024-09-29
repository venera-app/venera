part of 'components.dart';

class HoverBox extends StatefulWidget {
  const HoverBox(
      {super.key, required this.child, this.borderRadius = BorderRadius.zero});

  final Widget child;

  final BorderRadius borderRadius;

  @override
  State<HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<HoverBox> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            color: isHover
                ? Theme.of(context).colorScheme.surfaceContainerLow
                : null,
            borderRadius: widget.borderRadius),
        child: widget.child,
      ),
    );
  }
}

enum ButtonType { filled, outlined, text, normal }

class Button extends StatefulWidget {
  const Button(
      {super.key,
      required this.type,
      required this.child,
      this.isLoading = false,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      required this.onPressed});

  const Button.filled(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.isLoading = false})
      : type = ButtonType.filled;

  const Button.outlined(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.isLoading = false})
      : type = ButtonType.outlined;

  const Button.text(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.isLoading = false})
      : type = ButtonType.text;

  const Button.normal(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.isLoading = false})
      : type = ButtonType.normal;

  static Widget icon(
      {Key? key,
      required Widget icon,
      required VoidCallback onPressed,
      double? size,
      Color? color,
      String? tooltip}) {
    return _IconButton(
      key: key,
      icon: icon,
      onPressed: onPressed,
      size: size,
      color: color,
      tooltip: tooltip,
    );
  }

  final ButtonType type;

  final Widget child;

  final bool isLoading;

  final void Function() onPressed;

  final void Function(Offset location)? onPressedAt;

  final double? width;

  final double? height;

  final EdgeInsets? padding;

  final Color? color;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool isHover = false;

  bool isLoading = false;

  @override
  void didUpdateWidget(covariant Button oldWidget) {
    if (oldWidget.isLoading != widget.isLoading) {
      setState(() => isLoading = widget.isLoading);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    var padding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    var width = widget.width;
    if (width != null) {
      width = width - padding.horizontal;
    }
    var height = widget.height;
    if (height != null) {
      height = height - padding.vertical;
    }
    Widget child = DefaultTextStyle(
      style: TextStyle(
        color: textColor,
        fontSize: 16,
      ),
      child: isLoading
          ? CircularProgressIndicator(
              color: widget.type == ButtonType.filled
                  ? context.colorScheme.inversePrimary
                  : context.colorScheme.primary,
              strokeWidth: 1.8,
            ).fixWidth(16).fixHeight(16)
          : widget.child,
    );
    if (width != null || height != null) {
      child = child.toCenter();
    }
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isLoading) return;
          widget.onPressed();
          if (widget.onPressedAt != null) {
            var renderBox = context.findRenderObject() as RenderBox;
            var offset = renderBox.localToGlobal(Offset.zero);
            widget.onPressedAt!(offset);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: padding,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (isHover && !isLoading && widget.type == ButtonType.filled)
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
            border: widget.type == ButtonType.outlined
                ? Border.all(
                    color: widget.color ??
                        Theme.of(context).colorScheme.outlineVariant,
                    width: 0.6,
                  )
                : null,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Color get buttonColor {
    if (widget.type == ButtonType.filled) {
      var color = widget.color ?? context.colorScheme.primary;
      if (isHover) {
        return color.withOpacity(0.9);
      } else {
        return color;
      }
    }
    if (isHover) {
      return context.colorScheme.outline.withOpacity(0.2);
    }
    return Colors.transparent;
  }

  Color get textColor {
    if (widget.type == ButtonType.outlined) {
      return widget.color ?? context.colorScheme.onSurface;
    }
    return widget.type == ButtonType.filled
        ? context.colorScheme.onPrimary
        : (widget.type == ButtonType.text
            ? widget.color ?? context.colorScheme.primary
            : context.colorScheme.onSurface);
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      this.size,
      this.color,
      this.tooltip});

  final Widget icon;

  final VoidCallback onPressed;

  final double? size;

  final String? tooltip;

  final Color? color;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onPressed,
      mouseCursor: SystemMouseCursors.click,
      customBorder: const CircleBorder(),
      child: Tooltip(
        message: widget.tooltip ?? "",
        child: Container(
          decoration: BoxDecoration(
            color:
                isHover ? Theme.of(context).colorScheme.surfaceContainer : null,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(6),
          child: IconTheme(
            data: IconThemeData(
                size: widget.size ?? 24,
                color: widget.color ?? context.colorScheme.primary),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
