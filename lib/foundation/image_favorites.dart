part of "history.dart";

class ImageFavorite {
  final String eid;
  final String id; // 漫画id
  final int ep;
  final String epName;
  final String sourceKey;
  String imageKey;
  int page;
  bool? isAutoFavorite;

  ImageFavorite(
    this.page,
    this.imageKey,
    this.isAutoFavorite,
    this.eid,
    this.id,
    this.ep,
    this.sourceKey,
    this.epName,
  );

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'imageKey': imageKey,
      'isAutoFavorite': isAutoFavorite,
      'eid': eid,
      'id': id,
      'ep': ep,
      'sourceKey': sourceKey,
      'epName': epName,
    };
  }

  ImageFavorite.fromJson(Map<String, dynamic> json)
      : page = json['page'],
        imageKey = json['imageKey'],
        isAutoFavorite = json['isAutoFavorite'],
        eid = json['eid'],
        id = json['id'],
        ep = json['ep'],
        sourceKey = json['sourceKey'],
        epName = json['epName'];

  ImageFavorite copyWith({
    int? page,
    String? imageKey,
    bool? isAutoFavorite,
    String? eid,
    String? id,
    int? ep,
    String? sourceKey,
    String? epName,
  }) {
    return ImageFavorite(
      page ?? this.page,
      imageKey ?? this.imageKey,
      isAutoFavorite ?? this.isAutoFavorite,
      eid ?? this.eid,
      id ?? this.id,
      ep ?? this.ep,
      sourceKey ?? this.sourceKey,
      epName ?? this.epName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageFavorite &&
        other.id == id &&
        other.sourceKey == sourceKey &&
        other.page == page &&
        other.eid == eid &&
        other.ep == ep;
  }

  @override
  int get hashCode => Object.hash(id, sourceKey, page, eid, ep);
}

class ImageFavoritesEp {
  // 小心拷贝等多章节的可能更新章节顺序
  String eid;
  final int ep;
  int maxPage;
  String epName;
  List<ImageFavorite> imageFavorites;

  ImageFavoritesEp(
      this.eid, this.ep, this.imageFavorites, this.epName, this.maxPage);

  // 是否有封面
  bool get isHasFirstPage {
    return imageFavorites[0].page == firstPage;
  }

  // 是否都有imageKey
  bool get isHasImageKey {
    return imageFavorites.every((e) => e.imageKey != "");
  }

  Map<String, dynamic> toJson() {
    return {
      'eid': eid,
      'ep': ep,
      'maxPage': maxPage,
      'epName': epName,
      'imageFavorites': imageFavorites.map((e) => e.toJson()).toList(),
    };
  }
}

class ImageFavoritesComic {
  final String id;
  final String title;
  String subTitle;
  String author;
  final String sourceKey;

  // 不一定是真的这本漫画的所有页数, 如果是多章节的时候
  int maxPage;
  List<String> tags;
  List<String> translatedTags;
  final DateTime time;
  List<ImageFavoritesEp> imageFavoritesEp;
  final Map<String, dynamic> other;

  ImageFavoritesComic(
    this.id,
    this.imageFavoritesEp,
    this.title,
    this.sourceKey,
    this.tags,
    this.translatedTags,
    this.time,
    this.author,
    this.other,
    this.subTitle,
    this.maxPage,
  );

  // 是否都有imageKey
  bool get isAllHasImageKey {
    return imageFavoritesEp
        .every((e) => e.imageFavorites.every((j) => j.imageKey != ""));
  }

  int get maxPageFromEp {
    int temp = 0;
    for (var e in imageFavoritesEp) {
      temp += e.maxPage;
    }
    return temp;
  }

  // 是否都有封面
  bool get isAllHasFirstPage {
    return imageFavoritesEp.every((e) => e.isHasFirstPage);
  }

  List<ImageFavorite> get sortedImageFavorites {
    List<ImageFavorite> temp = [];
    for (var e in imageFavoritesEp) {
      for (var i in e.imageFavorites) {
        temp.add(i);
      }
    }
    return temp;
  }

  @override
  bool operator ==(Object other) {
    return other is ImageFavoritesComic &&
        other.id == id &&
        other.sourceKey == sourceKey;
  }

  @override
  int get hashCode => Object.hash(id, sourceKey);
}

class ImageFavoriteManager with ChangeNotifier {
  Database get _db => HistoryManager()._db;
  late List<ImageFavoritesComic> imageFavoritesComicList = getAll(null);

