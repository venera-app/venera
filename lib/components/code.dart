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
    return FutureBuilder(
      future: _controller.init(context.brightness),
      builder: (context, value) {
        if (value.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        return Scrollbar(
          thumbVisibility: true,
          controller: verticalScrollController,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
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
                  child: IntrinsicWidth(
                    stepWidth: 100,
                    child: TextField(
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
      fontFamily: 'consolas',
      fontFamilyFallback: ['Courier New', 'monospace'],
    );

    return setTextSpanFont(result, style);
  }

  TextSpan setTextSpanFont(TextSpan span, TextStyle style) {
    var result = TextSpan(
      style: style.merge(span.style),
      children: span.children?.whereType().map((e) => setTextSpanFont(e, style)).toList(),
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
