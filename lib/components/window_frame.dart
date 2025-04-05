import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:window_manager/window_manager.dart';

const _kTitleBarHeight = 36.0;

class WindowFrameController extends InheritedWidget {
  /// Whether the window frame is hidden.
  final bool isWindowFrameHidden;

  /// Sets the visibility of the window frame.
  final void Function(bool) setWindowFrame;

  /// Adds a listener that will be called when close button is clicked.
  /// The listener should return `true` to allow the window to be closed.
  final void Function(WindowCloseListener listener) addCloseListener;

  /// Removes a close listener.
  final void Function(WindowCloseListener listener) removeCloseListener;

  const WindowFrameController._create({
    required this.isWindowFrameHidden,
    required this.setWindowFrame,
    required this.addCloseListener,
    required this.removeCloseListener,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

class WindowFrame extends StatefulWidget {
  const WindowFrame(this.child, {super.key});

  final Widget child;

  @override
  State<WindowFrame> createState() => _WindowFrameState();

  static WindowFrameController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowFrameController>()!;
  }
}

typedef WindowCloseListener = bool Function();

class _WindowFrameState extends State<WindowFrame> {
  bool isWindowFrameHidden = false;
  bool useDarkTheme = false;
  var closeListeners = <WindowCloseListener>[];

  /// Sets the visibility of the window frame.
  void setWindowFrame(bool show) {
    setState(() {
      isWindowFrameHidden = !show;
    });
  }

  /// Adds a listener that will be called when close button is clicked.
  /// The listener should return `true` to allow the window to be closed.
  void addCloseListener(WindowCloseListener listener) {
    closeListeners.add(listener);
  }

  /// Removes a close listener.
  void removeCloseListener(WindowCloseListener listener) {
    closeListeners.remove(listener);
  }

  void _onClose() {
    for (var listener in closeListeners) {
      if (!listener()) {
        return;
      }
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    if (App.isMobile) return widget.child;

    Widget body = Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: isWindowFrameHidden
                  ? null
                  : const EdgeInsets.only(top: _kTitleBarHeight),
            ),
            child: widget.child,
          ),
        ),
        if (!isWindowFrameHidden)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(context).copyWith(
                  brightness: useDarkTheme ? Brightness.dark : null,
                ),
                child: Builder(builder: (context) {
                  return SizedBox(
                    height: _kTitleBarHeight,
                    child: Row(
                      children: [
                        if (App.isMacOS)
                          const DragToMoveArea(
                            child: SizedBox(
                              height: double.infinity,
                              width: 16,
                            ),
                          ).paddingRight(52)
                        else
                          const SizedBox(width: 12),
                        Expanded(
                          child: DragToMoveArea(
                            child: Text(
                              'Venera',
                              style: TextStyle(
                                fontSize: 13,
                                color: (useDarkTheme ||
                                        context.brightness == Brightness.dark)
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            )
                                .toAlign(Alignment.centerLeft)
                                .paddingLeft(4 + (App.isMacOS ? 25 : 0)),
                          ),
                        ),
                        if (kDebugMode)
                          const TextButton(
                            onPressed: debug,
                            child: Text('Debug'),
                          ),
                        if (!App.isMacOS)
                          _WindowButtons(
                            onClose: _onClose,
                          )
                      ],
                    ),
                  );
                }),
              ),
            ),
          )
      ],
    );

    if (App.isLinux) {
      body = VirtualWindowFrame(child: body);
    }

    return WindowFrameController._create(
      isWindowFrameHidden: isWindowFrameHidden,
      setWindowFrame: setWindowFrame,
      addCloseListener: addCloseListener,
      removeCloseListener: removeCloseListener,
      child: body,
    );
  }
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons({required this.onClose});

  final void Function() onClose;

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool isMaximized = false;

  @override
  void initState() {
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (value) {
        setState(() {
          isMaximized = true;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {
      isMaximized = true;
    });
    super.onWindowMaximize();
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      isMaximized = false;
    });
    super.onWindowUnmaximize();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? Colors.white : Colors.black;
    final hoverColor = dark ? Colors.white30 : Colors.black12;

    return SizedBox(
      width: 138,
      height: _kTitleBarHeight,
      child: Row(
        children: [
          WindowButton(
            icon: MinimizeIcon(color: color),
            hoverColor: hoverColor,
            onPressed: () async {
              bool isMinimized = await windowManager.isMinimized();
              if (isMinimized) {
                windowManager.restore();
              } else {
                windowManager.minimize();
              }
            },
          ),
          if (isMaximized)
            WindowButton(
              icon: RestoreIcon(
                color: color,
              ),
              hoverColor: hoverColor,
              onPressed: () {
                windowManager.unmaximize();
              },
            )
          else
            WindowButton(
              icon: MaximizeIcon(
                color: color,
              ),
              hoverColor: hoverColor,
              onPressed: () {
                windowManager.maximize();
              },
            ),
          WindowButton(
            icon: CloseIcon(
              color: color,
            ),
            hoverIcon: CloseIcon(
              color: !dark ? Colors.white : Colors.black,
            ),
            hoverColor: Colors.red,
            onPressed: widget.onClose,
          )
        ],
      ),
    );
  }
}

class WindowButton extends StatefulWidget {
  const WindowButton(
      {required this.icon,
      required this.onPressed,
      required this.hoverColor,
      this.hoverIcon,
      super.key});

  final Widget icon;

  final void Function() onPressed;

  final Color hoverColor;

