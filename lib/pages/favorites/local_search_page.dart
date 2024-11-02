part of 'favorites_page.dart';

class LocalSearchPage extends StatefulWidget {
  const LocalSearchPage({super.key});

  @override
  State<LocalSearchPage> createState() => _LocalSearchPageState();
}

class _LocalSearchPageState extends State<LocalSearchPage> {
  String keyword = '';

  var comics = <FavoriteItemWithFolderInfo>[];

  late final SearchBarController controller;

  @override
  void initState() {
    super.initState();
    controller = SearchBarController(onSearch: (text) {
      keyword = text;
      comics = LocalFavoritesManager().search(keyword);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(slivers: [
        SliverSearchBar(controller: controller),
        SliverGridComics(
          comics: comics,
          badgeBuilder: (c) {
            return (c as FavoriteItemWithFolderInfo).folder;
          },
        ),
      ]),
    );
  }
}
