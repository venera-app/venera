import "package:flutter/material.dart";
import "package:venera/components/components.dart";
import "package:venera/foundation/app.dart";
import "package:venera/foundation/comic_source/comic_source.dart";
import "package:venera/utils/translations.dart";

class RankingPage extends StatefulWidget {
  const RankingPage({required this.sourceKey, super.key});

  final String sourceKey;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late final CategoryComicsData data;
  late final Map<String, String> options;
  late String optionValue;

  void findData() {
    for (final source in ComicSource.all()) {
      if (source.categoryData?.key == widget.sourceKey) {
        data = source.categoryComicsData!;
        options = data.rankingData!.options;
        optionValue = options.keys.first;
        return;
      }
    }
    throw "${widget.sourceKey} Not found";
  }

  @override
  void initState() {
    findData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Ranking".tl),
      ),
      body: Column(
        children: [
          Expanded(
            child: ComicList(
              loadPage: (i) => data.rankingData!.load(optionValue, i),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOptionItem(String text, String value, BuildContext context) {
    return OptionChip(
      text: text,
      isSelected: value == optionValue,
      onTap: () {
        if (value == optionValue) return;
        setState(() {
          optionValue = value;
        });
      },
    );
  }

  Widget buildOptions() {
    List<Widget> children = [];
    children.add(Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var option in options.entries)
          buildOptionItem(option.value.tl, option.key, context)
      ],
    ));
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...children, const Divider()],
      ).paddingLeft(8).paddingRight(8),
    );
  }
}
