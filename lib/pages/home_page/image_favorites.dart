part of '../home_page.dart';

class ImageFavorites extends StatefulWidget {
  const ImageFavorites({super.key});

  @override
  State<ImageFavorites> createState() => ImageFavoritesState();
}

class ImageFavoritesState extends State<ImageFavorites> {
  void refreshImageFavorites() {
    setState(() {});
  }

  @override
  void initState() {
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
    ImageFavoriteManager().removeListener(refreshImageFavorites);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ImageFavoritePro> allImageFavoritePros = [];
    for (var comic in ImageFavoriteManager.imageFavoritesComicList) {
      allImageFavoritePros.addAll(comic.sortedImageFavoritePros);
    }
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const ImageFavoritesPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('Image Favorites'.tl, style: ts.s18),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              SizedBox(
                width: double.infinity,
                child: Text(
                  "@a Comic, @b image favorites".tlParams({
                    "a": ImageFavoriteManager.length.toString(),
                    "b": allImageFavoritePros.length
                  }),
                  style: const TextStyle(fontSize: 15),
                ).paddingHorizontal(16).paddingBottom(16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
