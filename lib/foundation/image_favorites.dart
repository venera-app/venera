part of "history.dart";

class ImageFavorite {
  String imageKey;

  int page;

  // 是否是自动收藏的, 仅用于第一页
  bool? isAutoFavorite;

  ImageFavorite(
    this.page,
    this.imageKey,
    this.isAutoFavorite,
  );
}

class ImageFavoritePro extends ImageFavorite {
  final String eid;
  final String id; // 漫画id
  final int ep;
  final String epName;
  final String sourceKey;
  ImageFavoritePro(
    super.page,
    super.imageKey,
    super.isAutoFavorite,
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
    };
  }

  // 复制构造函数
  ImageFavoritePro.copy(ImageFavoritePro other)
      : this(other.page, other.imageKey, other.isAutoFavorite, other.eid,
            other.id, other.ep, other.sourceKey, other.epName);
}

class ImageFavoritesEp {
  final String eid;
  final int ep;
  int maxPage;
  String epName;
  List<ImageFavoritePro> imageFavorites;

  // 避免使用常量
  static int firstPage = 1;

  ImageFavoritesEp(
      this.eid, this.ep, this.imageFavorites, this.epName, this.maxPage);
  Map<String, dynamic> toJson() {
    return {
      'eid': eid,
      'ep': ep,
      'imageFavorites': imageFavorites,
      'epName': epName,
      'maxPage': maxPage,
    };
  }

  // 是否有封面
  bool get isHasFirstPage {
    return imageFavorites[0].page == firstPage;
  }

  // 是否都有imageKey
  bool get isHasImageKey {
    return imageFavorites.every((e) => e.imageKey != "");
  }
}

class ImageFavoritesSomething {
  String author;
  String subTitle;
  List<String> tags;
  List<String> translatedTags;
  String epName;
  ImageFavoritesSomething(
      this.author, this.tags, this.translatedTags, this.epName, this.subTitle);
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
      this.maxPage);

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

  List<ImageFavoritePro> get sortedImageFavoritePros {
    List<ImageFavoritePro> temp = [];
    for (var e in imageFavoritesEp) {
      for (var i in e.imageFavorites) {
        temp.add(i);
      }
    }
    return temp;
  }

  static List<String> tagsToTranslated(List<String> tags) {
    var translatedTags = <String>[];
    for (var tag in tags) {
      var translated = tag.translateTagsToCN;
      if (translated != tag) {
        translatedTags.add(translated);
      }
    }
    return translatedTags;
  }

  static ImageFavoritesSomething getSomethingFromComicDetails(
      ComicDetails comicDetails, int ep) {
    List<String> tags = [];
    String author = "";
    try {
      if (comicDetails.tags['Artists'] != null) {
        author = comicDetails.tags['Artists']!.first;
      }
      if (comicDetails.tags['artist'] != null) {
        author = comicDetails.tags['artist']!.first;
      }
      if (comicDetails.tags['作者'] != null) {
        author = comicDetails.tags['作者']!.first;
      }
      if (comicDetails.tags['Author'] != null) {
        author = comicDetails.tags['Author']!.first;
      }
      // ignore: empty_catches
    } catch (e) {}
    String epName =
        comicDetails.chapters?.values.elementAtOrNull(ep - 1) ?? "E$ep";
    tags = comicDetails.tags.values.fold(
        <String>[], (previousValue, element) => [...previousValue, ...element]);
    var translatedTags = tagsToTranslated(tags);
    String subTitle = comicDetails.subTitle ?? "";
    return ImageFavoritesSomething(
        author, tags, translatedTags, epName, subTitle);
  }
}

class ImageFavoriteManager with ChangeNotifier {
  static Database get _db => HistoryManager()._db;
  static ImageFavoriteManager? cache;
  static List<ImageFavoritesComic> imageFavoritesComicList = getAll(null);
  ImageFavoriteManager.create();
  static bool hasInit = false;
  factory ImageFavoriteManager() {
    return cache == null ? (cache = ImageFavoriteManager.create()) : cache!;
  }
  void updateValue() {
    imageFavoritesComicList = getAll(null);
    notifyListeners();
  }

