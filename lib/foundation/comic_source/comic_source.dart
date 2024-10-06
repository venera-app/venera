library comic_source;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/io.dart';

import '../js_engine.dart';
import '../log.dart';

part 'category.dart';
part 'favorites.dart';
part 'parser.dart';
part 'models.dart';

/// build comic list, [Res.subData] should be maxPage or null if there is no limit.
typedef ComicListBuilder = Future<Res<List<Comic>>> Function(int page);

typedef LoginFunction = Future<Res<bool>> Function(String, String);

typedef LoadComicFunc = Future<Res<ComicDetails>> Function(String id);

typedef LoadComicPagesFunc = Future<Res<List<String>>> Function(
    String id, String? ep);

typedef CommentsLoader = Future<Res<List<Comment>>> Function(
    String id, String? subId, int page, String? replyTo);

typedef SendCommentFunc = Future<Res<bool>> Function(
    String id, String? subId, String content, String? replyTo);

typedef GetImageLoadingConfigFunc = Map<String, dynamic> Function(
    String imageKey, String comicId, String epId)?;
typedef GetThumbnailLoadingConfigFunc = Map<String, dynamic> Function(
    String imageKey)?;

typedef ComicThumbnailLoader = Future<Res<List<String>>> Function(
    String comicId, String? next);

typedef LikeOrUnlikeComicFunc = Future<Res<bool>> Function(
    String comicId, bool isLiking);

/// [isLiking] is true if the user is liking the comment, false if unliking.
/// return the new likes count or null.
typedef LikeCommentFunc = Future<Res<int?>> Function(String comicId, String? subId, String commentId, bool isLiking);

/// [isUp] is true if the user is upvoting the comment, false if downvoting.
/// return the new vote count or null.
typedef VoteCommentFunc = Future<Res<int?>> Function(String comicId, String? subId, String commentId, bool isUp, bool isCancel);

class ComicSource {
  static final List<ComicSource> _sources = [];

  static final List<Function> _listeners = [];

  static void addListener(Function listener) {
    _listeners.add(listener);
  }

  static void removeListener(Function listener) {
    _listeners.remove(listener);
  }

  static void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  static List<ComicSource> all() => List.from(_sources);

  static ComicSource? find(String key) =>
      _sources.firstWhereOrNull((element) => element.key == key);

  static ComicSource? fromIntKey(int key) =>
      _sources.firstWhereOrNull((element) => element.key.hashCode == key);

  static Future<void> init() async {
    final path = "${App.dataPath}/comic_source";
    if (!(await Directory(path).exists())) {
      Directory(path).create();
      return;
    }
    await for (var entity in Directory(path).list()) {
      if (entity is File && entity.path.endsWith(".js")) {
        try {
          var source = await ComicSourceParser()
              .parse(await entity.readAsString(), entity.absolute.path);
          _sources.add(source);
        } catch (e, s) {
          Log.error("ComicSource", "$e\n$s");
        }
      }
    }
  }

  static Future reload() async {
    _sources.clear();
    JsEngine().runCode("ComicSource.sources = {};");
    await init();
    notifyListeners();
  }

  static void add(ComicSource source) {
    _sources.add(source);
    notifyListeners();
  }

  static void remove(String key) {
    _sources.removeWhere((element) => element.key == key);
    notifyListeners();
  }

  /// Name of this source.
  final String name;

  /// Identifier of this source.
  final String key;

  int get intKey {
    return key.hashCode;
  }

  /// Account config.
  final AccountConfig? account;

  /// Category data used to build a static category tags page.
  final CategoryData? categoryData;

  /// Category comics data used to build a comics page with a category tag.
  final CategoryComicsData? categoryComicsData;

  /// Favorite data used to build favorite page.
  final FavoriteData? favoriteData;

  /// Explore pages.
  final List<ExplorePageData> explorePages;

  /// Search page.
  final SearchPageData? searchPageData;

  /// Settings.
  final List<SettingItem> settings;

  /// Load comic info.
  final LoadComicFunc? loadComicInfo;

  final ComicThumbnailLoader? loadComicThumbnail;

  /// Load comic pages.
  final LoadComicPagesFunc? loadComicPages;

  final Map<String, dynamic> Function(
      String imageKey, String comicId, String epId)? getImageLoadingConfig;

  final Map<String, dynamic> Function(String imageKey)?
      getThumbnailLoadingConfig;

  var data = <String, dynamic>{};

  bool get isLogged => data["account"] != null;

  final String filePath;

  final String url;

  final String version;

  final CommentsLoader? commentsLoader;

  final SendCommentFunc? sendCommentFunc;

  final RegExp? idMatcher;

  final LikeOrUnlikeComicFunc? likeOrUnlikeComic;

  final VoteCommentFunc? voteCommentFunc;

  final LikeCommentFunc? likeCommentFunc;

  Future<void> loadData() async {
    var file = File("${App.dataPath}/comic_source/$key.data");
    if (await file.exists()) {
      data = Map.from(jsonDecode(await file.readAsString()));
    }
  }

  bool _isSaving = false;
  bool _haveWaitingTask = false;

