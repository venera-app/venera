import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/js_engine.dart';

import 'components.dart';

mixin class JsUiApi {
  final Map<int, LoadingDialogController> _loadingDialogControllers = {};

  dynamic handleUIMessage(Map<String, dynamic> message) {
    switch (message['function']) {
      case 'showMessage':
        var m = message['message'];
        if (m.toString().isNotEmpty) {
          App.rootContext.showMessage(message: m.toString());
        }
      case 'showDialog':
        return _showDialog(message);
      case 'launchUrl':
        var url = message['url'];
        if (url.toString().isNotEmpty) {
          launchUrlString(url.toString());
        }
      case 'showLoading':
        var onCancel = message['onCancel'];
        if (onCancel != null && onCancel is! JSInvokable) {
          return;
        }
        return _showLoading(onCancel);
      case 'cancelLoading':
        var id = message['id'];
        if (id is int) {
          _cancelLoading(id);
        }
      case 'showInputDialog':
        var title = message['title'];
        var validator = message['validator'];
        var image = message['image'];
        if (title is! String) return;
        if (validator != null && validator is! JSInvokable) return;
        if (image != null && image is! String) return;
        return _showInputDialog(title, validator, image);
      case 'showSelectDialog':
        var title = message['title'];
        var options = message['options'];
        var initialIndex = message['initialIndex'];
        if (title is! String) return;
        if (options is! List) return;
        if (initialIndex != null && initialIndex is! int) return;
        return _showSelectDialog(
          title,
          options.whereType<String>().toList(),
          initialIndex,
        );
    }
  }

  Future<void> _showDialog(Map<String, dynamic> message) {
    BuildContext? dialogContext;
    var title = message['title'];
    var content = message['content'];
    var actions = <Widget>[];
    for (var action in message['actions']) {
      if (action['callback'] is! JSInvokable) {
        continue;
      }
      var callback = action['callback'] as JSInvokable;
      var text = action['text'].toString();
      var style = (action['style'] ?? 'text').toString();
      actions.add(_JSCallbackButton(
        text: text,
        callback: JSAutoFreeFunction(callback),
        style: style,
        onCallbackFinished: () {
          dialogContext?.pop();
        },
      ));
    }
    if (actions.isEmpty) {
      actions.add(TextButton(
        onPressed: () {
          dialogContext?.pop();
        },
        child: Text('OK'),
      ));
    }
    return showDialog(
      context: App.rootContext,
      builder: (context) {
        dialogContext = context;
        return ContentDialog(
          title: title,
          content: Text(content).paddingHorizontal(16),
          actions: actions,
        );
      },
    ).then((value) {
      dialogContext = null;
    });
  }

  int _showLoading(JSInvokable? onCancel) {
    var func = onCancel == null ? null : JSAutoFreeFunction(onCancel);
    var controller = showLoadingDialog(
      App.rootContext,
      barrierDismissible: onCancel != null,
      allowCancel: onCancel != null,
      onCancel: onCancel == null
          ? null
          : () {
              func?.call([]);
            },
    );
    var i = 0;
    while (_loadingDialogControllers.containsKey(i)) {
      i++;
    }
    _loadingDialogControllers[i] = controller;
    return i;
  }

  void _cancelLoading(int id) {
    var controller = _loadingDialogControllers.remove(id);
    controller?.close();
  }

  Future<String?> _showInputDialog(String title, JSInvokable? validator, String? image) async {
    String? result;
    var func = validator == null ? null : JSAutoFreeFunction(validator);
    await showInputDialog(
      context: App.rootContext,
      title: title,
      image: image,
      onConfirm: (v) {
        if (func != null) {
          var res = func.call([v]);
          if (res != null) {
            return res.toString();
          } else {
            result = v;
          }
        } else {
          result = v;
        }
        return null;
      },
    );
    return result;
  }

  Future<int?> _showSelectDialog(
    String title,
    List<String> options,
    int? initialIndex,
  ) {
    if (options.isEmpty) {
      return Future.value(null);
    }
    if (initialIndex != null &&
        (initialIndex >= options.length || initialIndex < 0)) {
      initialIndex = null;
    }
    return showSelectDialog(
      title: title,
      options: options,
      initialIndex: initialIndex,
    );
  }
}

class _JSCallbackButton extends StatefulWidget {
  const _JSCallbackButton({
    required this.text,
    required this.callback,
    required this.style,
    this.onCallbackFinished,
  });

  final JSAutoFreeFunction callback;

  final String text;

  final String style;

  final void Function()? onCallbackFinished;

  @override
  State<_JSCallbackButton> createState() => _JSCallbackButtonState();
}

class _JSCallbackButtonState extends State<_JSCallbackButton> {
  bool isLoading = false;

  void onClick() async {
    if (isLoading) {
      return;
    }
    var res = widget.callback.call([]);
    if (res is Future) {
      setState(() {
        isLoading = true;
      });
      await res;
      setState(() {
        isLoading = false;
      });
    }
    widget.onCallbackFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.style) {
      "filled" => FilledButton(
          onPressed: onClick,
          child: isLoading
              ? CircularProgressIndicator(strokeWidth: 1.4)
                  .fixWidth(18)
                  .fixHeight(18)
              : Text(widget.text),
        ),
      "danger" => FilledButton(
          onPressed: onClick,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(context.colorScheme.error),
          ),
          child: isLoading
              ? CircularProgressIndicator(strokeWidth: 1.4)
                  .fixWidth(18)
                  .fixHeight(18)
              : Text(widget.text),
        ),
      _ => TextButton(
          onPressed: onClick,
          child: isLoading
              ? CircularProgressIndicator(strokeWidth: 1.4)
                  .fixWidth(18)
                  .fixHeight(18)
              : Text(widget.text),
        ),
    };
  }
}
