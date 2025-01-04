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
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/file_type.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
part "image_favorites_item.dart";
part "image_favorites_photo_view.dart";

class LoadingImageFavoritesEpRes {
  bool isLoaded;
  bool isInvalid;
  LoadingImageFavoritesEpRes({required this.isLoaded, required this.isInvalid});
}

class ImageFavoritesPage extends StatefulWidget {
  const ImageFavoritesPage({super.key, this.initialKeyword});
  final String? initialKeyword;
  @override
  State<ImageFavoritesPage> createState() => ImageFavoritesPageState();
}

class ImageFavoritesPageState extends State<ImageFavoritesPage> {
  late String sortType;
  late String timeFilterSelect;
  late String numFilterSelect;
  late List<String> finalTimeList;
  // 所有的图片收藏
  List<ImageFavoritesComic> imageFavoritesComicList = [];
  late List<ImageFavoritesComic> curImageFavoritesComicList;
  late List<DateTime> timeFilter;
  Map<ImageFavoritesEp, LoadingImageFavoritesEpRes> isRefreshEpMap = {};
  String keyword = "";

  // 进入关键词搜索模式
  bool searchMode = false;

  bool multiSelectMode = false;
  // 多选的时候选中的图片
  Map<ImageFavoritePro, bool> selectedImageFavorites = {};
  late List<ImageFavoritePro> imageFavoritePros;

  void update() {
    setState(() {});
  }

  void updateDialogConfig(String tempSortType, String tempTimeFilterSelect,
      String tempNumFilterSelect) {
    setState(() {
      sortType = tempSortType;
      timeFilterSelect = tempTimeFilterSelect;
      numFilterSelect = tempNumFilterSelect;
    });
  }

  void getInitImageFavorites() {
    imageFavoritePros = [];
    for (var e in ImageFavoriteManager.imageFavoritesComicList) {
      imageFavoritePros.addAll(e.sortedImageFavoritePros);
    }
    imageFavoritesComicList = ImageFavoriteManager.imageFavoritesComicList;
  }

  void refreshImageFavorites() {
    if (mounted) {
      getInitImageFavorites();
      update();
    }
  }

  void getCurImageFavorites() {
    List<ImageFavoritesComic> tempList = imageFavoritesComicList;
    if (keyword != "") {
      tempList = ImageFavoriteManager.search(keyword);
    }
    // 筛选到最终列表
    curImageFavoritesComicList = tempList.where((ele) {
      bool isFilter = true;
      if (timeFilterSelect != TimeFilterEnum.all.value) {
        timeFilter = getDateTimeRangeFromFilter(timeFilterSelect);
        DateTime start = timeFilter[0];
        DateTime end = timeFilter[1];
        DateTime dateTimeToCheck = ele.time;
        isFilter =
            dateTimeToCheck.isAfter(start) && dateTimeToCheck.isBefore(end) ||
                dateTimeToCheck == start ||
                dateTimeToCheck == end;
      }
      if (numFilterSelect != numFilterList[0]) {
        isFilter =
            ele.sortedImageFavoritePros.length > int.parse(numFilterSelect);
      }
      return isFilter;
    }).toList();
    // 给列表排序
    if (sortType == ImageFavoriteSortType.title.value) {
      curImageFavoritesComicList.sort((a, b) => a.title.compareTo(b.title));
    } else if (sortType == ImageFavoriteSortType.timeAsc.value) {
      curImageFavoritesComicList.sort((a, b) => a.time.compareTo(b.time));
    } else if (sortType == ImageFavoriteSortType.timeDesc.value) {
      curImageFavoritesComicList.sort((a, b) => b.time.compareTo(a.time));
    } else if (sortType == ImageFavoriteSortType.maxFavorites.value) {
      curImageFavoritesComicList.sort((a, b) => b.sortedImageFavoritePros.length
          .compareTo(a.sortedImageFavoritePros.length));
    } else if (sortType ==
        ImageFavoriteSortType.favoritesCompareComicPages.value) {
      curImageFavoritesComicList.sort((a, b) {
        double tempA = a.sortedImageFavoritePros.length / a.maxPageFromEp;
        double tempB = b.sortedImageFavoritePros.length / b.maxPageFromEp;
        return tempB.compareTo(tempA);
      });
    }
  }

