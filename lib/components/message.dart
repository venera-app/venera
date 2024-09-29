part of "components.dart";

class OverlayWidget extends StatefulWidget {
  const OverlayWidget(this.child, {super.key});

  final Widget child;

  @override
  State<OverlayWidget> createState() => OverlayWidgetState();
}

class OverlayWidgetState extends State<OverlayWidget> {
  final overlayKey = GlobalKey<OverlayState>();

  var entries = <OverlayEntry>[];

  void addOverlay(OverlayEntry entry) {
    if (overlayKey.currentState != null) {
      overlayKey.currentState!.insert(entry);
      entries.add(entry);
    }
  }

  void remove(OverlayEntry entry) {
    if (entries.remove(entry)) {
      entry.remove();
    }
  }

  void removeAll() {
    for (var entry in entries) {
      entry.remove();
    }
    entries.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: overlayKey,
      initialEntries: [OverlayEntry(builder: (context) => widget.child)],
    );
  }
}

void showDialogMessage(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: context.pop,
          child: Text("OK".tl),
        )
      ],
    ),
  );
}

void showConfirmDialog(BuildContext context, String title, String content,
    void Function() onConfirm) {
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: context.pop, child: Text("Cancel".tl)),
              TextButton(
                  onPressed: () {
                    context.pop();
                    onConfirm();
                  },
                  child: Text("Confirm".tl)),
            ],
          ));
}

class LoadingDialogController {
  void Function()? closeDialog;

  bool closed = false;

  void close() {
    if (closed) {
      return;
    }
    closed = true;
    if (closeDialog == null) {
      Future.microtask(closeDialog!);
    } else {
      closeDialog!();
    }
  }
}

LoadingDialogController showLoadingDialog(BuildContext context,
    {void Function()? onCancel,
    bool barrierDismissible = true,
    bool allowCancel = true,
    String? message,
    String cancelButtonText = "Cancel"}) {
  var controller = LoadingDialogController();

  var loadingDialogRoute = DialogRoute(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 100,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(
                  width: 16,
                ),
                Text(
                  message ?? 'Loading',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                if (allowCancel)
                  TextButton(
                      onPressed: () {
                        controller.close();
                        onCancel?.call();
                      },
                      child: Text(cancelButtonText.tl))
              ],
            ),
          ),
        );
      });

  var navigator = Navigator.of(context);

  navigator.push(loadingDialogRoute).then((value) => controller.closed = true);

  controller.closeDialog = () {
    navigator.removeRoute(loadingDialogRoute);
  };

  return controller;
}

class ContentDialog extends StatelessWidget {
  const ContentDialog({
    super.key,
    required this.title,
    required this.content,
    this.dismissible = true,
    this.actions = const [],
  });

  final String title;

  final Widget content;

  final List<Widget> actions;

  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    var content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Appbar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: dismissible ? context.pop : null,
          ),
          title: Text(title),
          backgroundColor: Colors.transparent,
        ),
        this.content,
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: actions,
        ).paddingRight(12),
        const SizedBox(height: 16),
      ],
    );
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      insetPadding: context.width < 400
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            minWidth: math.min(400, context.width - 16),
          ),
          child: MediaQuery.removePadding(
            removeTop: true,
            removeBottom: true,
            context: context,
            child: content,
          ),
        ),
      ),
    );
  }
}
