import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/image_favorites_provider.dart';
import 'package:venera/pages/comic_page.dart';
import 'package:venera/pages/image_favorites_page/type.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/translations.dart';
part "image_favorites_item.dart";

class ImageFavoritesPage extends StatefulWidget {
  const ImageFavoritesPage({super.key});

  @override
  State<ImageFavoritesPage> createState() => ImageFavoritesPageState();
}

class ImageFavoritesPageState extends State<ImageFavoritesPage>
    with TickerProviderStateMixin {
  late ImageFavoriteSortType sortType;
  late String timeFilterSelect;
  late List<String> finalTimeList;
  // 所有的图片收藏
  List<ImageFavoritesGroup> imageFavoritesGroup = [];
  late List<ImageFavoritesGroup> curImageFavoritesGroup;
  late List<DateTime> timeFilter;
  String keyword = "";

  // 进入关键词搜索模式
  bool searchMode = false;

  List<String> optionTypes = ['Sort', 'Filter'];

  bool multiSelectMode = false;
  late TabController controller = TabController(
    length: 2,
    vsync: this,
  );
  int tabIndex = 0;
  Map<ImageFavorite, bool> selectedImageFavorites = {};
  late List<ImageFavorite> imageFavorites;

  void update() {
    setState(() {});
  }

  void getInitImageFavorites() {
    imageFavorites = ImageFavoriteManager.getAll();
    imageFavoritesGroup = [];
    for (var ele in imageFavorites) {
      try {
        ImageFavoritesGroup tempGroup = imageFavoritesGroup
            .where(
              (i) => i.id == ele.id && i.eid == ele.ep.toString(),
            )
            .first;
        tempGroup.imageFavorites.add(ele);
      } catch (e) {
        imageFavoritesGroup
            .add(ImageFavoritesGroup(ele.id, [ele], ele.ep.toString()));
      }
    }
  }

  void refreshImageFavorites() {
    getInitImageFavorites();
    update();
  }

  void getCurImageFavorites() {
    // 筛选到最终列表
    curImageFavoritesGroup = imageFavoritesGroup.where((ele) {
      bool isFilter = true;
      if (keyword != "") {
        isFilter = ele.title.contains(keyword);
      }
      if (timeFilterSelect != "") {
        timeFilter = getDateTimeRangeFromFilter(timeFilterSelect);
        DateTime start = timeFilter[0];
        DateTime end = timeFilter[1];
        DateTime dateTimeToCheck = ele.firstTime;
        isFilter =
            dateTimeToCheck.isAfter(start) && dateTimeToCheck.isBefore(end) ||
                dateTimeToCheck == start ||
                dateTimeToCheck == end;
      }
      return isFilter;
    }).toList();
    // 给每个 group 的收藏图片排一个序
    for (var ele in curImageFavoritesGroup) {
      ele.imageFavorites.sort((a, b) => a.page.compareTo(b.page));
    }
    // 给列表排序
    switch (sortType) {
      case ImageFavoriteSortType.name:
        curImageFavoritesGroup.sort((a, b) => a.title.compareTo(b.title));
        break;
      case ImageFavoriteSortType.timeAsc:
        curImageFavoritesGroup
            .sort((a, b) => a.firstTime.compareTo(b.firstTime));
        break;
      case ImageFavoriteSortType.timeDesc:
        curImageFavoritesGroup
            .sort((a, b) => b.firstTime.compareTo(a.firstTime));
        break;
      default:
    }
  }

  @override
  void initState() {
    var sort = appdata.implicitData["image_favorites_sort"] ?? "name";
    sortType = ImageFavoriteSortType.fromString(sort);
    timeFilterSelect =
        appdata.implicitData["image_favorites_time_filter"] ?? "";
    finalTimeList = List<String>.from([
      ...timeFilterList.map((e) => e.name),
      ...ImageFavoriteManager.earliestTimeToNow
    ]);
    getInitImageFavorites();
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    ImageFavoriteManager().removeListener(refreshImageFavorites);
    super.dispose();
  }

  Widget buildMultiSelectMenu() {
    return MenuButton(entries: [
      MenuEntry(
        icon: Icons.delete_outline,
        text: "Delete".tl,
        onClick: () {
          selectedImageFavorites.keys.toList().forEach((ele) {
            ImageFavoriteManager.delete(ele);
          });
          setState(() {
            multiSelectMode = false;
            selectedImageFavorites.clear();
          });
        },
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    getCurImageFavorites();
    void selectAll() {
      for (var ele in imageFavorites) {
        selectedImageFavorites[ele] = true;
      }
      update();
    }

    void deSelect() {
      setState(() {
        selectedImageFavorites.clear();
      });
    }

    void invertSelection() {
      setState(() {
        selectedImageFavorites.removeWhere((k, v) => !v);
      });
    }

    void addSelected(ImageFavorite i) {
      if (selectedImageFavorites[i] == null) {
        selectedImageFavorites[i] = true;
      } else {
        selectedImageFavorites.remove(i);
      }
      if (selectedImageFavorites.isEmpty) {
        multiSelectMode = false;
      } else {
        multiSelectMode = true;
      }
      update();
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
      buildMultiSelectMenu(),
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
                    selectedImageFavorites.clear();
                  });
                },
              ),
            ),
            title: Text(
                "Selected @c ".tlParams({"c": selectedImageFavorites.length})),
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
        SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
          return ImageFavoritesItem(
              imageFavoritesGroup: curImageFavoritesGroup[index],
              selectedImageFavorites: selectedImageFavorites,
              addSelected: addSelected,
              multiSelectMode: multiSelectMode);
        }, childCount: 10)),
        SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }

  void sort() {
    Widget tabBar = Material(
      child: FilledTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
        controller: controller,
      ),
    ).paddingTop(context.padding.top);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          void handleTabIndex() {
            setState(() {
              tabIndex = controller.index;
            });
          }

          controller.addListener(handleTabIndex);

          return ContentDialog(
            content: Container(
                // 向上移动一点, 减少 Column 顶部的 padding, 避免观感太差
                transform: Matrix4.translationValues(0, -20, 0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  tabBar,
                  tabIndex == 0
                      ? Column(
                          children: [
                            CustomListItem('Name', ImageFavoriteSortType.name),
                            CustomListItem(
                                'timeAsc', ImageFavoriteSortType.timeAsc),
                            CustomListItem(
                                'timeDesc', ImageFavoriteSortType.timeDesc),
                            CustomListItem('favorite Num Desc',
                                ImageFavoriteSortType.maxFavorites),
                            CustomListItem(
                                'favoritesCompareComicPages',
                                ImageFavoriteSortType
                                    .favoritesCompareComicPages),
                          ]
                              .map(
                                (e) => RadioListTile<ImageFavoriteSortType>(
                                  title: Text(e.title.tl),
                                  value: e.value,
                                  groupValue: sortType,
                                  onChanged: (v) {
                                    setState(() {
                                      sortType = v!;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        )
                      : ListTile(
                          title: Text("时间筛选".tl),
                          trailing: Select(
                            current: timeFilterSelect,
                            values: finalTimeList,
                            minWidth: 64,
                            onTap: (index) {
                              setState(() {
                                timeFilterSelect = finalTimeList[index];
                              });
                            },
                          ),
                        )
                ])),
            actions: [
              FilledButton(
                onPressed: () {
                  appdata.implicitData["image_favorites_sort"] = sortType.value;
                  appdata.implicitData["image_favorites_time_filter"] =
                      timeFilterSelect;
                  appdata.writeImplicitData();
                  controller.removeListener(handleTabIndex);

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
