import 'dart:math';

import 'package:flutter/foundation.dart';
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
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/pages/comic_page.dart';
import 'package:venera/pages/image_favorites_page/type.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/file_type.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/translations.dart';

part "image_favorites_item.dart";

part "image_favorites_photo_view.dart";

class LoadingImageFavoritesComicRes {
  bool isLoaded;
  bool isInvalid;
  String id;
  String sourceKey;

  LoadingImageFavoritesComicRes(
      {required this.isLoaded,
      required this.isInvalid,
      required this.id,
      required this.sourceKey});
}

class ImageFavoritesPage extends StatefulWidget {
  const ImageFavoritesPage({super.key, this.initialKeyword});

  final String? initialKeyword;

  @override
  State<ImageFavoritesPage> createState() => ImageFavoritesPageState();
}

class ImageFavoritesPageState extends State<ImageFavoritesPage> {
  late ImageFavoriteSortType sortType;
  ImageFavoritesCompute? imageFavoritesCompute;
  late TimeFilterEnum timeFilterSelect;
  late int numFilterSelect;

  // 所有的图片收藏
  List<ImageFavoritesComic> comics = [];
  late List<DateTime> timeFilter;
  List<LoadingImageFavoritesComicRes> isRefreshComicList = [];
  late TextEditingController _textEditingController;
  String keyword = "";

  // 进入关键词搜索模式
  bool searchMode = false;

  bool multiSelectMode = false;

  // 多选的时候选中的图片
  Map<ImageFavorite, bool> selectedImageFavorites = {};
  late List<ImageFavorite> imageFavoritePros;

  // 避免重复请求
  void setRefreshComicList(LoadingImageFavoritesComicRes res) {
    LoadingImageFavoritesComicRes? tempRes =
        isRefreshComicList.firstWhereOrNull(
            (e) => e.id == res.id && e.sourceKey == res.sourceKey);
    if (tempRes == null) {
      isRefreshComicList.add(res);
    } else {
      tempRes.isLoaded = res.isLoaded;
      tempRes.isInvalid = res.isInvalid;
    }
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  void updateDialogConfig(ImageFavoriteSortType sortType,
      TimeFilterEnum timeFilter, int numFilter) {
    setState(() {
      this.sortType = sortType;
      timeFilterSelect = timeFilter;
      numFilterSelect = numFilter;
    });
  }

  void getInitImageFavorites() async {
    imageFavoritePros = [];
    for (var e in ImageFavoriteManager().imageFavoritesComicList) {
      imageFavoritePros.addAll(e.sortedImageFavorites);
    }
    getCurImageFavorites();
    imageFavoritesCompute =
        await ImageFavoriteManager().computeImageFavorites();
    update();
  }

  void refreshImageFavorites() async {
    if (mounted) {
      getInitImageFavorites();
      update();
    }
  }

  void getCurImageFavorites() {
    comics = searchMode
        ? ImageFavoriteManager().search(keyword)
        : ImageFavoriteManager().getAll();
    var now = DateTime.now();
    // 筛选到最终列表
    comics = comics.where((ele) {
      bool isFilter = true;
      if (timeFilterSelect != TimeFilterEnum.all) {
        isFilter = now.difference(ele.time) <= timeFilterSelect.duration;
      }
      if (numFilterSelect != numFilterList[0]) {
        isFilter = ele.sortedImageFavorites.length > numFilterSelect;
      }
      return isFilter;
    }).toList();
    // 给列表排序
    switch (sortType) {
      case ImageFavoriteSortType.title:
        comics.sort((a, b) => a.title.compareTo(b.title));
      case ImageFavoriteSortType.timeAsc:
        comics.sort((a, b) => a.time.compareTo(b.time));
      case ImageFavoriteSortType.timeDesc:
        comics.sort((a, b) => b.time.compareTo(a.time));
      case ImageFavoriteSortType.maxFavorites:
        comics.sort((a, b) => b.sortedImageFavorites.length
            .compareTo(a.sortedImageFavorites.length));
      case ImageFavoriteSortType.favoritesCompareComicPages:
        comics.sort((a, b) {
          double tempA = a.sortedImageFavorites.length / a.maxPageFromEp;
          double tempB = b.sortedImageFavorites.length / b.maxPageFromEp;
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
    _textEditingController = TextEditingController(text: keyword);
    sortType = ImageFavoriteSortType.values.firstWhereOrNull(
            (e) => e.value == appdata.implicitData["image_favorites_sort"]) ??
        ImageFavoriteSortType.title;
    timeFilterSelect = TimeFilterEnum.values.firstWhereOrNull((e) =>
            e.value == appdata.implicitData["image_favorites_time_filter"]) ??
        TimeFilterEnum.all;
    numFilterSelect = appdata.implicitData["image_favorites_number_filter"] ??
        numFilterList[0];
    getInitImageFavorites();
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    ImageFavoriteManager().removeListener(refreshImageFavorites);
    scrollController.dispose();
    super.dispose();
  }

  Widget buildMultiSelectMenu() {
    return MenuButton(entries: [
      MenuEntry(
        icon: Icons.delete_outline,
        text: "Delete".tl,
        onClick: () {
          ImageFavoriteManager()
              .deleteImageFavorite(selectedImageFavorites.keys.toList());
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
      buildMultiSelectMenu(),
    ];
    var scrollWidget = SmoothCustomScrollView(
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
              controller: _textEditingController,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: InputBorder.none,
              ),
              onChanged: (v) {
                Future.delayed(Duration(milliseconds: 500), () {
                  keyword = _textEditingController.text;
                  update();
                });
              },
            ),
          ),
        if (appdata.implicitData['Guide_imageFavoritesPage_DoubleTap'] != true)
          SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  'Double tap comic copy title, double tap image open gallery'
                      .tl,
                ),
                Spacer(),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    appdata.implicitData['Guide_imageFavoritesPage_DoubleTap'] =
                        true;
                    appdata.writeImplicitData();
                    update();
                  },
                )
              ],
            ).paddingHorizontal(8),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _ImageFavoritesItem(
                isRefreshComicList: isRefreshComicList,
                imageFavoritesComic: comics[index],
                selectedImageFavorites: selectedImageFavorites,
                addSelected: addSelected,
                multiSelectMode: multiSelectMode,
                finalImageFavoritesComicList: comics,
                setRefreshComicList: setRefreshComicList,
                imageFavoritesCompute: imageFavoritesCompute,
              );
            },
            childCount: comics.length,
          ),
        ),
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
        child: context.width > changePoint
            ? scrollWidget.paddingHorizontal(8)
            : scrollWidget,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedImageFavorites.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            update();
          });
        }
      },
      child: body,
    );
  }

  void sort() {
    showDialog(
      context: context,
      builder: (context) {
        return ImageFavoritesDialog(
          initSortType: sortType,
          initTimeFilterSelect: timeFilterSelect,
          initNumFilterSelect: numFilterSelect,
          updateDialogConfig: updateDialogConfig,
        );
      },
    );
  }
}

