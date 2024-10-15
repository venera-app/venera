import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/pages/search_result_page.dart';
import 'package:venera/utils/translations.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchBarController controller;

  String searchTarget = "";

  var options = <String>[];

  void update() {
    setState(() {});
  }

  void search([String? text]) {
    context.to(
      () => SearchResultPage(
        text: text ?? controller.text,
        sourceKey: searchTarget,
        options: options,
      ),
    );
  }

  @override
  void initState() {
    var defaultSearchTarget = appdata.settings['defaultSearchTarget'];
    if (defaultSearchTarget != null &&
        ComicSource.find(defaultSearchTarget) != null) {
      searchTarget = defaultSearchTarget;
    } else {
      searchTarget = ComicSource.all().first.key;
    }
    controller = SearchBarController(
      onSearch: search,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverSearchBar(controller: controller),
          buildSearchTarget(),
          buildSearchOptions(),
        ],
      ),
    );
  }

  Widget buildSearchTarget() {
    var sources =
        ComicSource.all().where((e) => e.searchPageData != null).toList();
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Search From".tl),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources.map((e) {
                return OptionChip(
                  text: e.name.tl,
                  isSelected: searchTarget == e.key,
                  onTap: () {
                    setState(() {
                      searchTarget = e.key;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSearchOptions() {
    var children = <Widget>[];

    final searchOptions =
        ComicSource.find(searchTarget)!.searchPageData!.searchOptions ??
            <SearchOptions>[];
    if (searchOptions.length != options.length) {
      options = searchOptions.map((e) => e.defaultValue).toList();
    }
    if (searchOptions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(option.label.tl),
      ));
      children.add(Wrap(
        runSpacing: 8,
        spacing: 8,
        children: option.options.entries.map((e) {
          return OptionChip(
            text: e.value.ts(searchTarget),
            isSelected: options[i] == e.key,
            onTap: () {
              options[i] = e.key;
              update();
            },
          );
        }).toList(),
      ));
    }

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget buildSearchHistory() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Search History".tl),
            );
          }
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appdata.searchHistory[index - 1]),
            onTap: () {
              search(appdata.searchHistory[index - 1]);
            },
          );
        },
        childCount: 1 + appdata.searchHistory.length,
      ),
    ).sliverPaddingHorizontal(16);
  }
}
