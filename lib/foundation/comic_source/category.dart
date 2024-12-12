part of 'comic_source.dart';

class CategoryData {
  /// The title is displayed in the tab bar.
  final String title;

  /// 当使用中文语言时, 英文的分类标签将在构建页面时被翻译为中文
  final List<BaseCategoryPart> categories;

  final bool enableRankingPage;

  final String key;

  final List<CategoryButtonData> buttons;

  /// Data class for building category page.
  const CategoryData({
    required this.title,
    required this.categories,
    required this.enableRankingPage,
    required this.key,
    this.buttons = const [],
  });
}

class CategoryButtonData {
  final String label;

  final void Function() onTap;

  const CategoryButtonData({
    required this.label,
    required this.onTap,
  });
}

abstract class BaseCategoryPart {
  String get title;

  List<String> get categories;

  List<String>? get categoryParams => null;

  bool get enableRandom;

  String get categoryType;

  /// Data class for building a part of category page.
  const BaseCategoryPart();
}

class FixedCategoryPart extends BaseCategoryPart {
  @override
  final List<String> categories;

  @override
  bool get enableRandom => false;

  @override
  final String title;

  @override
  final String categoryType;

  @override
  final List<String>? categoryParams;

  /// A [BaseCategoryPart] that show fixed tags on category page.
  const FixedCategoryPart(this.title, this.categories, this.categoryType,
      [this.categoryParams]);
}

class RandomCategoryPart extends BaseCategoryPart {
  final List<String> tags;

  final int randomNumber;

  @override
  final String title;

  @override
  bool get enableRandom => true;

  @override
  final String categoryType;

  List<String> _categories() {
    if (randomNumber >= tags.length) {
      return tags;
    }
    var start = math.Random().nextInt(tags.length - randomNumber);
    return tags.sublist(start, start + randomNumber);
  }

  @override
  List<String> get categories => _categories();

  /// A [BaseCategoryPart] that show random tags on category page.
  const RandomCategoryPart(
      this.title, this.tags, this.randomNumber, this.categoryType);
}

class RandomCategoryPartWithRuntimeData extends BaseCategoryPart {
  final Iterable<String> Function() loadTags;

  final int randomNumber;

  @override
  final String title;

  @override
  bool get enableRandom => true;

  @override
  final String categoryType;

  static final random = math.Random();

  List<String> _categories() {
    var tags = loadTags();
    if (randomNumber >= tags.length) {
      return tags.toList();
    }
    final start = random.nextInt(tags.length - randomNumber);
    var res = List.filled(randomNumber, '');
    int index = -1;
    for (var s in tags) {
      index++;
      if (start > index) {
        continue;
      } else if (index == start + randomNumber) {
        break;
      }
      res[index - start] = s;
    }
    return res;
  }

  @override
  List<String> get categories => _categories();

  /// A [BaseCategoryPart] that show random tags on category page.
  RandomCategoryPartWithRuntimeData(
      this.title, this.loadTags, this.randomNumber, this.categoryType);
}

CategoryData getCategoryDataWithKey(String key) {
  for (var source in ComicSource._sources) {
    if (source.categoryData?.key == key) {
      return source.categoryData!;
    }
  }
  throw "Unknown category key $key";
}
