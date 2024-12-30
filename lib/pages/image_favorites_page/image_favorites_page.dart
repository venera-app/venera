import 'dart:developer';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/image_favorites_provider.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/pages/comic_page.dart';
import 'package:venera/pages/image_favorites_page/type.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/file_type.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
part "image_favorites_item.dart";
part "image_favorites_photo_view.dart";

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
  List<ImageFavoritesComic> imageFavoritesComicList = [];
  late List<ImageFavoritesComic> curImageFavoritesComicList;
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
  // 多选的时候选中的图片
  Map<ImageFavoritePro, bool> selectedImageFavorites = {};
  late List<ImageFavoritePro> imageFavoritePros;

  void update() {
    setState(() {});
  }

  void getInitImageFavorites() {
    imageFavoritePros = [];
    for (var e in ImageFavoriteManager.imageFavoritesComicList) {
      imageFavoritePros.addAll(e.sortedImageFavoritePros);
    }
    imageFavoritesComicList = ImageFavoriteManager.imageFavoritesComicList;
  }

  void refreshImageFavorites() {
    getInitImageFavorites();
    update();
  }

  void getCurImageFavorites() {
    List<ImageFavoritesComic> tempList = imageFavoritesComicList;
    if (keyword != "") {
      tempList = ImageFavoriteManager.search(keyword);
    }
    // 筛选到最终列表
    curImageFavoritesComicList = tempList.where((ele) {
      bool isFilter = true;
      if (timeFilterSelect != "") {
        timeFilter = getDateTimeRangeFromFilter(timeFilterSelect);
        DateTime start = timeFilter[0];
        DateTime end = timeFilter[1];
        DateTime dateTimeToCheck = ele.time;
        isFilter =
            dateTimeToCheck.isAfter(start) && dateTimeToCheck.isBefore(end) ||
                dateTimeToCheck == start ||
                dateTimeToCheck == end;
      }
      return isFilter;
    }).toList();
    // 给列表排序
    switch (sortType) {
      case ImageFavoriteSortType.name:
        curImageFavoritesComicList.sort((a, b) => a.title.compareTo(b.title));
        break;
      case ImageFavoriteSortType.timeAsc:
        curImageFavoritesComicList.sort((a, b) => a.time.compareTo(b.time));
        break;
      case ImageFavoriteSortType.timeDesc:
        curImageFavoritesComicList.sort((a, b) => b.time.compareTo(a.time));
        break;
      case ImageFavoriteSortType.maxFavorites:
        curImageFavoritesComicList.sort((a, b) => b
            .sortedImageFavoritePros.length
            .compareTo(a.sortedImageFavoritePros.length));
        break;
      case ImageFavoriteSortType.favoritesCompareComicPages:
        curImageFavoritesComicList.sort((a, b) {
          double tempA = a.sortedImageFavoritePros.length / a.maxPageFromEp;
          double tempB = b.sortedImageFavoritePros.length / b.maxPageFromEp;
          return tempB.compareTo(tempA);
        });
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
            ImageFavoriteManager.deleteImageFavoritePro([ele]);
          });
          setState(() {
            multiSelectMode = false;
            selectedImageFavorites.clear();
          });
        },
      )
    ]);
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    getCurImageFavorites();
    void selectAll() {
      for (var ele in imageFavoritePros) {
        selectedImageFavorites[ele] = true;
      }
      update();
    }

    void deSelect() {
      setState(() {
        selectedImageFavorites.clear();
      });
    }

    void addSelected(ImageFavoritePro i) {
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
      buildMultiSelectMenu(),
    ];
    var widget = SmoothCustomScrollView(
      controller: scrollController,
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
              MenuButton(
                entries: [
                  MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export current to clipboard".tl,
                      onClick: () async {
                        await Clipboard.setData(
                            ClipboardData(text: "要复制到剪贴板的内容"));
                        showToast(message: "成功赋值到剪贴板".tl, context: context);
                      }),
                ],
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
            imageFavoritesComic: curImageFavoritesComicList[index],
            selectedImageFavorites: selectedImageFavorites,
            addSelected: addSelected,
            multiSelectMode: multiSelectMode,
            finalImageFavoritesComicList: curImageFavoritesComicList,
          );
        }, childCount: curImageFavoritesComicList.length)),
        SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    Widget body = Scrollbar(
      controller: scrollController,
      thickness: App.isDesktop ? 8 : 12,
      radius: const Radius.circular(8),
      interactive: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child:
            context.width > changePoint ? widget.paddingHorizontal(8) : widget,
      ),
    );
    return body;
  }

  void sort() {
    Widget tabBar = Material(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        // 向上移动一点, 减少 Column 顶部的 padding, 避免观感太差
        transform: Matrix4.translationValues(0, -24, 0),
        child: FilledTabBar(
          key: PageStorageKey(optionTypes),
          tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
          controller: controller,
        ),
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
            content: Column(mainAxisSize: MainAxisSize.min, children: [
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
                        CustomListItem('favoritesCompareComicPages',
                            ImageFavoriteSortType.favoritesCompareComicPages),
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
                  : Column(
                      children: [
                        ListTile(
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
                      ],
                    )
            ]),
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
