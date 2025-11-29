import 'dart:math';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:venera/foundation/app.dart';

const double _kBackGestureWidth = 20.0;
const int _kMaxDroppedSwipePageForwardAnimationTime = 800;
const int _kMaxPageBackAnimationTime = 300;
const double _kMinFlingVelocity = 1.0;

class AppPageRoute<T> extends PageRoute<T> with _AppRouteTransitionMixin{
  /// Construct a MaterialPageRoute whose contents are defined by [builder].
  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
    this.enableIOSGesture = true,
    this.preventRebuild = true,
  }) {
    assert(opaque);
  }

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  String? label;

  @override
  toString() => "/$label";

  @override
  Widget buildContent(BuildContext context) {
    var widget = builder(context);
    label = widget.runtimeType.toString();
    return widget;
  }

  @override
  final bool maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  final bool enableIOSGesture;

  @override
  final bool preventRebuild;
}

mixin _AppRouteTransitionMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Don't perform outgoing animation if the next route is a fullscreen dialog.
    return nextRoute is PageRoute && !nextRoute.fullscreenDialog;
  }

  bool get enableIOSGesture;

  bool get preventRebuild;

  Widget? _child;

  @override
  Widget buildPage(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      ) {
    Widget result;

    if(preventRebuild){
      result = _child ?? (_child = buildContent(context));
    } else {
      result = buildContent(context);
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: result,
    );
  }

  static bool _isPopGestureEnabled<T>(PageRoute<T> route) {
    if (route.isFirst ||
        route.willHandlePopInternally ||
        route.popDisposition == RoutePopDisposition.doNotPop ||
        route.fullscreenDialog ||
        route.animation!.status != AnimationStatus.completed ||
        route.secondaryAnimation!.status != AnimationStatus.dismissed ||
        !route.popGestureEnabled ||
        route.navigator!.userGestureInProgress) {
      return false;
    }

    return true;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    PageTransitionsBuilder builder;
    if (App.isAndroid) {
      builder = PredictiveBackPageTransitionsBuilder();
    } else {
      builder = SlidePageTransitionBuilder();
  }

  return builder.buildTransitions(
        this,
        context,
        animation,
        secondaryAnimation,
    enableIOSGesture && App.isIOS
      ? IOSBackGestureDetector(
        gestureWidth: _kBackGestureWidth,
        enabledCallback: () => _isPopGestureEnabled<T>(this),
        onStartPopGesture: () => _startPopGesture(this),
        child: child,
        )
      : child);
  }

  IOSBackGestureController _startPopGesture(PageRoute<T> route) {
    return IOSBackGestureController(route.controller!, route.navigator!);
  }
}

class IOSBackGestureController {
  final AnimationController controller;

  final NavigatorState navigator;

  IOSBackGestureController(this.controller, this.navigator) {
    navigator.didStartUserGesture();
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.fastLinearToSlowEaseIn;
    final bool animateForward;

    if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      final droppedPageForwardAnimationTime = min(
        lerpDouble(
                _kMaxDroppedSwipePageForwardAnimationTime, 0, controller.value)!
            .floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(1.0,
          duration: Duration(milliseconds: droppedPageForwardAnimationTime),
          curve: animationCurve);
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final droppedPageBackAnimationTime = lerpDouble(
                0, _kMaxDroppedSwipePageForwardAnimationTime, controller.value)!
            .floor();
        controller.animateBack(0.0,
            duration: Duration(milliseconds: droppedPageBackAnimationTime),
            curve: animationCurve);
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }

  void dragUpdate(double delta) {
    controller.value -= delta;
  }
}

class IOSBackGestureDetector extends StatefulWidget {
  const IOSBackGestureDetector({
    required this.enabledCallback,
    required this.child,
    required this.gestureWidth,
    required this.onStartPopGesture,
    super.key,
  });

  final double gestureWidth;
  final bool Function() enabledCallback;
  final IOSBackGestureController Function() onStartPopGesture;
  final Widget child;

  @override
  State<IOSBackGestureDetector> createState() => _IOSBackGestureDetectorState();
}

class _IOSBackGestureDetectorState extends State<IOSBackGestureDetector> {
  IOSBackGestureController? _backGestureController;
  late _BackSwipeRecognizer _recognizer;