  static ImageFavoriteManager? _cache;

  ImageFavoriteManager._();

  factory ImageFavoriteManager() => (_cache ??= ImageFavoriteManager._());

  Timer? updateTimer;

  void updateValue() {
    // 立刻触发, 让阅读界面可以看到图片收藏的图标状态更新了
    imageFavoritesComicList = getAll();
    // 避免从pica导入的时候, 疯狂触发更新
    updateTimer?.cancel();
    updateTimer = Timer(const Duration(seconds: 4), () {
      notifyListeners();
      updateTimer = null;
    });
  }

  /// 检查表image_favorites是否存在, 不存在则创建
  void init() {
    _db.execute("CREATE TABLE IF NOT EXISTS image_favorites ("
        "id TEXT,"
        "title TEXT NOT NULL,"
        "sub_title TEXT,"
        "author TEXT,"
        "tags TEXT,"
        "translated_tags TEXT,"
        "time int,"
        "max_page int,"
        "source_key TEXT NOT NULL,"
        "image_favorites_ep TEXT NOT NULL,"
        "other TEXT NOT NULL,"
        "PRIMARY KEY (id,source_key)"
        ");");
  }

  // 做排序和去重的操作
  void addOrUpdateOrDelete(ImageFavoritesComic favorite) {
    // 没有章节了就删掉
    if (favorite.imageFavoritesEp.isEmpty) {
      _db.execute("""
      delete from image_favorites
      where id == ? and source_key == ?;
    """, [favorite.id, favorite.sourceKey]);
    } else {
      // 去重章节
      List<ImageFavoritesEp> tempImageFavoritesEp = [];
      for (var e in favorite.imageFavoritesEp) {
        int index = tempImageFavoritesEp.indexWhere((i) {
          return i.ep == e.ep;
        });
        // 再做一层保险, 防止出现ep为0的脏数据
        if (index == -1 && e.ep > 0) {
          tempImageFavoritesEp.add(e);
        }
      }
      tempImageFavoritesEp.sort((a, b) => a.ep.compareTo(b.ep));
      List<dynamic> finalImageFavoritesEp =
          jsonDecode(jsonEncode(tempImageFavoritesEp));
      for (var e in tempImageFavoritesEp) {
        List<Map> finalImageFavorites = [];
        int epIndex = tempImageFavoritesEp.indexOf(e);
        for (ImageFavorite j in e.imageFavorites) {
          int index =
              finalImageFavorites.indexWhere((i) => i["page"] == j.page);
          if (index == -1 && j.page > 0) {
            // isAutoFavorite 为 null 不写入数据库, 同时只保留需要的属性, 避免增加太多重复字段在数据库里
            if (j.isAutoFavorite != null) {
              finalImageFavorites.add({
                "page": j.page,
                "imageKey": j.imageKey,
                "isAutoFavorite": j.isAutoFavorite
              });
            } else {
              finalImageFavorites.add({"page": j.page, "imageKey": j.imageKey});
            }
          }
        }
        finalImageFavorites.sort((a, b) => a["page"].compareTo(b["page"]));
        finalImageFavoritesEp[epIndex]["imageFavorites"] = finalImageFavorites;
      }
      if (tempImageFavoritesEp.isEmpty) {
        throw "Error: No ImageFavoritesEp";
      }
      _db.execute("""
      insert or replace into image_favorites(id, title, sub_title, author, tags, translated_tags, time, max_page, source_key, image_favorites_ep, other)
      values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, [
        favorite.id,
        favorite.title,
        favorite.subTitle,
        favorite.author,
        favorite.tags.join(","),
        favorite.translatedTags.join(","),
        favorite.time.millisecondsSinceEpoch,
        favorite.maxPage,
        favorite.sourceKey,
        jsonEncode(finalImageFavoritesEp),
        jsonEncode(favorite.other)
      ]);
    }
    ImageFavoriteManager().updateValue();
  }

  ImageFavoritesComic? findFromComicList(List<ImageFavoritesComic> tempList,
      String id, String sourceKey, String eid, int page, int ep) {
    ImageFavoritesComic? temp = tempList
        .firstWhereOrNull((e) => e.id == id && e.sourceKey == sourceKey);
    if (temp == null) {
      return null;
    } else {
      ImageFavoritesEp? tempEp = temp.imageFavoritesEp.firstWhereOrNull((e) {
        return e.ep == ep;
      });
      if (tempEp == null) {
        return null;
      } else {
        ImageFavorite? tempFavorite =
            tempEp.imageFavorites.firstWhereOrNull((e) => e.page == page);
        if (tempFavorite != null) {
          return temp;
        }
        return null;
      }
    }
  }

  bool has(String id, String sourceKey, String eid, int page, int ep) {
    return findFromComicList(
            imageFavoritesComicList, id, sourceKey, eid, page, ep) !=
        null;
  }

  List<ImageFavoritesComic> getAll([String? keyword]) {
    var res = [];
    if (keyword == null || keyword == "") {
      res = _db.select("select * from image_favorites;");
    } else {
      res = _db.select(
        """
    select * from image_favorites
    WHERE LOWER(title) LIKE LOWER(?)
    OR LOWER(sub_title) LIKE LOWER(?)
    OR LOWER(tags) LIKE LOWER(?)
    OR LOWER(translated_tags) LIKE LOWER(?)
    OR LOWER(author) LIKE LOWER(?);
    """,
        ['%$keyword%', '%$keyword%', '%$keyword%', '%$keyword%', '%$keyword%'],
      );
    }
    try {
      return res.map((e) {
        var tempImageFavoritesEp = jsonDecode(e["image_favorites_ep"]);
        List<ImageFavoritesEp> finalImageFavoritesEp = [];
        tempImageFavoritesEp.forEach((i) {
          List<ImageFavorite> temp = [];
          i["imageFavorites"].forEach((j) {
            temp.add(ImageFavorite(
                j["page"],
                j["imageKey"],
                j["isAutoFavorite"],
                i["eid"],
                e["id"],
                i["ep"],
                e["source_key"],
                i["epName"]));
          });
          finalImageFavoritesEp.add(ImageFavoritesEp(
              i["eid"], i["ep"], temp, i["epName"], i["maxPage"] ?? 1));
        });
        return ImageFavoritesComic(
          e["id"],
          finalImageFavoritesEp,
          e["title"],
          e["source_key"],
          e["tags"].split(","),
          e["translated_tags"].split(","),
          DateTime.fromMillisecondsSinceEpoch(e["time"]),
          e["author"],
          jsonDecode(e["other"]),
          e["sub_title"],
          e["max_page"],
        );
      }).toList();
    } catch (e, stackTrace) {
      Log.error("Unhandled Exception", e.toString(), stackTrace);
      return [];
    }
  }

  void deleteImageFavorite(List<ImageFavorite> imageFavoriteList) {
    if (imageFavoriteList.isEmpty) {
      return;
    }
    for (var e in imageFavoritesComicList) {
      // 找到同一个漫画中的需要删除的具体图片
      List<ImageFavorite> filterImageFavorites = imageFavoriteList.where((i) {
        return i.id == e.id && i.sourceKey == e.sourceKey;
      }).toList();
      if (filterImageFavorites.isNotEmpty) {
        e.imageFavoritesEp = e.imageFavoritesEp.where((i) {
          // 去掉匹配到的具体图片
          i.imageFavorites = i.imageFavorites.where((j) {
            ImageFavorite? temp = filterImageFavorites.firstWhereOrNull((k) {
              return k.page == j.page && k.ep == j.ep;
            });
            // 如果没有匹配到, 说明不是这个章节和page, 就留着
            return temp == null;
          }).toList();
          // 如果一张图片都没了, 或者只有一张自动收藏的firstPage, 就去掉这个章节
          if (i.imageFavorites.length == 1 &&
              i.imageFavorites.first.isAutoFavorite == true) {
            return false;
          }
          return i.imageFavorites.isNotEmpty;
        }).toList();
        addOrUpdateOrDelete(e);
      }
    }
    ImageFavoriteManager().updateValue();
  }

  List<String> get earliestTimeToNow {
    var res = _db.select("select MIN(time) from image_favorites;");
    if (res.first.values.first == null) {
      return [];
    }
    int earliestYear =
        DateTime.fromMillisecondsSinceEpoch(res.first.values.first! as int)
            .year;
    DateTime now = DateTime.now();
    int currentYear = now.year;
    List<String> yearsList = [];
    for (int year = earliestYear; year <= currentYear; year++) {
      yearsList.add(year.toString());
    }
    return yearsList;
  }

  int get length {
    var res = _db.select("select count(*) from image_favorites;");
    return res.first.values.first! as int;
  }

  List<ImageFavoritesComic> search(String keyword) {
    if (keyword == "") {
      return [];
    }
    return getAll(keyword);
  }

  Future<ImageFavoritesCompute> computeImageFavorites() {
    return compute(
      _computeImageFavorites,
      imageFavoritesComicList,
    );
  }

  static ImageFavoritesCompute _computeImageFavorites(
      List<ImageFavoritesComic> comics) {
    // 去掉这些没有意义的标签
    const List<String> exceptTags = [
      '連載中',
      '',
      'translated',
      'chinese',
      'sole male',
      'sole female',
      'original',
      'doujinshi',
      'manga',
      'multi-work series',
      'mosaic censorship',
      'dilf',
      'bbm',
      'uncensored',
      'full censorship'
    ];

    Map<String, int> tagCount = {};
    Map<String, int> authorCount = {};
    Map<ImageFavoritesComic, int> comicImageCount = {};
    Map<ImageFavoritesComic, int> comicMaxPages = {};

    for (var comic in comics) {
      for (var tag in comic.tags) {
        String finalTag = tag;
        tagCount[finalTag] = (tagCount[finalTag] ?? 0) + 1;
      }

      if (comic.author != "") {
        String finalAuthor = comic.author;
        authorCount[finalAuthor] =
            (authorCount[finalAuthor] ?? 0) + comic.sortedImageFavorites.length;
      }
      // 小于10页的漫画不统计
      if (comic.maxPageFromEp < 10) {
        continue;
      }
      comicImageCount[comic] =
          (comicImageCount[comic] ?? 0) + comic.sortedImageFavorites.length;
      comicMaxPages[comic] = (comicMaxPages[comic] ?? 0) + comic.maxPageFromEp;
    }

    // 按数量排序标签
    List<String> sortedTags = tagCount.keys.toList()
      ..sort((a, b) => tagCount[b]!.compareTo(tagCount[a]!));

    // 按数量排序作者
    List<String> sortedAuthors = authorCount.keys.toList()
      ..sort((a, b) => authorCount[b]!.compareTo(authorCount[a]!));

    // 按收藏数量排序漫画
    List<MapEntry<ImageFavoritesComic, int>> sortedComicsByNum =
        comicImageCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // 按收藏比例排序漫画
    List<MapEntry<ImageFavoritesComic, int>> sortedComicsByPercentage =
        comicImageCount.entries.toList()
          ..sort((a, b) {
            double percentageA =
                comicImageCount[a.key]! / comicMaxPages[a.key]!;
            double percentageB =
                comicImageCount[b.key]! / comicMaxPages[b.key]!;
            return percentageB.compareTo(percentageA);
          });

    validateTag(String tag) {
      if (tag.startsWith("Category:")) {
        return false;
      }
      return !exceptTags.contains(tag.toLowerCase()) && !tag.isNum;
    }

    return ImageFavoritesCompute(
      sortedTags
          .where(validateTag)
          .map((tag) => TextWithCount(tag, tagCount[tag]!))
          .toList(),
      sortedAuthors
          .map((author) => TextWithCount(author, authorCount[author]!))
          .toList(),
      sortedComicsByNum
          .map((comic) => TextWithCount(comic.key.title, comic.value))
          .toList(),
      sortedComicsByPercentage
          .map((comic) => TextWithCount(comic.key.title, comic.value))
          .toList(),
    );
  }

  ImageFavoritesComic? find(String id, String sourceKey) {
    return imageFavoritesComicList.firstWhereOrNull(
      (comic) => comic.id == id && comic.sourceKey == sourceKey,
    );
  }
}

class TextWithCount {
  final String text;
  final int count;

  const TextWithCount(this.text, this.count);
}

class ImageFavoritesCompute {
  /// 基于收藏的标签数排序
  final List<TextWithCount> tags;

  /// 基于收藏的作者数排序
  final List<TextWithCount> authors;

  /// 基于喜欢的图片数排序
  final List<TextWithCount> comicByNum;

  // 基于图片数比上总页数排序
  final List<TextWithCount> comicByPercentage;

  /// 计算后的图片收藏数据
  const ImageFavoritesCompute(
    this.tags,
    this.authors,
    this.comicByNum,
    this.comicByPercentage,
  );
}
