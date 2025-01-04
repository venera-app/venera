import 'package:venera/foundation/log.dart';

enum ImageFavoriteSortType {
  title("Title"),
  timeAsc("Time Asc"),
  timeDesc("Time Desc"),
  maxFavorites("Favorite Num"), // 单本收藏数最多排序
  favoritesCompareComicPages("Favorite Num Compare Comic Pages"); // 单本收藏数比上总页数

  final String value;

  const ImageFavoriteSortType(this.value);

  static ImageFavoriteSortType fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return title;
  }
}

enum TimeFilterEnum {
  all("All"),
  lastWeek("Last Week"),
  lastMonth("Last Month"),
  lastHalfYear("Last Half Year"),
  lastYear("Last Year"); // 单本收藏数最多排序

  final String value;
  const TimeFilterEnum(this.value);
  static TimeFilterEnum fromString(String value) {
    for (var type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return all;
  }
}

const timeFilterList = [
  TimeFilterEnum.all,
  TimeFilterEnum.lastWeek,
  TimeFilterEnum.lastMonth,
  TimeFilterEnum.lastHalfYear,
  TimeFilterEnum.lastYear,
];
const numFilterList = ['0', '1', '2', '5', '10', '20', '50', '100'];
getDateTimeRangeFromFilter(String timeFilter) {
  DateTime now = DateTime.now();
  DateTime start = now;
  DateTime end = now;
  try {
    if (timeFilter == TimeFilterEnum.all.value) {
      start = DateTime(2025, 1, 1);
      end = DateTime(2099, 12, 31);
    } else if (timeFilter == TimeFilterEnum.lastWeek.value) {
      start = now.subtract(const Duration(days: 7));
    } else if (timeFilter == TimeFilterEnum.lastMonth.value) {
      start = now.subtract(const Duration(days: 30));
    } else if (timeFilter == TimeFilterEnum.lastHalfYear.value) {
      start = now.subtract(const Duration(days: 180));
    } else if (timeFilter == TimeFilterEnum.lastYear.value) {
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
