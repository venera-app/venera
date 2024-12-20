part of "history.dart";

class ImageFavorite {
  /// unique id for the comic
  final String id;

  final String imagePath;

  final DateTime time;

  final String title;

  final int ep;

  final int page;

  final Map<String, dynamic> otherInfo;

  const ImageFavorite(
    this.id,
    this.imagePath,
    this.title,
    this.time,
    this.ep,
    this.page,
    this.otherInfo,
  );

  ImageFavorite.fromMap(Map<String, dynamic> map)
      : time = map["time"] ?? DateTime.now(), // 兜底从 picacomic 引入时没有 time 的情况
        title = map["title"],
        imagePath = map["imagePath"],
        ep = map["ep"],
        page = map["page"],
        id = map["id"],
        otherInfo = map["otherInfo"] ?? {};
}

class ImageFavoriteManager {
  static Database get _db => HistoryManager()._db;

  /// 检查表image_favorites是否存在, 不存在则创建
  static void init() {
    _db.execute("CREATE TABLE IF NOT EXISTS image_favorites ("
        "id TEXT,"
        "title TEXT NOT NULL,"
        "time int,"
        "cover TEXT NOT NULL,"
        "ep INTEGER NOT NULL,"
        "page INTEGER NOT NULL,"
        "other TEXT NOT NULL,"
        "PRIMARY KEY (id, ep, page)"
        ");");
  }

  static void add(ImageFavorite favorite) {
    _db.execute("""
      insert or replace into image_favorites(id, title, time, cover, ep, page, other)
      values(?, ?, ?, ?, ?, ?, ?);
    """, [
      favorite.id,
      favorite.title,
      favorite.time.millisecondsSinceEpoch,
      favorite.imagePath,
      favorite.ep,
      favorite.page,
      jsonEncode(favorite.otherInfo)
    ]);
  }

  static List<ImageFavorite> getAll() {
    var res = _db.select("select * from image_favorites;");
    return res
        .map((e) => ImageFavorite(
            e["id"],
            e["cover"],
            e["title"],
            DateTime.fromMillisecondsSinceEpoch(e["time"]),
            e["ep"],
            e["page"],
            jsonDecode(e["other"])))
        .toList();
  }

  static void delete(ImageFavorite favorite) {
    _db.execute("""
      delete from image_favorites
      where id = ? and ep = ? and page = ?;
    """, [favorite.id, favorite.ep, favorite.page]);
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
    var res = _db.select("select count(*) from image_favorites;");
    return res.first.values.first! as int;
  }
}
