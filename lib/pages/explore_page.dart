import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/foundation/state_controller.dart';
import 'package:venera/utils/translations.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin {
  late TabController controller;

  bool showFB = true;

  double location = 0;

  late List<String> pages;

  @override
  void initState() {
    pages = List<String>.from(appdata.settings["explore_pages"]);
    var all = ComicSource.all().map((e) => e.explorePages).expand((e) => e.map((e) => e.title)).toList();
    pages = pages.where((e) => all.contains(e)).toList();
    controller = TabController(
      length: pages.length,
      vsync: this,
    );
    super.initState();
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
    return Tab(text: i.tl, key: Key(i));
  }

  Widget buildBody(String i) => _SingleExplorePage(i, key: Key(i));

  @override
  Widget build(BuildContext context) {
    Widget tabBar = Material(
      child: FilledTabBar(
        tabs: pages.map((e) => buildTab(e)).toList(),
        controller: controller,
      ),
    );

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

                      if ((current > location && current != 0) && showFB) {
                        setState(() {
                          showFB = false;
                        });
                      } else if ((current < location || current == 0) && !showFB) {
                        setState(() {
                          showFB = true;
                        });
                      }

                      location = current;
                      return false;
                    },
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: TabBarView(
                        controller: controller,
                        children: pages
                            .map((e) => buildBody(e))
                            .toList(),
                      ),
                    ),
                  ),
                )
              ],
            )),
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
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(this.title, {super.key});

  final String title;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends StateWithController<_SingleExplorePage> {
  late final ExplorePageData data;

  bool loading = true;

  String? message;

  List<ExplorePagePart>? parts;

  late final String comicSourceKey;

  int key = 0;

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
    throw "Explore Page ${widget.title} Not Found!";
  }

  @override
  Widget build(BuildContext context) {
    if (data.loadMultiPart != null) {
      return buildMultiPart();
    } else if (data.loadPage != null) {
      return buildComicList();
    } else if (data.loadMixed != null) {
      return _MixedExplorePage(
        data,
        comicSourceKey,
        key: ValueKey(key),
      );
    } else if (data.overridePageBuilder != null) {
      return Builder(
        builder: (context) {
          return data.overridePageBuilder!(context);
        },
        key: ValueKey(key),
      );
    } else {
      return const Center(
        child: Text("Empty Page"),
      );
    }
  }

  Widget buildComicList() {
    return ComicList(
      loadPage: data.loadPage!,
      key: ValueKey(key),
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
}

class _MixedExplorePage extends StatefulWidget {
  const _MixedExplorePage(this.data, this.sourceKey, {super.key});

  final ExplorePageData data;

  final String sourceKey;

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
                    // TODO: view more
                    /*
                    var context = App.mainNavigatorKey!.currentContext!;
                    if (part.viewMore!.startsWith("search:")) {
                      context.to(
                            () => SearchResultPage(
                          keyword: part.viewMore!.replaceFirst("search:", ""),
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
                    }*/
                  },
                  child: Text("查看更多".tl),
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
