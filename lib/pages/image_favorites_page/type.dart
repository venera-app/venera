import 'package:venera/foundation/log.dart';

enum ImageFavoriteSortType {
  name("name"),
  timeAsc("time_asc"),
  timeDesc("time_desc"),
  maxFavorites("max_favorites"), // 单本收藏数最多排序
  favoritesCompareComicPages("favorites_compare_comic_pages"); // 单本收藏数比上总页数

  final String value;

  const ImageFavoriteSortType(this.value);

  static ImageFavoriteSortType fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return name;
  }
}

class CustomListItem<T> {
  final String title;
  final T value;

  CustomListItem(this.title, this.value);
}

enum TimeFilterEnum {
  lastWeek("lastWeek"),
  lastMonth("lastMonth"),
  lastHalfYear("lastHalfYear"),
  lastYear("lastYear"); // 单本收藏数最多排序

  final String value;
  const TimeFilterEnum(this.value);
  static TimeFilterEnum fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return lastWeek;
  }
}

const timeFilterList = [
  TimeFilterEnum.lastWeek,
  TimeFilterEnum.lastMonth,
  TimeFilterEnum.lastHalfYear,
  TimeFilterEnum.lastYear,
];

getDateTimeRangeFromFilter(String timeFilter) {
  DateTime now = DateTime.now();
  DateTime start = now;
  DateTime end = now;
  try {
    if (timeFilter == TimeFilterEnum.lastWeek.name) {
      start = now.subtract(const Duration(days: 7));
    } else if (timeFilter == TimeFilterEnum.lastMonth.name) {
      start = now.subtract(const Duration(days: 30));
    } else if (timeFilter == TimeFilterEnum.lastHalfYear.name) {
      start = now.subtract(const Duration(days: 180));
    } else if (timeFilter == TimeFilterEnum.lastYear.name) {
      start = now.subtract(const Duration(days: 365));
    } else {
      // 是 2024, 2025 之类的
      int year = int.parse(timeFilter);
      start = DateTime(year, 1, 1);
      end = DateTime(year, 12, 31, 23, 59, 59);
    }
  } catch (e) {
    Log.error("Date compute", e);
  }

  List<DateTime> ranges = [start, end];
  return ranges;
}
