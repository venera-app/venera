part of 'comic_source.dart';

bool compareSemVer(String ver1, String ver2) {
  ver1 = ver1.replaceFirst("-", ".");
  ver2 = ver2.replaceFirst("-", ".");
  List<String> v1 = ver1.split('.');
  List<String> v2 = ver2.split('.');

  for (int i = 0; i < 3; i++) {
    int num1 = int.parse(v1[i]);
    int num2 = int.parse(v2[i]);

    if (num1 > num2) {
      return true;
    } else if (num1 < num2) {
      return false;
    }
  }

  var v14 = v1.elementAtOrNull(3);
  var v24 = v2.elementAtOrNull(3);

  if (v14 != v24) {
    if (v14 == null && v24 != "hotfix") {
      return true;
    } else if (v14 == null) {
      return false;
    }
    if (v24 == null) {
      if (v14 == "hotfix") {
        return true;
      }
      return false;
    }
    return v14.compareTo(v24) > 0;
  }

  return false;
}

class ComicSourceParseException implements Exception {
  final String message;

  ComicSourceParseException(this.message);

  @override
  String toString() {
    return message;
  }
}

class ComicSourceParser {
  /// comic source key
  String? _key;

  String? _name;

  Future<ComicSource> createAndParse(String js, String fileName) async {
    if (!fileName.endsWith("js")) {
      fileName = "$fileName.js";
    }
    var file = File(FilePath.join(App.dataPath, "comic_source", fileName));
    if (file.existsSync()) {
      int i = 0;
      while (file.existsSync()) {
        file = File(FilePath.join(App.dataPath, "comic_source",
            "${fileName.split('.').first}($i).js"));
        i++;
      }
    }
    await file.writeAsString(js);
    try {
      return await parse(js, file.path);
    } catch (e) {
      await file.delete();
      rethrow;
    }
  }

  Future<ComicSource> parse(String js, String filePath) async {
    js = js.replaceAll("\r\n", "\n");
    var line1 = js
        .split('\n')
        .firstWhereOrNull((element) => element.removeAllBlank.isNotEmpty);
    if (line1 == null ||
        !line1.startsWith("class ") ||
        !line1.contains("extends ComicSource")) {
      throw ComicSourceParseException("Invalid Content");
    }
    var className = line1.split("class")[1].split("extends ComicSource").first;
    className = className.trim();
    JsEngine().runCode("""
      (() => {
        $js
        this['temp'] = new $className()
      }).call()
    """);
    _name = JsEngine().runCode("this['temp'].name") ??
        (throw ComicSourceParseException('name is required'));
    var key = JsEngine().runCode("this['temp'].key") ??
        (throw ComicSourceParseException('key is required'));
    var version = JsEngine().runCode("this['temp'].version") ??
        (throw ComicSourceParseException('version is required'));
    var minAppVersion = JsEngine().runCode("this['temp'].minAppVersion");
    var url = JsEngine().runCode("this['temp'].url");
    var matchBriefIdRegex =
        JsEngine().runCode("this['temp'].comic.matchBriefIdRegex");
    if (minAppVersion != null) {
      if (compareSemVer(minAppVersion, App.version.split('-').first)) {
        throw ComicSourceParseException(
            "minAppVersion $minAppVersion is required");
      }
    }
    for (var source in ComicSource.all()) {
      if (source.key == key) {
        throw ComicSourceParseException("key($key) already exists");
      }
    }
    _key = key;
    _checkKeyValidation();

    JsEngine().runCode("""
      ComicSource.sources.$_key = this['temp'];
    """);

    final account = _loadAccountConfig();
    final explorePageData = _loadExploreData();
    final categoryPageData = _loadCategoryData();
    final categoryComicsData = _loadCategoryComicsData();
    final searchData = _loadSearchData();
    final loadComicFunc = _parseLoadComicFunc();
    final loadComicThumbnailFunc = _parseThumbnailLoader();
    final loadComicPagesFunc = _parseLoadComicPagesFunc();
    final getImageLoadingConfigFunc = _parseImageLoadingConfigFunc();
    final getThumbnailLoadingConfigFunc = _parseThumbnailLoadingConfigFunc();
    final favoriteData = _loadFavoriteData();
    final commentsLoader = _parseCommentsLoader();
    final sendCommentFunc = _parseSendCommentFunc();
    final likeFunc = _parseLikeFunc();

    var source = ComicSource(
      _name!,
      key,
      account,
      categoryPageData,
      categoryComicsData,
      favoriteData,
      explorePageData,
      searchData,
      [],
      loadComicFunc,
      loadComicThumbnailFunc,
      loadComicPagesFunc,
      getImageLoadingConfigFunc,
      getThumbnailLoadingConfigFunc,
      matchBriefIdRegex,
      filePath,
      url ?? "",
      version ?? "1.0.0",
      commentsLoader,
      sendCommentFunc,
      likeFunc,
    );

    await source.loadData();

    Future.delayed(const Duration(milliseconds: 50), () {
      JsEngine().runCode("ComicSource.sources.$_key.init()");
    });

    return source;
  }

