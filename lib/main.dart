import 'dart:async';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rhttp/rhttp.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/auth_page.dart';
import 'package:venera/pages/main_page.dart';
import 'package:venera/utils/app_links.dart';
import 'package:venera/utils/io.dart';
import 'package:window_manager/window_manager.dart';
import 'components/components.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'init.dart';

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  overrideIO(() {
    runZonedGuarded(() async {
      await Rhttp.init();
      WidgetsFlutterBinding.ensureInitialized();
      await init();
      if (App.isAndroid) {
        handleLinks();
      }
      FlutterError.onError = (details) {
        Log.error(
            "Unhandled Exception", "${details.exception}\n${details.stack}");
      };
      runApp(const MyApp());
      if (App.isDesktop) {
        await windowManager.ensureInitialized();
        windowManager.waitUntilReadyToShow().then((_) async {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: App.isMacOS,
          );
          if (App.isLinux) {
            await windowManager.setBackgroundColor(Colors.transparent);
          }
          await windowManager.setMinimumSize(const Size(500, 600));
          if (!App.isLinux) {
            // https://github.com/leanflutter/window_manager/issues/460
            var placement = await WindowPlacement.loadFromFile();
            await placement.applyToWindow();
            await windowManager.show();
            WindowPlacement.loop();
          }
        });
      }
    }, (error, stack) {
      Log.error("Unhandled Exception", "$error\n$stack");
    });
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    App.registerForceRebuild(forceRebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  bool isAuthPageActive = false;

  OverlayEntry? hideContentOverlay;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!App.isMobile || !appdata.settings['authorizationRequired']) {
      return;
    }
    if (state == AppLifecycleState.inactive && hideContentOverlay == null) {
      hideContentOverlay = OverlayEntry(
        builder: (context) {
          return Positioned.fill(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: App.rootContext.colorScheme.surface,
            ),
          );
        },
      );
      Overlay.of(App.rootContext).insert(hideContentOverlay!);
    } else if (hideContentOverlay != null &&
        state == AppLifecycleState.resumed) {
      hideContentOverlay!.remove();
      hideContentOverlay = null;
    }
    if (state == AppLifecycleState.hidden &&
        !isAuthPageActive &&
        !IO.isSelectingFiles) {
      isAuthPageActive = true;
      App.rootContext.to(
        () => AuthPage(
          onSuccessfulAuth: () {
            App.rootContext.pop();
            isAuthPageActive = false;
          },
        ),
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  void forceRebuild() {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (appdata.settings['authorizationRequired']) {
      home = AuthPage(
        onSuccessfulAuth: () {
          App.rootContext.toReplacement(() => const MainPage());
        },
      );
    } else {
      home = const MainPage();
    }
    return MaterialApp(
      home: home,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: App.mainColor,
          surface: Colors.white,
          primary: App.mainColor.shade600,
          // ignore: deprecated_member_use
          background: Colors.white,
        ),
        fontFamily: App.isWindows ? "Microsoft YaHei" : null,
      ),
      navigatorKey: App.rootNavigatorKey,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: App.mainColor,
          brightness: Brightness.dark,
          surface: Colors.black,
          primary: App.mainColor.shade400,
          // ignore: deprecated_member_use
          background: Colors.black,
        ),
        fontFamily: App.isWindows ? "Microsoft YaHei" : null,
      ),
      themeMode: switch (appdata.settings['theme_mode']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: () {
        var lang = appdata.settings['language'];
        if (lang == 'system') {
          return null;
        }
        return switch (lang) {
          'zh-CN' => const Locale('zh', 'CN'),
          'zh-TW' => const Locale('zh', 'TW'),
          'en-US' => const Locale('en'),
          _ => null
        };
      }(),
      supportedLocales: const [
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      builder: (context, widget) {
        ErrorWidget.builder = (details) {
          Log.error(
              "Unhandled Exception", "${details.exception}\n${details.stack}");
          return Material(
            child: Center(
              child: Text(details.exception.toString()),
            ),
          );
        };
        if (widget != null) {
          widget = OverlayWidget(widget);
          if (App.isDesktop) {
            widget = Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.escape): VoidCallbackIntent(
                  App.pop,
                ),
              },
              child: MouseBackDetector(
                onTapDown: App.pop,
                child: WindowFrame(widget),
              ),
            );
          }
          return _SystemUiProvider(Material(
            child: widget,
          ));
        }
        throw ('widget is null');
      },
    );
  }
}

class _SystemUiProvider extends StatelessWidget {
  const _SystemUiProvider(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    SystemUiOverlayStyle systemUiStyle;
    if (brightness == Brightness.light) {
      systemUiStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}
