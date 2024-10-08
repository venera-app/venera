import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/main_page.dart';
import 'package:window_manager/window_manager.dart';
import 'components/components.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'init.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await init();
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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    App.registerForceRebuild(forceRebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.initState();
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
    return MaterialApp(
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: App.mainColor,
          surface: Colors.white,
          primary: App.mainColor.shade600,
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
              child: WindowFrame(widget),
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
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}
