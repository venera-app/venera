import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/foundation/state_controller.dart';
import 'package:venera/pages/search_result_page.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/translations.dart';

import 'category_comics_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<ExplorePage> {
  late TabController controller;

  bool showFB = true;

  double location = 0;

  late List<String> pages;

  void onSettingsChanged() {
    var explorePages = List<String>.from(appdata.settings["explore_pages"]);
    var all = ComicSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    explorePages = explorePages.where((e) => all.contains(e)).toList();
    if (!pages.isEqualsTo(explorePages)) {
      setState(() {
        pages = explorePages;
        controller = TabController(
          length: pages.length,
          vsync: this,
        );
      });
    }
  }

  void onNaviItemTapped(int index) {
    if (index == 2) {
      int page = controller.index;
      String currentPageId = pages[page];
      StateController.find<SimpleController>(tag: currentPageId)
          .control!()['toTop']
          ?.call();
    }
  }

  NaviPaneState? naviPane;

  @override
  void initState() {
    pages = List<String>.from(appdata.settings["explore_pages"]);
    var all = ComicSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    pages = pages.where((e) => all.contains(e)).toList();
    controller = TabController(
      length: pages.length,
      vsync: this,
    );
    appdata.settings.addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    naviPane = NaviPane.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    controller.dispose();
    appdata.settings.removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    super.dispose();
  }

  void refresh() {
    int page = controller.index;
    String currentPageId = pages[page];
    StateController.find<SimpleController>(tag: currentPageId).refresh();
  }

  Widget buildFAB() => Material(
        color: Colors.transparent,
        child: FloatingActionButton(
          key: const Key("FAB"),
          onPressed: refresh,
          child: const Icon(Icons.refresh),
        ),
      );

  Tab buildTab(String i) {
    var comicSource = ComicSource.all()
        .firstWhere((e) => e.explorePages.any((e) => e.title == i));
    return Tab(text: i.ts(comicSource.key), key: Key(i));
  }

  Widget buildBody(String i) => _SingleExplorePage(i, key: Key(i));

  Widget buildEmpty() {
    var msg = "No Explore Pages".tl;
    msg += '\n';
    if (ComicSource.isEmpty) {
      msg += "Add a comic source in home page".tl;
    } else {
      msg += "Please check your settings".tl;
    }
    return NetworkError(
      message: msg,
      retry: () {
        setState(() {
          pages = ComicSource.all()
              .map((e) => e.explorePages)
              .expand((e) => e.map((e) => e.title))
              .toList();
          controller = TabController(
            length: pages.length,
            vsync: this,
          );
        });
      },
      withAppbar: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (pages.isEmpty) {
      return buildEmpty();
    }

    Widget tabBar = Material(
      child: FilledTabBar(
        key: Key(pages.toString()),
        tabs: pages.map((e) => buildTab(e)).toList(),
        controller: controller,
      ),
    ).paddingTop(context.padding.top);

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              tabBar,
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notifications) {
                    if (notifications.metrics.axis == Axis.horizontal) {
                      if (!showFB) {
                        setState(() {
                          showFB = true;
                        });
                      }
                      return true;
                    }

                    var current = notifications.metrics.pixels;
                    var overflow = notifications.metrics.outOfRange;
                    if (current > location && current != 0 && showFB) {
                      setState(() {
                        showFB = false;
                      });
                    } else if ((current < location - 50 || current == 0) &&
                        !showFB) {
                      setState(() {
                        showFB = true;
                      });
                    }
                    if ((current > location || current < location - 50) &&
                        !overflow) {
                      location = current;
                    }
                    return false;
                  },
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: TabBarView(
                      controller: controller,
                      children: pages.map((e) => buildBody(e)).toList(),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            reverseDuration: const Duration(milliseconds: 150),
            child: showFB ? buildFAB() : const SizedBox(),
            transitionBuilder: (widget, animation) {
              var tween = Tween<Offset>(
                  begin: const Offset(0, 1), end: const Offset(0, 0));
              return SlideTransition(
                position: tween.animate(animation),
                child: widget,
              );
            },
          ),
        )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(this.title, {super.key});

  final String title;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends StateWithController<_SingleExplorePage>
    with AutomaticKeepAliveClientMixin<_SingleExplorePage> {
  late final ExplorePageData data;

  bool loading = true;

  String? message;

  List<ExplorePagePart>? parts;

  late final String comicSourceKey;

  int key = 0;

  bool _wantKeepAlive = true;

  var scrollController = ScrollController();

  void onSettingsChanged() {
    var explorePages = appdata.settings["explore_pages"];
    if (!explorePages.contains(widget.title)) {
      _wantKeepAlive = false;
      updateKeepAlive();
    }
  }

  @override
  void initState() {
    super.initState();
    for (var source in ComicSource.all()) {
      for (var d in source.explorePages) {
        if (d.title == widget.title) {
          data = d;
          comicSourceKey = source.key;
          return;
        }
      }
    }
    appdata.settings.addListener(onSettingsChanged);
    throw "Explore Page ${widget.title} Not Found!";
  }

  @override
  void dispose() {
    appdata.settings.removeListener(onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (data.loadMultiPart != null) {
      return buildMultiPart();
    } else if (data.loadPage != null || data.loadNext != null) {
      return buildComicList();
    } else if (data.loadMixed != null) {
      return _MixedExplorePage(
        data,
        comicSourceKey,
        key: ValueKey(key),
        controller: scrollController,
      );
    } else {
      return const Center(
        child: Text("Empty Page"),
      );
    }
  }

  Widget buildComicList() {
    return ComicList(
      loadPage: data.loadPage,
      loadNext: data.loadNext,
      key: ValueKey(key),
      controller: scrollController,
    );
  }

  void load() async {
    var res = await data.loadMultiPart!();
    loading = false;
    if (mounted) {
      setState(() {
        if (res.error) {
          message = res.errorMessage;
        } else {
          parts = res.data;
        }
      });
    }
  }

  Widget buildMultiPart() {
    if (loading) {
      load();
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (message != null) {
      return NetworkError(
        message: message!,
        retry: refresh,
        withAppbar: false,
      );
    } else {
      return buildPage();
    }
  }

  Widget buildPage() {
    return SmoothCustomScrollView(
      controller: scrollController,
      slivers: _buildPage().toList(),
    );
  }

  Iterable<Widget> _buildPage() sync* {
    for (var part in parts!) {
      yield* _buildExplorePagePart(part, comicSourceKey);
    }
  }

  @override
  Object? get tag => widget.title;

  @override
  void refresh() {
    message = null;
    if (data.loadMultiPart != null) {
      setState(() {
        loading = true;
      });
    } else {
      setState(() {
        key++;
      });
    }
  }

  @override
  bool get wantKeepAlive => _wantKeepAlive;

  void toTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Map<String, dynamic> get control => {"toTop": toTop};
}

class _MixedExplorePage extends StatefulWidget {
  const _MixedExplorePage(this.data, this.sourceKey, {super.key, this.controller});

  final ExplorePageData data;

  final String sourceKey;

  final ScrollController? controller;

  @override
  State<_MixedExplorePage> createState() => _MixedExplorePageState();
}

class _MixedExplorePageState
    extends MultiPageLoadingState<_MixedExplorePage, Object> {
  Iterable<Widget> buildSlivers(BuildContext context, List<Object> data) sync* {
    List<Comic> cache = [];
    for (var part in data) {
      if (part is ExplorePagePart) {
        if (cache.isNotEmpty) {
          yield SliverGridComics(
            comics: (cache),
          );
          yield const SliverToBoxAdapter(child: Divider());
          cache.clear();
        }
        yield* _buildExplorePagePart(part, widget.sourceKey);
        yield const SliverToBoxAdapter(child: Divider());
      } else {
        cache.addAll(part as List<Comic>);
      }
    }
    if (cache.isNotEmpty) {
      yield SliverGridComics(
        comics: (cache),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context, List<Object> data) {
    return SmoothCustomScrollView(
      controller: widget.controller,
      slivers: [
        ...buildSlivers(context, data),
        if (haveNextPage) const ListLoadingIndicator().toSliver()
      ],
    );
  }

  @override
  Future<Res<List<Object>>> loadData(int page) async {
    var res = await widget.data.loadMixed!(page);
    if (res.error) {
      return res;
    }
    for (var element in res.data) {
      if (element is! ExplorePagePart && element is! List<Comic>) {
        return const Res.error("function loadMixed return invalid data");
      }
    }
    return res;
  }
}

Iterable<Widget> _buildExplorePagePart(
    ExplorePagePart part, String sourceKey) sync* {
  Widget buildTitle(ExplorePagePart part) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
          child: Row(
            children: [
              Text(
                part.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (part.viewMore != null)
                TextButton(
                  onPressed: () {
                    var context = App.mainNavigatorKey!.currentContext!;
                    if (part.viewMore!.startsWith("search:")) {
                      context.to(
                        () => SearchResultPage(
                          text: part.viewMore!.replaceFirst("search:", ""),
                          options: const [],
                          sourceKey: sourceKey,
                        ),
                      );
                    } else if (part.viewMore!.startsWith("category:")) {
                      var cp = part.viewMore!.replaceFirst("category:", "");
                      var c = cp.split('@').first;
                      String? p = cp.split('@').last;
                      if (p == c) {
                        p = null;
                      }
                      context.to(
                        () => CategoryComicsPage(
                          category: c,
                          categoryKey:
                              ComicSource.find(sourceKey)!.categoryData!.key,
                          param: p,
                        ),
                      );
                    }
                  },
                  child: Text("View more".tl),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildComics(ExplorePagePart part) {
    return SliverGridComics(comics: part.comics);
  }

  yield buildTitle(part);
  yield buildComics(part);
}
