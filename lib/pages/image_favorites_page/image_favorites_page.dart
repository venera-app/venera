import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/pages/history_page.dart';
import 'package:venera/pages/image_favorites_page/type.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/translations.dart';
part "./image_favorites_group.dart";

class ImageFavoritesPage extends StatefulWidget {
  const ImageFavoritesPage({super.key});

  @override
  State<ImageFavoritesPage> createState() => ImageFavoritesPageState();
}

class ImageFavoritesPageState extends State<ImageFavoritesPage>
    with TickerProviderStateMixin {
  late ImageFavoriteSortType sortType;

  String keyword = "";

  bool searchMode = false;

  bool multiSelectMode = false;
  late TabController controller = TabController(
    length: 2,
    vsync: this,
  );

  Map<ImageFavorite, bool> selectedComics = {};

  void update() {
    if (keyword.isEmpty) {
      setState(() {
        // comics = LocalManager().getComics(sortType);
      });
    } else {
      setState(() {
        // comics = LocalManager().search(keyword);
      });
    }
  }

  @override
  void initState() {
    var sort = appdata.implicitData["local_sort"] ?? "name";
    sortType = ImageFavoriteSortType.fromString(sort);
    // comics = LocalManager().getComics(sortType);
    // LocalManager().addListener(update);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    void selectAll() {
      setState(() {
        // selectedComics = [];
      });
    }

    void deSelect() {
      setState(() {
        selectedComics.clear();
      });
    }

    void invertSelection() {
      setState(() {
        // comics.asMap().forEach((k, v) {
        //   selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
        // });
        selectedComics.removeWhere((k, v) => !v);
      });
    }

    void selectRange() {
      setState(() {
        List<int> l = [];
        selectedComics.forEach((k, v) {
          l.add(1);
        });
        if (l.isEmpty) {
          return;
        }
        l.sort();
        int start = l.first;
        int end = l.last;
        selectedComics.clear();
        // selectedComics.addEntries(List.generate(end - start + 1, (i) {
        //   return MapEntry(comics[start + i], true);
        // }));
      });
    }

    List<Widget> selectActions = [
      IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: "Select All".tl,
          onPressed: selectAll),
      IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: "Deselect".tl,
          onPressed: deSelect),
      IconButton(
          icon: const Icon(Icons.flip),
          tooltip: "Invert Selection".tl,
          onPressed: invertSelection),
      IconButton(
          icon: const Icon(Icons.border_horizontal_outlined),
          tooltip: "Select in range".tl,
          onPressed: selectRange),
    ];
    var widget = SmoothCustomScrollView(
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppbar(
            title: Text("Local".tl),
            actions: [
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      searchMode = true;
                    });
                  },
                ),
              ),
              Tooltip(
                message: "Sort".tl,
                child: IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: sort,
                ),
              ),
              Tooltip(
                message: multiSelectMode
                    ? "Exit Multi-Select".tl
                    : "Multi-Select".tl,
                child: IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () {
                    setState(() {
                      multiSelectMode = !multiSelectMode;
                    });
                  },
                ),
              ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
                "Selected @c comics".tlParams({"c": selectedComics.length})),
            actions: selectActions,
          )
        else if (searchMode)
          SliverAppbar(
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    searchMode = false;
                    keyword = "";
                    update();
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: InputBorder.none,
              ),
              onChanged: (v) {
                keyword = v;
                update();
              },
            ),
          ),
        SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }

  void sort() {
    Widget tabBar = Material(
      child: FilledTabBar(
        tabs: ['Sort', 'Filter']
            .map((e) => Tab(text: e.tl, key: Key(e)))
            .toList(),
        controller: controller,
      ),
    ).paddingTop(context.padding.top);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            content: Container(
              // 向上移动一点, 减少 Column 顶部的 padding, 避免观感太差
              transform: Matrix4.translationValues(0, -20, 0),
              child: Column(
                children: [
                  tabBar,
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  appdata.implicitData["image_favorite_sort"] = sortType.value;
                  appdata.writeImplicitData();
                  Navigator.pop(context);
                  update();
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
  }
}
