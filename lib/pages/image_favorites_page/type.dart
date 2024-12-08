enum ImageFavoriteSortType {
  name("name"),
  timeAsc("time_asc"),
  timeDesc("time_desc"),
  favoriteNumDesc("favorite_num_desc");

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

class ImageFavoriteSortItem {
  final String title;
  final ImageFavoriteSortType value;

  ImageFavoriteSortItem(this.title, this.value);
}
