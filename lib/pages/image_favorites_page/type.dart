enum ImageFavoriteSortType {
  title("Title"),
  timeAsc("Time Asc"),
  timeDesc("Time Desc"),
  maxFavorites("Favorite Num"), // 单本收藏数最多排序
  favoritesCompareComicPages("Favorite Num Compare Comic Pages"); // 单本收藏数比上总页数

  final String value;

  const ImageFavoriteSortType(this.value);
}

const numFilterList = [0, 1, 2, 5, 10, 20, 50, 100];

enum TimeFilterEnum {
  all("All"),
  lastWeek("Last Week"),
  lastMonth("Last Month"),
  lastHalfYear("Last Half Year"),
  lastYear("Last Year"); // 单本收藏数最多排序

  final String value;
  const TimeFilterEnum(this.value);

  Duration get duration {
    return switch (this) {
      all => Duration(days: 365 * 100),
      lastWeek => Duration(days: 7),
      lastMonth => Duration(days: 30),
      lastHalfYear => Duration(days: 180),
      lastYear => Duration(days: 365),
    };
  }
}