  final Widget? hoverIcon;

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() {
        isHovering = true;
      }),
      onExit: (event) => setState(() {
        isHovering = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: double.infinity,
          decoration:
              BoxDecoration(color: isHovering ? widget.hoverColor : null),
          child: isHovering ? widget.hoverIcon ?? widget.icon : widget.icon,
        ),
      ),
    );
  }
}

/// Close
class CloseIcon extends StatelessWidget {
  final Color color;

  const CloseIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_ClosePainter(color));
}

class _ClosePainter extends _IconPainter {
  _ClosePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color, true);
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), p);
  }
}

/// Maximize
class MaximizeIcon extends StatelessWidget {
  final Color color;

  const MaximizeIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_MaximizePainter(color));
}

class _MaximizePainter extends _IconPainter {
  _MaximizePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width - 1, size.height - 1), p);
  }
}

/// Restore
class RestoreIcon extends StatelessWidget {
  final Color color;

  const RestoreIcon({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => _AlignedPaint(_RestorePainter(color));
}

class _RestorePainter extends _IconPainter {
  _RestorePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawRect(Rect.fromLTRB(0, 2, size.width - 2, size.height), p);
    canvas.drawLine(const Offset(2, 2), const Offset(2, 0), p);
    canvas.drawLine(const Offset(2, 0), Offset(size.width, 0), p);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, size.height - 2), p);
    canvas.drawLine(Offset(size.width, size.height - 2),
        Offset(size.width - 2, size.height - 2), p);
  }
}

/// Minimize
class MinimizeIcon extends StatelessWidget {
  final Color color;

  const MinimizeIcon({super.key, required this.color});

  @override
  Widget build(BuildContext context) => _AlignedPaint(_MinimizePainter(color));
}

class _MinimizePainter extends _IconPainter {
  _MinimizePainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = getPaint(color);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
  }
}

/// Helpers
abstract class _IconPainter extends CustomPainter {
  _IconPainter(this.color);

  final Color color;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlignedPaint extends StatelessWidget {
  const _AlignedPaint(this.painter);

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.center,
        child: CustomPaint(size: const Size(10, 10), painter: painter));
  }
}

Paint getPaint(Color color, [bool isAntiAlias = false]) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..isAntiAlias = isAntiAlias
  ..strokeWidth = 1;

class WindowPlacement {
  final Rect rect;

  final bool isMaximized;

  const WindowPlacement(this.rect, this.isMaximized);

  Future<void> applyToWindow() async {
    await windowManager.setBounds(rect);

    if (!validate(rect)) {
      await windowManager.center();
    }

    if (isMaximized) {
      await windowManager.maximize();
    }
  }

  Future<void> writeToFile() async {
    var file = File("${App.dataPath}/window_placement");
    await file.writeAsString(jsonEncode({
      'width': rect.width,
      'height': rect.height,
      'x': rect.topLeft.dx,
      'y': rect.topLeft.dy,
      'isMaximized': isMaximized
    }));
  }

  static Future<WindowPlacement> loadFromFile() async {
    try {
      var file = File("${App.dataPath}/window_placement");
      if (!file.existsSync()) {
        return defaultPlacement;
      }
      var json = jsonDecode(await file.readAsString());
      var rect =
          Rect.fromLTWH(json['x'], json['y'], json['width'], json['height']);
      return WindowPlacement(rect, json['isMaximized']);
    } catch (e) {
      return defaultPlacement;
    }
  }

  static Rect? lastValidRect;

  static Future<WindowPlacement> get current async {
    var rect = await windowManager.getBounds();
    if (validate(rect)) {
      lastValidRect = rect;
    } else {
      rect = lastValidRect ?? defaultPlacement.rect;
    }
    var isMaximized = await windowManager.isMaximized();
    return WindowPlacement(rect, isMaximized);
  }

  static const defaultPlacement =
      WindowPlacement(Rect.fromLTWH(10, 10, 900, 600), false);

  static WindowPlacement cache = defaultPlacement;

  static Timer? timer;

  static void loop() async {
    timer ??= Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      var placement = await WindowPlacement.current;
      if (placement.rect != cache.rect ||
          placement.isMaximized != cache.isMaximized) {
        cache = placement;
        await placement.writeToFile();
      }
    });
  }

  static bool validate(Rect rect) {
    return rect.topLeft.dx >= 0 && rect.topLeft.dy >= 0;
  }
}

class VirtualWindowFrame extends StatefulWidget {
  const VirtualWindowFrame({
    super.key,
    required this.child,
  });

  /// The [child] contained by the VirtualWindowFrame.
  final Widget child;

  @override
  State<StatefulWidget> createState() => _VirtualWindowFrameState();
}

class _VirtualWindowFrameState extends State<VirtualWindowFrame>
    with WindowListener {
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Widget _buildVirtualWindowFrame(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_isMaximized ? 0 : 8),
        color: Colors.transparent,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.toOpacity(_isFocused ? 0.4 : 0.2),
            blurRadius: 4,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragToResizeArea(
      enableResizeEdges: (_isMaximized || _isFullScreen) ? [] : null,
      child: Padding(
        padding: EdgeInsets.all(_isMaximized ? 0 : 4),
        child: _buildVirtualWindowFrame(context),
      ),
    );
  }

  @override
  void onWindowFocus() {
    setState(() {
      _isFocused = true;
    });
  }

  @override
  void onWindowBlur() {
    setState(() {
      _isFocused = false;
    });
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }
}

// ignore: non_constant_identifier_names
TransitionBuilder VirtualWindowFrameInit() {
  return (_, Widget? child) {
    return VirtualWindowFrame(
      child: child!,
    );
  };
}

void debug() {
  ComicSourceManager().reload();
}