  /// 检查表image_favorites是否存在, 不存在则创建
  static void init() {
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
    hasInit = true;
  }

  // 做排序和去重的操作
  static void addOrUpdateOrDelete(ImageFavoritesComic favorite) {
    // 没有章节了就删掉
    if (favorite.imageFavoritesEp.isEmpty) {
      _db.execute("""
      delete from image_favorites
      where id == ? and source_key == ?;
    """, [favorite.id, favorite.sourceKey]);
    } else {
      List<ImageFavoritesEp> tempImageFavoritesEp = [];
      for (var e in favorite.imageFavoritesEp) {
        int index = tempImageFavoritesEp.indexWhere((i) => i.ep == e.ep);
        if (index == -1) {
          tempImageFavoritesEp.add(e);
        }
      }
      tempImageFavoritesEp.sort((a, b) => a.ep.compareTo(b.ep));
      List<dynamic> finalImageFavoritesEp =
          jsonDecode(jsonEncode(tempImageFavoritesEp));
      for (var e in tempImageFavoritesEp) {
        List<Map> finalImageFavorites = [];
        int epIndex = tempImageFavoritesEp.indexOf(e);
        for (ImageFavoritePro j in e.imageFavorites) {
          int index =
              finalImageFavorites.indexWhere((i) => i["page"] == j.page);
          if (index == -1) {
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

  static ImageFavoritesComic? findFromComicList(
      List<ImageFavoritesComic> tempList,
      String id,
      String sourceKey,
      dynamic eid,
      int page) {
    ImageFavoritesComic? temp = tempList
        .firstWhereOrNull((e) => e.id == id && e.sourceKey == sourceKey);
    if (temp == null) {
      return null;
    } else {
      ImageFavoritesEp? tempEp = temp.imageFavoritesEp.firstWhereOrNull((e) {
        if (eid is int) {
          return e.ep == eid;
        }
        return e.eid == eid;
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

  static bool isHas(String id, String sourceKey, String eid, int page) {
    return findFromComicList(
            imageFavoritesComicList, id, sourceKey, eid, page) !=
        null;
  }

  static List<ImageFavoritesComic> getAll(String? keyword) {
    if (!hasInit) return [];
    var res = [];
    if (keyword == null) {
      res = _db.select("select * from image_favorites;");
    } else {
      _db.select(
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
        dynamic tempImageFavoritesEp = jsonDecode(e["image_favorites_ep"]);
        List<ImageFavoritesEp> finalImageFavoritesEp = [];
        tempImageFavoritesEp.forEach((i) {
          List<ImageFavoritePro> temp = [];
          i["imageFavorites"].forEach((j) {
            temp.add(ImageFavoritePro(
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

  static void deleteImageFavoritePro(
      List<ImageFavoritePro> imageFavoriteProList) {
    for (var e in imageFavoritesComicList) {
      // 找到需要删除的具体图片
      List<ImageFavoritePro> filterImageFavoritesPro =
          imageFavoriteProList.where((i) {
        return i.id == e.id && i.sourceKey == e.sourceKey;
      }).toList();
      if (filterImageFavoritesPro.isNotEmpty) {
        e.imageFavoritesEp = e.imageFavoritesEp.where((i) {
          // 去掉匹配到的具体图片
          i.imageFavorites = i.imageFavorites.where((j) {
            ImageFavoritePro? temp =
                filterImageFavoritesPro.firstWhereOrNull((k) {
              return k.eid == j.eid && k.page == j.page;
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

  static List<String> get earliestTimeToNow {
    var res = _db.select("select MIN(time) from image_favorites;");
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

  static int get length {
    if (!hasInit) return 0;
    var res = _db.select("select count(*) from image_favorites;");
    return res.first.values.first! as int;
  }

  static List<ImageFavoritesComic> search(String keyword) {
    return getAll(keyword);
  }
}