  @override
  void initState() {
    super.initState();
    _recognizer = _BackSwipeRecognizer(
      debugOwner: this,
      gestureWidth: widget.gestureWidth,
      isPointerInHorizontal: _isPointerInHorizontalScrollable,
      onStart: _handleDragStart,
      onUpdate: _handleDragUpdate,
      onEnd: _handleDragEnd,
      onCancel: _handleDragCancel,
    );
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _BackSwipeRecognizer: GestureRecognizerFactoryWithHandlers<_BackSwipeRecognizer>(
          () => _recognizer,
          (instance) {
            instance.gestureWidth = widget.gestureWidth;
          },
        ),
      },
      child: widget.child,
    );
  }

  bool _isPointerInHorizontalScrollable(Offset globalPosition) {
    final HitTestResult result = HitTestResult();
    final binding = WidgetsBinding.instance;
    binding.hitTestInView(result, globalPosition, binding.platformDispatcher.implicitView!.viewId);

    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderViewport) {
        if (target.axisDirection == AxisDirection.left || 
            target.axisDirection == AxisDirection.right) {
          return true;
        }
      } 
      else if (target is RenderSliver) {
         if (target.constraints.axisDirection == AxisDirection.left || 
             target.constraints.axisDirection == AxisDirection.right) {
          return true;
        }
      }
      else if (target.runtimeType.toString() == '_RenderSingleChildViewport') {
        try {
          final dynamic renderObject = target;
          if (renderObject.axis == Axis.horizontal) {
            return true;
          }
        } catch (e) {
          // protected
        }
      }
      else if (target is RenderEditable) {
         return true;
      }
    }
    return false;
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enabledCallback()) return;
    if (mounted && _backGestureController == null) {
      _backGestureController = widget.onStartPopGesture();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (mounted && _backGestureController != null) {
      _backGestureController!.dragUpdate(
          _convertToLogical(details.primaryDelta! / context.size!.width));
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (mounted && _backGestureController != null) {
      _backGestureController!.dragEnd(_convertToLogical(
          details.velocity.pixelsPerSecond.dx / context.size!.width));
      _backGestureController = null;
    }
  }

  void _handleDragCancel() {
    if (mounted && _backGestureController != null) {
      _backGestureController?.dragEnd(0.0);
      _backGestureController = null;
    }
  }

  double _convertToLogical(double value) {
    switch (Directionality.of(context)) {
      case TextDirection.rtl: return -value;
      case TextDirection.ltr: return value;
    }
  }
}

class _BackSwipeRecognizer extends OneSequenceGestureRecognizer {
  _BackSwipeRecognizer({
    required this.isPointerInHorizontal,
    required this.gestureWidth,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    super.debugOwner,
  });

  final bool Function(Offset globalPosition) isPointerInHorizontal;
  double gestureWidth;
  final ValueSetter<DragStartDetails> onStart;
  final ValueSetter<DragUpdateDetails> onUpdate;
  final ValueSetter<DragEndDetails> onEnd;
  final VoidCallback onCancel;

  Offset? _startGlobal;
  bool _accepted = false;
  bool _startedInHorizontal = false;
  bool _startedNearLeftEdge = false; 

  VelocityTracker? _velocityTracker;

  static const double _minDistance = 5.0; 

  @override
  void addPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _startGlobal = event.position;
    _accepted = false;
    
    _startedInHorizontal = isPointerInHorizontal(event.position);
    _startedNearLeftEdge = event.position.dx <= gestureWidth;

    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker?.addPosition(event.timeStamp, event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent || event is PointerUpEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
    }

    if (event is PointerMoveEvent) {
      if (_startGlobal == null) return;
      final delta = event.position - _startGlobal!;
      final dx = delta.dx;
      final dy = delta.dy.abs();

      if (!_accepted) {
        if (delta.distance < _minDistance) return;

        final isRight = dx > 0;
        final isHorizontal = dx.abs() > dy * 1.5;
        final bool eligible = _startedNearLeftEdge || (!_startedInHorizontal);

        if (isRight && isHorizontal && eligible) {
          _accepted = true;
          resolve(GestureDisposition.accepted);
          onStart(DragStartDetails(
            globalPosition: _startGlobal!, 
            localPosition: event.localPosition
          ));
        } else {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);
          _startGlobal = null;
          _velocityTracker = null;
        }
      }

      if (_accepted) {
        onUpdate(DragUpdateDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          primaryDelta: event.delta.dx,
          delta: event.delta,
        ));
      }
    } else if (event is PointerUpEvent) {
      if (_accepted) {
        final Velocity velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
        
        onEnd(DragEndDetails(
          velocity: velocity,
          primaryVelocity: velocity.pixelsPerSecond.dx
        ));
      }
      _reset();
    } else if (event is PointerCancelEvent) {
      if (_accepted) {
        onCancel();
      }
      _reset();
    }
  }

  void _reset() {
    stopTrackingPointer(0);
    _accepted = false;
    _startGlobal = null;
    _startedInHorizontal = false;
    _startedNearLeftEdge = false;
    _velocityTracker = null;
  }

  @override
  String get debugDescription => 'IOSBackSwipe';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

class SlidePageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    final Animation<double> primaryAnimation = App.isIOS
        ? animation
        : CurvedAnimation(parent: animation, curve: Curves.ease);
    final Animation<double> secondaryCurve = App.isIOS
        ? secondaryAnimation
        : CurvedAnimation(parent: secondaryAnimation, curve: Curves.ease);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(primaryAnimation),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.4, 0),
        ).animate(secondaryCurve),
        child: PhysicalModel(
          color: Colors.transparent,
          borderRadius: BorderRadius.zero,
          clipBehavior: Clip.hardEdge,
          elevation: 6,
          child: Material(child: child),
        ),
      ),
    );
  }
}