  Future<void> saveData() async {
    if (_haveWaitingTask) return;
    while (_isSaving) {
      _haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 20));
      _haveWaitingTask = false;
    }
    _isSaving = true;
    var file = File("${App.dataPath}/comic_source/$key.data");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));
    _isSaving = false;
  }

  Future<bool> reLogin() async {
    if (data["account"] == null) {
      return false;
    }
    final List accountData = data["account"];
    var res = await account!.login!(accountData[0], accountData[1]);
    if (res.error) {
      Log.error("Failed to re-login", res.errorMessage ?? "Error");
    }
    return !res.error;
  }

  ComicSource(
      this.name,
      this.key,
      this.account,
      this.categoryData,
      this.categoryComicsData,
      this.favoriteData,
      this.explorePages,
      this.searchPageData,
      this.settings,
      this.loadComicInfo,
      this.loadComicThumbnail,
      this.loadComicPages,
      this.getImageLoadingConfig,
      this.getThumbnailLoadingConfig,
      this.filePath,
      this.url,
      this.version,
      this.commentsLoader,
      this.sendCommentFunc,
      this.likeOrUnlikeComic,
      this.voteCommentFunc,
      this.likeCommentFunc,)
      : idMatcher = null;
}

class AccountConfig {
  final LoginFunction? login;

  final FutureOr<void> Function(BuildContext)? onLogin;

  final String? loginWebsite;

  final String? registerWebsite;

  final void Function() logout;

  final bool allowReLogin;

  final List<AccountInfoItem> infoItems;

  const AccountConfig(
      this.login, this.loginWebsite, this.registerWebsite, this.logout,
      {this.onLogin})
      : allowReLogin = true,
        infoItems = const [];
}

class AccountInfoItem {
  final String title;
  final String Function()? data;
  final void Function()? onTap;
  final WidgetBuilder? builder;

  AccountInfoItem({required this.title, this.data, this.onTap, this.builder});
}

class LoadImageRequest {
  String url;

  Map<String, String> headers;

  LoadImageRequest(this.url, this.headers);
}

class ExplorePageData {
  final String title;

  final ExplorePageType type;

  final ComicListBuilder? loadPage;

  final Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;

  /// return a `List` contains `List<Comic>` or `ExplorePagePart`
  final Future<Res<List<Object>>> Function(int index)? loadMixed;

  final WidgetBuilder? overridePageBuilder;

  ExplorePageData(this.title, this.type, this.loadPage, this.loadMultiPart)
      : loadMixed = null,
        overridePageBuilder = null;
}

class ExplorePagePart {
  final String title;

  final List<Comic> comics;

  /// If this is not null, the [ExplorePagePart] will show a button to jump to new page.
  ///
  /// Value of this field should match the following format:
  ///   - search:keyword
  ///   - category:categoryName
  ///
  /// End with `@`+`param` if the category has a parameter.
  final String? viewMore;

  const ExplorePagePart(this.title, this.comics, this.viewMore);
}

enum ExplorePageType {
  multiPageComicList,
  singlePageWithMultiPart,
  mixed,
  override,
}

typedef SearchFunction = Future<Res<List<Comic>>> Function(
    String keyword, int page, List<String> searchOption);

class SearchPageData {
  /// If this is not null, the default value of search options will be first element.
  final List<SearchOptions>? searchOptions;

  final Widget Function(BuildContext, List<String> initialValues,
      void Function(List<String>))? customOptionsBuilder;

  final Widget Function(String keyword, List<String> options)?
      overrideSearchResultBuilder;

  final SearchFunction? loadPage;

  final bool enableLanguageFilter;

  final bool enableTagsSuggestions;

  const SearchPageData(this.searchOptions, this.loadPage)
      : enableLanguageFilter = false,
        customOptionsBuilder = null,
        overrideSearchResultBuilder = null,
        enableTagsSuggestions = false;
}

class SearchOptions {
  final LinkedHashMap<String, String> options;

  final String label;

  const SearchOptions(this.options, this.label);

  String get defaultValue => options.keys.first;
}

class SettingItem {
  final String name;
  final String iconName;
  final SettingType type;
  final List<String>? options;

  const SettingItem(this.name, this.iconName, this.type, this.options);
}

enum SettingType {
  switcher,
  selector,
  input,
}

typedef CategoryComicsLoader = Future<Res<List<Comic>>> Function(
    String category, String? param, List<String> options, int page);

class CategoryComicsData {
  /// options
  final List<CategoryComicsOptions> options;

  /// [category] is the one clicked by the user on the category page.

  /// if [BaseCategoryPart.categoryParams] is not null, [param] will be not null.
  ///
  /// [Res.subData] should be maxPage or null if there is no limit.
  final CategoryComicsLoader load;

  final RankingData? rankingData;

  const CategoryComicsData(this.options, this.load, {this.rankingData});
}

class RankingData {
  final Map<String, String> options;

  final Future<Res<List<Comic>>> Function(String option, int page) load;

  const RankingData(this.options, this.load);
}

class CategoryComicsOptions {
  /// Use a [LinkedHashMap] to describe an option list.
  /// key is for loading comics, value is the name displayed on screen.
  /// Default value will be the first of the Map.
  final LinkedHashMap<String, String> options;

  /// If [notShowWhen] contains category's name, the option will not be shown.
  final List<String> notShowWhen;

  final List<String>? showWhen;

  const CategoryComicsOptions(this.options, this.notShowWhen, this.showWhen);
}