  @override
  void initState() {
    if (widget.initialKeyword != null) {
      keyword = widget.initialKeyword!;
      searchMode = true;
    }
    String initSortType = appdata.implicitData["image_favorites_sort"] ??
        ImageFavoriteSortType.title.value;
    sortType = ImageFavoriteSortType.values
            .firstWhereOrNull((e) => e.value == initSortType)
            ?.value ??
        ImageFavoriteSortType.title.value;
    String initTimeFilter =
        appdata.implicitData["image_favorites_time_filter"] ??
            TimeFilterEnum.all.value;
    // 可能是年份
    int yearNum = int.tryParse(initTimeFilter) ?? 2023;
    bool isValideYearNum = yearNum >= 2023 && yearNum <= 2099;
    if (!isValideYearNum) {
      timeFilterSelect = timeFilterList
              .firstWhereOrNull((e) => e.value == initTimeFilter)
              ?.value ??
          TimeFilterEnum.all.value;
    } else {
      timeFilterSelect = initTimeFilter;
    }
    numFilterSelect =
        appdata.implicitData["image_favorites_num_filter"] ?? numFilterList[0];
    finalTimeList = List<String>.from([
      ...timeFilterList.map((e) => e.value),
      ...ImageFavoriteManager.earliestTimeToNow
    ]);
    getInitImageFavorites();
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
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
            title: Text("Image Favorites".tl),
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
                  color: timeFilterSelect != TimeFilterEnum.all.value ||
                          numFilterSelect != numFilterList[0]
                      ? Theme.of(context).colorScheme.primary
                      : null,
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
              controller: TextEditingController(text: keyword),
              onChanged: (v) {
                keyword = v;
                update();
              },
            ),
          ),
        SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
          return ImageFavoritesItem(
            isRefreshEpMap: isRefreshEpMap,
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
    showDialog(
      context: context,
      builder: (context) {
        return ImageFavoritesDialog(
          initSortType: sortType,
          initTimeFilterSelect: timeFilterSelect,
          initNumFilterSelect: numFilterSelect,
          finalTimeList: finalTimeList,
          updateDialogConfig: updateDialogConfig,
        );
      },
    );
  }
}

class ImageFavoritesDialog extends StatefulWidget {
  ImageFavoritesDialog({
    super.key,
    required this.initSortType,
    required this.initTimeFilterSelect,
    required this.initNumFilterSelect,
    required this.finalTimeList,
    required this.updateDialogConfig,
  });
  String initSortType;
  String initTimeFilterSelect;
  String initNumFilterSelect;
  final List<String> finalTimeList;
  final Function updateDialogConfig;
  @override
  State<ImageFavoritesDialog> createState() => ImageFavoritesDialogState();
}

class ImageFavoritesDialogState extends State<ImageFavoritesDialog>
    with TickerProviderStateMixin {
  late TabController controller;
  List<String> optionTypes = ['Sort', 'Filter'];
  int tabIndex = 0;
  void handleTabIndex() {
    if (mounted) {
      setState(() {
        tabIndex = controller.index;
      });
    }
  }

  @override
  void initState() {
    controller = TabController(
      length: 2,
      vsync: this,
    );
    controller.addListener(handleTabIndex);
    super.initState();
  }

  @override
  void dispose() {
    controller.removeListener(handleTabIndex);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tabBar = Material(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: FilledTabBar(
          key: PageStorageKey(optionTypes),
          tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
          controller: controller,
        ),
      ),
    ).paddingTop(context.padding.top);
    return ContentDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        tabBar,
        tabIndex == 0
            ? Column(
                children: [
                  ImageFavoriteSortType.title,
                  ImageFavoriteSortType.timeAsc,
                  ImageFavoriteSortType.timeDesc,
                  ImageFavoriteSortType.maxFavorites,
                  ImageFavoriteSortType.favoritesCompareComicPages,
                ]
                    .map(
                      (e) => RadioListTile<String>(
                        title: Text(e.value.tl),
                        value: e.value,
                        groupValue: widget.initSortType,
                        onChanged: (v) {
                          setState(() {
                            widget.initSortType = v!;
                          });
                        },
                      ),
                    )
                    .toList(),
              )
            : Column(
                children: [
                  ListTile(
                    title: Text("Time Filter".tl),
                    trailing: Select(
                      current: widget.initTimeFilterSelect,
                      values: widget.finalTimeList,
                      minWidth: 64,
                      onTap: (index) {
                        setState(() {
                          widget.initTimeFilterSelect =
                              widget.finalTimeList[index];
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text("Image Favorites Greater Than".tl),
                    trailing: Select(
                      current: widget.initNumFilterSelect,
                      values: numFilterList,
                      minWidth: 64,
                      onTap: (index) {
                        setState(() {
                          widget.initNumFilterSelect = numFilterList[index];
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
            appdata.implicitData["image_favorites_sort"] = widget.initSortType;
            appdata.implicitData["image_favorites_time_filter"] =
                widget.initTimeFilterSelect;
            appdata.implicitData["image_favorites_num_filter"] =
                widget.initNumFilterSelect;
            appdata.writeImplicitData();
            controller.removeListener(handleTabIndex);
            if (mounted) {
              Navigator.pop(context);
              widget.updateDialogConfig(widget.initSortType,
                  widget.initTimeFilterSelect, widget.initNumFilterSelect);
            }
          },
          child: Text("Confirm".tl),
        ),
      ],
    );
  }
}
