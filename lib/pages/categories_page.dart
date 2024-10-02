import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/state_controller.dart';
import 'package:venera/pages/ranking_page.dart';
import 'package:venera/utils/translations.dart';

import 'category_comics_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StateBuilder<SimpleController>(
      tag: "category",
      init: SimpleController(),
      builder: (controller) {
        var categories = List.from(appdata.settings["categories"]);
        var allCategories = ComicSource.all()
            .map((e) => e.categoryData?.key)
            .where((element) => element != null)
            .map((e) => e!)
            .toList();
        categories = categories
            .where((element) => allCategories.contains(element))
            .toList();

        return Material(
          child: DefaultTabController(
            length: categories.length,
            key: Key(categories.toString()),
            child: Column(
              children: [
                FilledTabBar(
                  tabs: categories.map((e) {
                    String title = e;
                    try {
                      title = getCategoryDataWithKey(e).title;
                    } catch (e) {
                      //
                    }
                    return Tab(
                      text: title,
                      key: Key(e),
                    );
                  }).toList(),
                ),
                Expanded(
                  child: TabBarView(
                      children:
                          categories.map((e) => _CategoryPage(e)).toList()),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

typedef ClickTagCallback = void Function(String, String?);

class _CategoryPage extends StatelessWidget {
  const _CategoryPage(this.category);

  final String category;

  CategoryData get data => getCategoryDataWithKey(category);

  String findComicSourceKey() {
    for (var source in ComicSource.all()) {
      if (source.categoryData?.key == category) {
        return source.key;
      }
    }
    return "";
  }

  void handleClick(
    String tag,
    String? param,
    String type,
    String namespace,
    String categoryKey,
  ) {
    if (type == 'search') {
      // TODO: Implement search
      /*
      App.mainNavigatorKey?.currentContext?.to(
            () => SearchResultPage(
          keyword: tag,
          options: const [],
          sourceKey: findComicSourceKey(),
        ),
      );
       */
    } else if (type == "search_with_namespace") {
      /*
      if (tag.contains(" ")) {
        tag = '"$tag"';
      }
      App.mainNavigatorKey?.currentContext?.to(
            () => SearchResultPage(
          keyword: "$namespace:$tag",
          options: const [],
          sourceKey: findComicSourceKey(),
        ),
      );
       */
    } else if (type == "category") {
      App.mainNavigatorKey!.currentContext!.to(
        () => CategoryComicsPage(
          category: tag,
          categoryKey: categoryKey,
          param: param,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    if (data.enableRankingPage || data.buttons.isNotEmpty) {
      children.add(buildTitle(data.title));
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        child: Wrap(
          children: [
            if (data.enableRankingPage)
              buildTag("Ranking".tl, (p0, p1) {
                context.to(() => RankingPage(sourceKey: findComicSourceKey()));
              }),
            for (var buttonData in data.buttons)
              buildTag(buttonData.label.tl, (p0, p1) => buttonData.onTap())
          ],
        ),
      ));
    }

    for (var part in data.categories) {
      if (part.enableRandom) {
        children.add(StatefulBuilder(builder: (context, updater) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTitleWithRefresh(part.title, () => updater(() {})),
              buildTagsWithParams(
                part.categories,
                part.categoryParams,
                part.title,
                (key, param) => handleClick(
                  key,
                  param,
                  part.categoryType,
                  part.title,
                  category,
                ),
              )
            ],
          );
        }));
      } else {
        children.add(buildTitle(part.title));
        children.add(
          buildTagsWithParams(
            part.categories,
            part.categoryParams,
            part.title,
            (tag, param) => handleClick(
              tag,
              param,
              part.categoryType,
              part.title,
              data.key,
            ),
          ),
        );
      }
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Text(title.tl,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
    );
  }

  Widget buildTitleWithRefresh(String title, void Function() onRefresh) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Row(
        children: [
          Text(
            title.tl,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh))
        ],
      ),
    );
  }

  Widget buildTagsWithParams(
    List<String> tags,
    List<String>? params,
    String? namespace,
    ClickTagCallback onClick,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: Wrap(
        children: List<Widget>.generate(
          tags.length,
          (index) => buildTag(
            tags[index],
            onClick,
            namespace,
            params?.elementAtOrNull(index),
          ),
        ),
      ),
    );
  }

  Widget buildTag(String tag, ClickTagCallback onClick,
      [String? namespace, String? param]) {
    String translateTag(String tag) {
      /*
      // TODO: Implement translation
      if (enableTranslation) {
        if (namespace != null) {
          tag = TagsTranslation.translationTagWithNamespace(tag, namespace);
        } else {
          tag = tag.translateTagsToCN;
        }
      }

       */
      return tag;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Builder(
        builder: (context) {
          return Material(
            elevation: 0.6,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            color: context.colorScheme.surfaceContainerLow,
            surfaceTintColor: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              onTap: () => onClick(tag, param),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(translateTag(tag)),
              ),
            ),
          );
        },
      ),
    );
  }

  bool get enableTranslation => App.locale.languageCode == 'zh';
}
