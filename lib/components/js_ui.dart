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
        _showDialog(message);
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
        return showLoading(onCancel);
      case 'cancelLoading':
        var id = message['id'];
        if (id is int) {
          cancelLoading(id);
        }
    }
  }

  void _showDialog(Map<String, dynamic> message) {
    BuildContext? dialogContext;
    var title = message['title'];
    var content = message['content'];
    var actions = <Widget>[];
    for (var action in message['actions']) {
      if (action['callback'] is! JSInvokable) {
        continue;
      }
      var callback = action['callback'] as JSInvokable;
      // [message] will be released after the method call, causing the action to be invalid, so we need to duplicate it
      callback.dup();
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
    showDialog(
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

  int showLoading(JSInvokable? onCancel) {
    onCancel?.dup();
    var func = onCancel == null ? null : JSAutoFreeFunction(onCancel);
    var controller = showLoadingDialog(
      App.rootContext,
      barrierDismissible: onCancel != null,
      allowCancel: onCancel != null,
      onCancel: onCancel == null ? null : () {
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

  void cancelLoading(int id) {
    var controller = _loadingDialogControllers.remove(id);
    controller?.close();
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