class ImageFavoritesDialog extends StatefulWidget {
  const ImageFavoritesDialog({
    super.key,
    required this.initSortType,
    required this.initTimeFilterSelect,
    required this.initNumFilterSelect,
    required this.updateDialogConfig,
  });

  final ImageFavoriteSortType initSortType;
  final TimeFilterEnum initTimeFilterSelect;
  final int initNumFilterSelect;
  final Function updateDialogConfig;

  @override
  State<ImageFavoritesDialog> createState() => ImageFavoritesDialogState();
}

class ImageFavoritesDialogState extends State<ImageFavoritesDialog>
    with TickerProviderStateMixin {
  late TabController controller;
  List<String> optionTypes = ['Sort', 'Filter'];
  int tabIndex = 0;
  late var sortType = widget.initSortType;
  late var timeFilter = widget.initTimeFilterSelect;
  late var numFilter = widget.initNumFilterSelect;

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
      borderRadius: BorderRadius.circular(8),
      child: FilledTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
        controller: controller,
      ),
    ).paddingTop(context.padding.top);
    return ContentDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        tabBar,
        tabIndex == 0
            ? Column(
                children: ImageFavoriteSortType.values
                    .map(
                      (e) => RadioListTile<ImageFavoriteSortType>(
                        title: Text(e.value.tl),
                        value: e,
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
                    title: Text("Time Filter".tl),
                    trailing: Select(
                      current: timeFilter.value,
                      values:
                          TimeFilterEnum.values.map((e) => e.value).toList(),
                      minWidth: 64,
                      onTap: (index) {
                        setState(() {
                          timeFilter = TimeFilterEnum.values[index];
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text("Image Favorites Greater Than".tl),
                    trailing: Select(
                      current: numFilter.toString(),
                      values: numFilterList.map((e) => e.toString()).toList(),
                      minWidth: 64,
                      onTap: (index) {
                        setState(() {
                          numFilter = numFilterList[index];
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
                timeFilter.value;
            appdata.implicitData["image_favorites_number_filter"] = numFilter;
            appdata.writeImplicitData();
            controller.removeListener(handleTabIndex);
            if (mounted) {
              Navigator.pop(context);
              widget.updateDialogConfig(sortType, timeFilter, numFilter);
            }
          },
          child: Text("Confirm".tl),
        ),
      ],
    );
  }
}
