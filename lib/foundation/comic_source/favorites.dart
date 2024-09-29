part of 'comic_source.dart';

typedef AddOrDelFavFunc = Future<Res<bool>> Function(String comicId, String folderId, bool isAdding);

class FavoriteData{
  final String key;

  final String title;

  final bool multiFolder;

  final Future<Res<List<Comic>>> Function(int page, [String? folder]) loadComic;

  /// key-id, value-name
  ///
  /// if comicId is not null, Res.subData is the folders that the comic is in
  final Future<Res<Map<String, String>>> Function([String? comicId])? loadFolders;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String key)? deleteFolder;

  /// A value of null disables this feature
  final Future<Res<bool>> Function(String name)? addFolder;

  /// A value of null disables this feature
  final String? allFavoritesId;

  final AddOrDelFavFunc? addOrDelFavorite;

  const FavoriteData({
    required this.key,
    required this.title,
    required this.multiFolder,
    required this.loadComic,
    this.loadFolders,
    this.deleteFolder,
    this.addFolder,
    this.allFavoritesId,
    this.addOrDelFavorite});
}

FavoriteData getFavoriteData(String key){
  var source = ComicSource.find(key) ?? (throw "Unknown source key: $key");
  return source.favoriteData!;
}

FavoriteData? getFavoriteDataOrNull(String key){
  var source = ComicSource.find(key);
  return source?.favoriteData;
}