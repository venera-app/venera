import "package:flutter/material.dart";
import "package:venera/components/components.dart";
import "package:venera/foundation/app.dart";
import "package:venera/foundation/comic_source/comic_source.dart";
import "package:venera/utils/translations.dart";

class CategoryComicsPage extends StatefulWidget {
  const CategoryComicsPage({
    required this.category,
    this.param,
    required this.categoryKey,
    super.key,
  });

  final String category;

  final String? param;

  final String categoryKey;

  @override
  State<CategoryComicsPage> createState() => _CategoryComicsPageState();
}

class _CategoryComicsPageState extends State<CategoryComicsPage> {
  late final CategoryComicsData data;
  late final List<CategoryComicsOptions> options;
  late List<String> optionsValue;
  late String sourceKey;

  void findData() {
    for (final source in ComicSource.all()) {
      if (source.categoryData?.key == widget.categoryKey) {
        data = source.categoryComicsData!;
        options = data.options.where((element) {
          if (element.notShowWhen.contains(widget.category)) {
            return false;
          } else if (element.showWhen != null) {
            return element.showWhen!.contains(widget.category);
          }
          return true;
        }).toList();
        optionsValue = options.map((e) => e.options.keys.first).toList();
        sourceKey = source.key;
        return;
      }
    }
    throw "${widget.categoryKey} Not found";
  }

  @override
  void initState() {
    findData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var topPadding = context.padding.top + 56.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Appbar(
        title: Text(widget.category),
      ),
      body: ComicList(
        key: Key(widget.category + optionsValue.toString()),
        errorLeading: SizedBox(height: topPadding),
        leadingSliver: buildOptions().paddingTop(topPadding).toSliver(),
        loadPage: (i) => data.load(
          widget.category,
          widget.param,
          optionsValue,
          i,
        ),
      ),
    );
  }

  Widget buildOptionItem(
      String text, String value, int group, BuildContext context) {
    return OptionChip(
      text: text.ts(sourceKey),
      isSelected: value == optionsValue[group],
      onTap: () {
        if (value == optionsValue[group]) return;
        setState(() {
          optionsValue[group] = value;
        });
      },
    );
  }

  Widget buildOptions() {
    List<Widget> children = [];
    for (var optionList in options) {
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var option in optionList.options.entries)
            buildOptionItem(
              option.value.tl,
              option.key,
              options.indexOf(optionList),
              context,
            )
        ],
      ));
      if (options.last != optionList) {
        children.add(const SizedBox(height: 8));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...children, const Divider()],
    ).paddingLeft(8).paddingRight(8);
  }
}
