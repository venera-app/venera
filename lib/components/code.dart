part of 'components.dart';

class CodeEditor extends StatefulWidget {
  const CodeEditor({super.key, this.initialValue, this.onChanged});

  final String? initialValue;

  final void Function(String value)? onChanged;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late _CodeTextEditingController _controller;
  late FocusNode _focusNode;
  var horizontalScrollController = ScrollController();
  var verticalScrollController = ScrollController();
  int lineCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = _CodeTextEditingController(text: widget.initialValue);
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
    lineCount = calculateLineCount(widget.initialValue ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future = _controller.init(context.brightness);
  }

  void handleTab() {
    var text = _controller.text;
    var start = _controller.selection.start;
    var end = _controller.selection.end;
    _controller.text = '${text.substring(0, start)}    ${text.substring(end)}';
    _controller.selection = TextSelection.collapsed(offset: start + 4);
  }

  int calculateLineCount(String text) {
    return text.split('\n').length;
  }

  Widget buildLineNumbers() {
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          for (var i = 1; i <= lineCount; i++)
            SizedBox(
              height: 14 * 1.5,
              child: Center(
                child: Text(
                  i.toString(),
                  style: TextStyle(
                    color: context.colorScheme.outline,
                    fontSize: 13,
                    height: 1.0,
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['Courier New', 'monospace'],
                  ),
                ),
              ),
            ),
        ],
      ),
    ).paddingVertical(8);
  }

  late Future future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, value) {
        if (value.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        return GestureDetector(
          onTap: () {
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            _focusNode.requestFocus();
          },
          child: Scrollbar(
            thumbVisibility: true,
            controller: verticalScrollController,
            notificationPredicate: (notif) =>
                notif.metrics.axis == Axis.vertical,
            child: Scrollbar(
              thumbVisibility: true,
              controller: horizontalScrollController,
              notificationPredicate: (notif) =>
                  notif.metrics.axis == Axis.horizontal,
              child: SizedBox.expand(
                child: ScrollConfiguration(
                  behavior: _CustomScrollBehavior(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: horizontalScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      controller: verticalScrollController,
                      child: Row(
                        children: [
                          buildLineNumbers(),
                          IntrinsicWidth(
                            stepWidth: 100,
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              cursorHeight: 1.5 * 14,
                              style: TextStyle(height: 1.5, fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(8),
                              ),
                              onChanged: (value) {
                                widget.onChanged?.call(value);
                                if (lineCount != calculateLineCount(value)) {
                                  setState(() {
                                    lineCount = calculateLineCount(value);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

class _CodeTextEditingController extends TextEditingController {
  _CodeTextEditingController({super.text});

  HighlighterTheme? _theme;

  Future<void> init(Brightness brightness) async {
    Highlighter.addLanguage('js', _jsGrammer);
    _theme = await HighlighterTheme.loadForBrightness(brightness);
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    var highlighter = Highlighter(
      language: 'js',
      theme: _theme!,
    );
    var result = highlighter.highlight(text);
    style = TextStyle(
      height: 1.5,
      fontSize: 14,
      fontFamily: 'Consolas',
      fontFamilyFallback: ['Courier New', 'Roboto Mono', 'monospace'],
    );

    return mergeTextStyle(result, style);
  }

  TextSpan mergeTextStyle(TextSpan span, TextStyle style) {
    var result = TextSpan(
      style: style.merge(span.style),
      children: span.children
          ?.whereType()
          .map((e) => mergeTextStyle(e, style))
          .toList(),
      text: span.text,
    );
    return result;
  }
}

const _jsGrammer = r'''
{
  "name": "JavaScript",
  "version": "1.0.0",
  "fileTypes": ["js", "mjs", "cjs"],
  "scopeName": "source.js",

  "foldingStartMarker": "\\{\\s*$",
  "foldingStopMarker": "^\\s*\\}",

  "patterns": [
    {
      "name": "meta.preprocessor.script.js",
      "match": "^(#!.*)$"
    },
    {
      "name": "meta.import-export.js",
      "begin": "\\b(import|export)\\b",
      "beginCaptures": {
        "0": {
          "name": "keyword.control.import.js"
        }
      },
      "end": ";",
      "endCaptures": {
        "0": {
          "name": "punctuation.terminator.js"
        }
      },
      "patterns": [
        {
          "include": "#strings"
        },
        {
          "include": "#comments"
        },
        {
          "name": "keyword.control.import.js",
          "match": "\\b(as|from)\\b"
        }
      ]
    },
    {
      "include": "#comments"
    },
    {
      "include": "#keywords"
    },
    {
      "include": "#constants-and-special-vars"
    },
    {
      "include": "#operators"
    },
    {
      "include": "#strings"
    }
  ],

  "repository": {
    "comments": {
      "patterns": [
        {
          "name": "comment.block.js",
          "begin": "/\\*",
          "end": "\\*/"
        },
        {
          "name": "comment.line.double-slash.js",
          "match": "//.*$"
        }
      ]
    },
    "keywords": {
      "patterns": [
        {
          "name": "keyword.control.js",
          "match": "\\b(if|else|for|while|do|switch|case|default|break|continue|return|throw|try|catch|finally)\\b"
        },
        {
          "name": "keyword.operator.js",
          "match": "\\b(instanceof|typeof|new|delete|in|void)\\b"
        },
        {
          "name": "storage.type.js",
          "match": "\\b(var|let|const|function|class|extends)\\b"
        },
        {
          "name": "keyword.declaration.js",
          "match": "\\b(export|import|default)\\b"
        }
      ]
    },
    "constants-and-special-vars": {
      "patterns": [
        {
          "name": "constant.language.js",
          "match": "\\b(true|false|null|undefined|NaN|Infinity)\\b"
        },
        {
          "name": "constant.numeric.js",
          "match": "\\b(0x[0-9A-Fa-f]+|[0-9]+\\.?[0-9]*(e[+-]?[0-9]+)?)\\b"
        }
      ]
    },
    "operators": {
      "patterns": [
        {
          "name": "keyword.operator.assignment.js",
          "match": "(=|\\+=|-=|\\*=|/=|%=|\\|=|&=|\\^=|<<=|>>=|>>>=)"
        },
        {
          "name": "keyword.operator.comparison.js",
          "match": "(==|!=|===|!==|<|<=|>|>=)"
        },
        {
          "name": "keyword.operator.logical.js",
          "match": "(&&|\\|\\||!)"
        },
        {
          "name": "keyword.operator.arithmetic.js",
          "match": "(-|\\+|\\*|/|%)"
        },
        {
          "name": "keyword.operator.bitwise.js",
          "match": "(\\||&|\\^|~|<<|>>|>>>)"
        }
      ]
    },
    "strings": {
      "patterns": [
        {
          "name": "string.quoted.double.js",
          "begin": "\"",
          "end": "\"",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        },
        {
          "name": "string.quoted.single.js",
          "begin": "'",
          "end": "'",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        },
        {
          "name": "string.template.js",
          "begin": "`",
          "end": "`",
          "patterns": [
            {
              "include": "#string-interpolation"
            }
          ]
        }
      ]
    },
    "string-interpolation": {
      "patterns": [
        {
          "name": "variable.parameter.js",
          "begin": "\\$\\{",
          "end": "\\}"
        }
      ]
    }
  }
}
''';