  _checkKeyValidation() {
    // 仅允许数字和字母以及下划线
    if (!_key!.contains(RegExp(r"^[a-zA-Z0-9_]+$"))) {
      throw ComicSourceParseException("key $_key is invalid");
    }
  }

  bool _checkExists(String index) {
    return JsEngine().runCode("ComicSource.sources.$_key.$index !== null "
        "&& ComicSource.sources.$_key.$index !== undefined");
  }

  dynamic _getValue(String index) {
    return JsEngine().runCode("ComicSource.sources.$_key.$index");
  }

  AccountConfig? _loadAccountConfig() {
    if (!_checkExists("account")) {
      return null;
    }

    Future<Res<bool>> login(account, pwd) async {
      try {
        await JsEngine().runCode("""
          ComicSource.sources.$_key.account.login(${jsonEncode(account)}, 
          ${jsonEncode(pwd)})
        """);
        var source = ComicSource.find(_key!)!;
        source.data["account"] = <String>[account, pwd];
        source.saveData();
        return const Res(true);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    }

    void logout() {
      JsEngine().runCode("ComicSource.sources.$_key.account.logout()");
    }

    return AccountConfig(login, _getValue("account.login.website"),
        _getValue("account.registerWebsite"), logout);
  }

  List<ExplorePageData> _loadExploreData() {
    if (!_checkExists("explore")) {
      return const [];
    }
    var length = JsEngine().runCode("ComicSource.sources.$_key.explore.length");
    var pages = <ExplorePageData>[];
    for (int i = 0; i < length; i++) {
      final String title = _getValue("explore[$i].title");
      final String type = _getValue("explore[$i].type");
      Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;
      Future<Res<List<Comic>>> Function(int page)? loadPage;
      if (type == "singlePageWithMultiPart") {
        loadMultiPart = () async {
          try {
            var res = await JsEngine()
                .runCode("ComicSource.sources.$_key.explore[$i].load()");
            return Res(List.from(res.keys
                .map((e) => ExplorePagePart(
                    e,
                    (res[e] as List)
                        .map<Comic>((e) => Comic.fromJson(e, _key!))
                        .toList(),
                    null))
                .toList()));
          } catch (e, s) {
            Log.error("Data Analysis", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      } else if (type == "multiPageComicList") {
        loadPage = (int page) async {
          try {
            var res = await JsEngine().runCode(
                "ComicSource.sources.$_key.explore[$i].load(${jsonEncode(page)})");
            return Res(
                List.generate(res["comics"].length,
                    (index) => Comic.fromJson(res["comics"][index], _key!)),
                subData: res["maxPage"]);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        };
      }
      pages.add(ExplorePageData(
          title,
          switch (type) {
            "singlePageWithMultiPart" =>
              ExplorePageType.singlePageWithMultiPart,
            "multiPageComicList" => ExplorePageType.multiPageComicList,
            _ =>
              throw ComicSourceParseException("Unknown explore page type $type")
          },
          loadPage,
          loadMultiPart));
    }
    return pages;
  }

  CategoryData? _loadCategoryData() {
    var doc = _getValue("category");

    if (doc?["title"] == null) {
      return null;
    }

    final String title = doc["title"];
    final bool? enableRankingPage = doc["enableRankingPage"];

    var categoryParts = <BaseCategoryPart>[];

    for (var c in doc["parts"]) {
      final String name = c["name"];
      final String type = c["type"];
      final List<String> tags = List.from(c["categories"]);
      final String itemType = c["itemType"];
      final List<String>? categoryParams =
          c["categoryParams"] == null ? null : List.from(c["categoryParams"]);
      if (type == "fixed") {
        categoryParts
            .add(FixedCategoryPart(name, tags, itemType, categoryParams));
      } else if (type == "random") {
        categoryParts.add(
            RandomCategoryPart(name, tags, c["randomNumber"] ?? 1, itemType));
      }
    }

    return CategoryData(
        title: title,
        categories: categoryParts,
        enableRankingPage: enableRankingPage ?? false,
        key: title);
  }

  CategoryComicsData? _loadCategoryComicsData() {
    if (!_checkExists("categoryComics")) return null;
    var options = <CategoryComicsOptions>[];
    for (var element in _getValue("categoryComics.optionList")) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(CategoryComicsOptions(
          map,
          List.from(element["notShowWhen"] ?? []),
          element["showWhen"] == null ? null : List.from(element["showWhen"])));
    }
    RankingData? rankingData;
    if (_checkExists("categoryComics.ranking")) {
      var options = <String, String>{};
      for (var option in _getValue("categoryComics.ranking.options")) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        options[key] = value;
      }
      rankingData = RankingData(options, (option, page) async {
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.categoryComics.ranking.load(
              ${jsonEncode(option)}, ${jsonEncode(page)})
          """);
          return Res(
              List.generate(res["comics"].length,
                  (index) => Comic.fromJson(res["comics"][index], _key!)),
              subData: res["maxPage"]);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      });
    }
    return CategoryComicsData(options, (category, param, options, page) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.categoryComics.load(
            ${jsonEncode(category)}, 
            ${jsonEncode(param)}, 
            ${jsonEncode(options)}, 
            ${jsonEncode(page)}
          )
        """);
        return Res(
            List.generate(res["comics"].length,
                (index) => Comic.fromJson(res["comics"][index], _key!)),
            subData: res["maxPage"]);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    }, rankingData: rankingData);
  }

  SearchPageData? _loadSearchData() {
    if (!_checkExists("search")) return null;
    var options = <SearchOptions>[];
    for (var element in _getValue("search.optionList") ?? []) {
      LinkedHashMap<String, String> map = LinkedHashMap<String, String>();
      for (var option in element["options"]) {
        if (option.isEmpty || !option.contains("-")) {
          continue;
        }
        var split = option.split("-");
        var key = split.removeAt(0);
        var value = split.join("-");
        map[key] = value;
      }
      options.add(SearchOptions(map, element["label"]));
    }
    return SearchPageData(options, (keyword, page, searchOption) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.search.load(
            ${jsonEncode(keyword)}, ${jsonEncode(searchOption)}, ${jsonEncode(page)})
        """);
        return Res(
            List.generate(res["comics"].length,
                (index) => Comic.fromJson(res["comics"][index], _key!)),
            subData: res["maxPage"]);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    });
  }

  LoadComicFunc? _parseLoadComicFunc() {
    return (id) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadInfo(${jsonEncode(id)})
        """);
        if (res is! Map<String, dynamic>) throw "Invalid data";
        res['comicId'] = id;
        res['sourceKey'] = _key;
        return Res(ComicDetails.fromJson(res));
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  LoadComicPagesFunc? _parseLoadComicPagesFunc() {
    return (id, ep) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadEp(${jsonEncode(id)}, ${jsonEncode(ep)})
        """);
        return Res(List.from(res["images"]));
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  FavoriteData? _loadFavoriteData() {
    if (!_checkExists("favorites")) return null;

    final bool multiFolder = _getValue("favorites.multiFolder");

    Future<Res<T>> retryZone<T>(Future<Res<T>> Function() func) async {
      if (!ComicSource.find(_key!)!.isLogged) {
        return const Res.error("Not login");
      }
      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await ComicSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    }

    Future<Res<bool>> addOrDelFavFunc(comicId, folderId, isAdding) async {
      func() async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.addOrDelFavorite(
              ${jsonEncode(comicId)}, ${jsonEncode(folderId)}, ${jsonEncode(isAdding)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res<bool>.error(e.toString());
        }
      }

      return retryZone(func);
    }

    Future<Res<List<Comic>>> loadComic(int page, [String? folder]) async {
      Future<Res<List<Comic>>> func() async {
        try {
          var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadComics(
              ${jsonEncode(page)}, ${jsonEncode(folder)})
          """);
          return Res(
              List.generate(res["comics"].length,
                  (index) => Comic.fromJson(res["comics"][index], _key!)),
              subData: res["maxPage"]);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      }

      return retryZone(func);
    }

    Future<Res<Map<String, String>>> Function([String? comicId])? loadFolders;

    Future<Res<bool>> Function(String name)? addFolder;

    Future<Res<bool>> Function(String key)? deleteFolder;

    if (multiFolder) {
      loadFolders = ([String? comicId]) async {
        Future<Res<Map<String, String>>> func() async {
          try {
            var res = await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.loadFolders(${jsonEncode(comicId)})
          """);
            List<String>? subData;
            if (res["favorited"] != null) {
              subData = List.from(res["favorited"]);
            }
            return Res(Map.from(res["folders"]), subData: subData);
          } catch (e, s) {
            Log.error("Network", "$e\n$s");
            return Res.error(e.toString());
          }
        }

        return retryZone(func);
      };
      addFolder = (name) async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.addFolder(${jsonEncode(name)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      };
      deleteFolder = (key) async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.favorites.deleteFolder(${jsonEncode(key)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      };
    }

    return FavoriteData(
      key: _key!,
      title: _name!,
      multiFolder: multiFolder,
      loadComic: loadComic,
      loadFolders: loadFolders,
      addFolder: addFolder,
      deleteFolder: deleteFolder,
      addOrDelFavorite: addOrDelFavFunc,
    );
  }

  CommentsLoader? _parseCommentsLoader() {
    if (!_checkExists("comic.loadComments")) return null;
    return (id, subId, page, replyTo) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadComments(
            ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(page)}, ${jsonEncode(replyTo)})
        """);
        return Res(
            (res["comments"] as List)
                .map((e) => Comment(e["userName"], e["avatar"], e["content"],
                    e["time"], e["replyCount"], e["id"].toString()))
                .toList(),
            subData: res["maxPage"]);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  SendCommentFunc? _parseSendCommentFunc() {
    if (!_checkExists("comic.sendComment")) return null;
    return (id, subId, content, replyTo) async {
      Future<Res<bool>> func() async {
        try {
          await JsEngine().runCode("""
            ComicSource.sources.$_key.comic.sendComment(
              ${jsonEncode(id)}, ${jsonEncode(subId)}, ${jsonEncode(content)}, ${jsonEncode(replyTo)})
          """);
          return const Res(true);
        } catch (e, s) {
          Log.error("Network", "$e\n$s");
          return Res.error(e.toString());
        }
      }

      var res = await func();
      if (res.error && res.errorMessage!.contains("Login expired")) {
        var reLoginRes = await ComicSource.find(_key!)!.reLogin();
        if (!reLoginRes) {
          return const Res.error("Login expired and re-login failed");
        } else {
          return func();
        }
      }
      return res;
    };
  }

  GetImageLoadingConfigFunc? _parseImageLoadingConfigFunc() {
    if (!_checkExists("comic.onImageLoad")) {
      return null;
    }
    return (imageKey, comicId, ep) {
      return JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onImageLoad(
            ${jsonEncode(imageKey)}, ${jsonEncode(comicId)}, ${jsonEncode(ep)})
        """) as Map<String, dynamic>;
    };
  }

  GetThumbnailLoadingConfigFunc? _parseThumbnailLoadingConfigFunc() {
    if (!_checkExists("comic.onThumbnailLoad")) {
      return null;
    }
    return (imageKey) {
      var res = JsEngine().runCode("""
          ComicSource.sources.$_key.comic.onThumbnailLoad(${jsonEncode(imageKey)})
        """);
      if (res is! Map) {
        Log.error("Network", "function onThumbnailLoad return invalid data");
        throw "function onThumbnailLoad return invalid data";
      }
      return res as Map<String, dynamic>;
    };
  }

  ComicThumbnailLoader? _parseThumbnailLoader() {
    if (!_checkExists("comic.loadThumbnail")) {
      return null;
    }
    return (id, next) async {
      try {
        var res = await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.loadThumbnail(${jsonEncode(id)}, ${jsonEncode(next)})
        """);
        return Res(List<String>.from(res['thumbnails']), subData: res['next']);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }

  LikeOrUnlikeComicFunc? _parseLikeFunc() {
    if (!_checkExists("comic.likeOrUnlikeComic")) {
      return null;
    }
    return (id, isLiking) async {
      try {
        await JsEngine().runCode("""
          ComicSource.sources.$_key.comic.likeOrUnlikeComic(${jsonEncode(id)}, ${jsonEncode(isLiking)})
        """);
        return const Res(true);
      } catch (e, s) {
        Log.error("Network", "$e\n$s");
        return Res.error(e.toString());
      }
    };
  }
}
