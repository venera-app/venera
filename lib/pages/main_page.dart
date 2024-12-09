import 'package:flutter/material.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/pages/categories_page.dart';
import 'package:venera/pages/search_page.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/translations.dart';

import '../components/components.dart';
import '../foundation/app.dart';
import 'comic_source_page.dart';
import 'explore_page.dart';
import 'favorites/favorites_page.dart';
import 'home_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final NaviObserver _observer;

  GlobalKey<NavigatorState>? _navigatorKey;

  void to(Widget Function() widget, {bool preventDuplicate = false}) async {
    if (preventDuplicate) {
      var page = widget();
      if ("/${page.runtimeType}" == _observer.routes.last.toString()) return;
    }
    _navigatorKey!.currentContext!.to(widget);
  }

  void back() {
    _navigatorKey!.currentContext!.pop();
  }

  void checkUpdates() async {
    if (!appdata.settings['checkUpdateOnStart']) {
      return;
    }
    var lastCheck = appdata.implicitData['lastCheckUpdate'] ?? 0;
    var now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCheck < 24 * 60 * 60 * 1000) {
      return;
    }
    appdata.implicitData['lastCheckUpdate'] = now;
    appdata.writeImplicitData();
    await Future.delayed(const Duration(milliseconds: 300));
    await checkUpdateUi(false);
    await ComicSourcePage.checkComicSourceUpdate(true);
  }

  @override
  void initState() {
    checkUpdates();
    _observer = NaviObserver();
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    super.initState();
  }

  final _pages = [
    const HomePage(
      key: PageStorageKey('home'),
    ),
    const FavoritesPage(
      key: PageStorageKey('favorites'),
    ),
    const ExplorePage(
      key: PageStorageKey('explore'),
    ),
    const CategoriesPage(
      key: PageStorageKey('categories'),
    ),
  ];

  var index = 0;

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: [
        PaneItemEntry(
          label: 'Home'.tl,
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
        ),
        PaneItemEntry(
          label: 'Favorites'.tl,
          icon: Icons.local_activity_outlined,
          activeIcon: Icons.local_activity,
        ),
        PaneItemEntry(
          label: 'Explore'.tl,
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore,
        ),
        PaneItemEntry(
          label: 'Categories'.tl,
          icon: Icons.category_outlined,
          activeIcon: Icons.category,
        ),
      ],
      onPageChanged: (i) {
        setState(() {
          index = i;
        });
      },
      paneActions: [
        if(index != 0)
          PaneActionEntry(
            icon: Icons.search,
            label: "Search".tl,
            onTap: () {
              to(() => const SearchPage(), preventDuplicate: true);
            },
          ),
        PaneActionEntry(
          icon: Icons.settings,
          label: "Settings".tl,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        )
      ],
      pageBuilder: (index) {
        return _pages[index];
      },
    );
  }
}
