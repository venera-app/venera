import "package:flutter/material.dart";
import "package:shimmer/shimmer.dart";
import "package:venera/components/components.dart";
import "package:venera/foundation/app.dart";
import "package:venera/foundation/comic_source/comic_source.dart";
import "package:venera/foundation/image_provider/cached_image.dart";
import "package:venera/pages/search_result_page.dart";
import "package:venera/utils/translations.dart";

import "comic_page.dart";

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage({super.key, required this.keyword});

  final String keyword;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late final List<ComicSource> sources;

  late final SearchBarController controller;

  var _keyword = "";

  @override
  void initState() {
    sources = ComicSource.all().where((e) => e.searchPageData != null).toList();
    _keyword = widget.keyword;
    controller = SearchBarController(
      currentText: widget.keyword,
      onSearch: (text) {
        setState(() {
          _keyword = text;
        });
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(slivers: [
      SliverSearchBar(controller: controller),
      SliverList(
        key: ValueKey(_keyword),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final source = sources[index];
            return _SliverSearchResult(source: source, keyword: _keyword);
          },
          childCount: sources.length,
        ),
      ),
    ]);
  }
}

class _SliverSearchResult extends StatefulWidget {
  const _SliverSearchResult({required this.source, required this.keyword});

  final ComicSource source;

  final String keyword;

  @override
  State<_SliverSearchResult> createState() => _SliverSearchResultState();
}

class _SliverSearchResultState extends State<_SliverSearchResult>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kComicHeight = 144.0;

  get _comicWidth => _kComicHeight * 0.72;

  static const _kLeftPadding = 16.0;

  List<Comic>? comics;

  void load() async {
    final data = widget.source.searchPageData!;
    var options =
        (data.searchOptions ?? []).map((e) => e.defaultValue).toList();
    if (data.loadPage != null) {
      var res = await data.loadPage!(widget.keyword, 1, options);
      if (!res.error) {
        setState(() {
          comics = res.data;
          isLoading = false;
        });
      }
    } else if (data.loadNext != null) {
      var res = await data.loadNext!(widget.keyword, null, options);
      if (!res.error) {
        setState(() {
          comics = res.data;
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Widget buildPlaceHolder() {
    return Container(
      height: _kComicHeight,
      width: _comicWidth,
      margin: const EdgeInsets.only(left: _kLeftPadding),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildComic(Comic c) {
    return AnimatedTapRegion(
      borderRadius: 8,
      onTap: () {
        context.to(() => ComicPage(
          id: c.id,
          sourceKey: c.sourceKey,
        ));
      },
      child: Container(
        height: _kComicHeight,
        width: _comicWidth,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow,
        ),
        child: AnimatedImage(
          width: _comicWidth,
          height: _kComicHeight,
          fit: BoxFit.cover,
          image: CachedImageProvider(c.cover),
        ),
      ),
    ).paddingLeft(_kLeftPadding);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return InkWell(
      onTap: () {
        context.to(
          () => SearchResultPage(
            text: widget.keyword,
            sourceKey: widget.source.key,
          ),
        );
      },
      child: Column(
        children: [
          ListTile(
            mouseCursor: SystemMouseCursors.click,
            title: Text(widget.source.name),
          ),
          if (isLoading)
            SizedBox(
              height: _kComicHeight,
              width: double.infinity,
              child: Shimmer.fromColors(
                baseColor: context.colorScheme.surfaceContainerLow,
                highlightColor: context.colorScheme.surfaceContainer,
                direction: ShimmerDirection.ltr,
                child: LayoutBuilder(builder: (context, constrains) {
                  var itemWidth = _comicWidth + _kLeftPadding;
                  var items = (constrains.maxWidth / itemWidth).ceil();
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          children: List.generate(
                            items,
                            (index) => buildPlaceHolder(),
                          ),
                        ),
                      )
                    ],
                  );
                }),
              ),
            )
          else if (comics == null || comics!.isEmpty)
            SizedBox(
              height: _kComicHeight,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Text("No search results found".tl),
                    ],
                  ),
                  const Spacer(),
                ],
              ).paddingHorizontal(16),
            )
          else
            SizedBox(
              height: _kComicHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var c in comics!) buildComic(c),
                ],
              ),
            ),
        ],
      ).paddingBottom(16),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
