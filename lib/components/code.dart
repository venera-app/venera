part of 'components.dart';

class CodeEditor extends StatefulWidget {
  const CodeEditor({super.key, this.initialValue, this.onChanged});

  final String? initialValue;

  final void Function(String value)? onChanged;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  var horizontalScrollController = ScrollController();
  var verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode()
      ..onKeyEvent = (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          if (event is KeyDownEvent) {
            handleTab();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
  }

  void handleTab() {
    var text = _controller.text;
    var start = _controller.selection.start;
    var end = _controller.selection.end;
    _controller.text = '${text.substring(0, start)}    ${text.substring(end)}';
    _controller.selection = TextSelection.collapsed(offset: start + 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      controller: verticalScrollController,
      notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
      child: Scrollbar(
        thumbVisibility: true,
        controller: horizontalScrollController,
        notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
        child: SizedBox.expand(
          child: ScrollConfiguration(
            behavior: _CustomScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: horizontalScrollController,
              child: IntrinsicWidth(
                stepWidth: 100,
                child: TextField(
                  style: TextStyle(
                    fontFamily: 'consolas',
                    fontFamilyFallback: ['Courier New', 'monospace'],
                  ),
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8),
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                  },
                  scrollController: verticalScrollController,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomScrollBehavior extends MaterialScrollBehavior {
  const _CustomScrollBehavior();
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
