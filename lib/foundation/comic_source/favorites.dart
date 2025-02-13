part of 'comic_source.dart';

typedef AddOrDelFavFunc = Future<Res<bool>> Function(
    String comicId, String folderId, bool isAdding, String? favId);

class FavoriteData {
  final String key;

  final String title;

  final bool multiFolder;

  // 这个收藏时间新旧顺序, 是为了最小成本同步远端的收藏, 只拉取远程最新收藏的漫画, 就不需要全拉取一遍了
  // 如果为 null, 当做从新到旧
  final bool? isOldToNewSort;

  final Future<Res<List<Comic>>> Function(int page, [String? folder])?
      loadComic;

  final Future<Res<List<Comic>>> Function(String? next, [String? folder])?
      loadNext;

  /// key-id, value-name
  ///
  /// if comicId is not null, Res.subData is the folders that the comic is in
  final Future<Res<Map<String, String>>> Function([String? comicId])?
      loadFolders;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String key)? deleteFolder;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String name)? addFolder;

  /// A value of null disables this feature
  final String? allFavoritesId;

  final AddOrDelFavFunc? addOrDelFavorite;

  final bool singleFolderForSingleComic;

  const FavoriteData({
    required this.key,
    required this.title,
    required this.multiFolder,
    required this.loadComic,
    required this.loadNext,
    this.loadFolders,
    this.deleteFolder,
    this.addFolder,
    this.allFavoritesId,
    this.addOrDelFavorite,
    this.isOldToNewSort,
    this.singleFolderForSingleComic = false,
  });
}

FavoriteData getFavoriteData(String key) {
  var source = ComicSource.find(key) ?? (throw "Unknown source key: $key");
  return source.favoriteData!;
}

FavoriteData? getFavoriteDataOrNull(String key) {
  var source = ComicSource.find(key);
  return source?.favoriteData;
}
