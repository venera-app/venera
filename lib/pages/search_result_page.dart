import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({
    super.key,
    required this.text,
    required this.sourceKey,
    required this.options,
  });

  final String text;

  final String sourceKey;

  final List<String> options;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late SearchBarController controller;

  late String sourceKey;

  late List<String> options;

  void search([String? text]) {}

  @override
  void initState() {
    controller = SearchBarController(
      initialText: widget.text,
      onSearch: search,
    );
    sourceKey = widget.sourceKey;
    options = widget.options;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ComicList(
      errorLeading: AppSearchBar(
        controller: controller,
      ),
      leadingSliver: SliverSearchBar(
        controller: controller,
      ),
      loadPage: (i) {
        var source = ComicSource.find(sourceKey);
        return source!.searchPageData!.loadPage!(
          controller.initialText,
          i,
          options,
        );
      },
    );
  }
}
