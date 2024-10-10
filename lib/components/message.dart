part of "components.dart";

void showToast({required String message, required BuildContext context, Widget? icon, Widget? trailing,}) {
  var newEntry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        icon: icon,
        trailing: trailing,
      ));

  var state = context.findAncestorStateOfType<OverlayWidgetState>();

  state?.addOverlay(newEntry);

  Timer(const Duration(seconds: 2), () => state?.remove(newEntry));
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({required this.message, this.icon, this.trailing});

  final String message;

  final Widget? icon;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Theme.of(context).colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          textStyle: ts.withColor(Theme.of(context).colorScheme.onInverseSurface),
          child: IconTheme(
            data: IconThemeData(color: Theme.of(context).colorScheme.onInverseSurface),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) icon!.paddingRight(8),
                  Text(
                    message,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 3,
                  ),
                  if (trailing != null) trailing!.paddingLeft(8)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
              TextButton(onPressed: context.pop, child: Text("Cancel".tl)),
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
        side: context.brightness == Brightness.dark
            ? BorderSide(color: context.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      insetPadding: context.width < 400
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shadowColor: context.colorScheme.shadow,
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
