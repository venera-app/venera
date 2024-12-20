part of 'image_favorites_page.dart';

class ImageFavoritesList extends StatefulWidget {
  const ImageFavoritesList(
      {super.key,
      required this.sortType,
      required this.timeFilterSelect,
      required this.keyword});
  final ImageFavoriteSortType sortType;
  final String timeFilterSelect;
  final String keyword;

  @override
  State<ImageFavoritesList> createState() => ImageFavoritesListState();
}

class ImageFavoritesListState extends State<ImageFavoritesList> {
  // 所有的图片收藏
  List<ImageFavoritesGroup> imageFavoritesGroup = [];
  late List<ImageFavoritesGroup> curImageFavoritesGroup;
  late List<DateTime> timeFilter;
  @override
  void initState() {
    List<ImageFavorite> imageFavorites = ImageFavoriteManager.getAll();

    for (var ele in imageFavorites) {
      try {
        ImageFavoritesGroup tempGroup = imageFavoritesGroup
            .where(
              (i) => i.id == ele.id && i.eid == ele.ep.toString(),
            )
            .first;
        tempGroup.imageFavorites.add(ele);
      } catch (e) {
        imageFavoritesGroup
            .add(ImageFavoritesGroup(ele.id, [ele], ele.ep.toString()));
      }
    }
    super.initState();
  }

  void getImageFavorites() {
    timeFilter = getDateTimeRangeFromFilter(widget.timeFilterSelect);
    // 筛选到最终列表
    curImageFavoritesGroup = imageFavoritesGroup.where((ele) {
      DateTime start = timeFilter[0];
      DateTime end = timeFilter[1];
      DateTime dateTimeToCheck = ele.firstTime;
      return dateTimeToCheck.isAfter(start) && dateTimeToCheck.isBefore(end) ||
          dateTimeToCheck == start ||
          dateTimeToCheck == end;
    }).toList();
    // 给列表排序
    switch (widget.sortType) {
      case ImageFavoriteSortType.name:
        curImageFavoritesGroup.sort((a, b) => a.title.compareTo(b.title));
        break;
      case ImageFavoriteSortType.timeAsc:
        curImageFavoritesGroup
            .sort((a, b) => a.firstTime.compareTo(b.firstTime));
        break;
      case ImageFavoriteSortType.timeDesc:
        curImageFavoritesGroup
            .sort((a, b) => b.firstTime.compareTo(a.firstTime));
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    getImageFavorites();
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      return ImageFavoritesItem(
          imageFavoritesGroup: curImageFavoritesGroup[index]);
    }, childCount: 10));
  }
}
