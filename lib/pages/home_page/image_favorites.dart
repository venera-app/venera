part of '../home_page.dart';

class ImageFavoritesFindComic {
  final String id;
  final String fullTitle;
  final String showTitle;
  final String sourceKey;

  const ImageFavoritesFindComic(
      this.id, this.fullTitle, this.showTitle, this.sourceKey);
}

class ImageFavoritesTextWithCount {
  final String text;
  final int count;
  const ImageFavoritesTextWithCount(this.text, this.count);
}

// 算出最喜欢的
class ImageFavoritesCompute {
  final List<ImageFavoritesTextWithCount> tags;
  final List<ImageFavoritesTextWithCount> authors;
  // 喜欢的图片数
  final List<ImageFavoritesFindComic> comicByNum;
  // 图片数比上总页数
  final List<ImageFavoritesFindComic> comicByPercentage;

  const ImageFavoritesCompute(
      this.tags, this.authors, this.comicByNum, this.comicByPercentage);
}

enum ImageFavoritesComputeType {
  tags,
  authors,
  comicByNum,
  comicByPercentage,
}

class ImageFavorites extends StatefulWidget {
  const ImageFavorites({super.key});

  @override
  State<ImageFavorites> createState() => ImageFavoritesState();
}

// 去掉这些没有意义的标签
List<String> exceptTags = [
  '連載中',
  '',
  'translated',
  'chinese',
  'sole male',
  'sole female',
  'original',
  'doujinshi',
  'manga',
  'multi-work series',
  'mosaic censorship',
  'dilf',
  'bbm',
  'uncensored',
  'full censorship'
].map((e) => e.toLowerCase()).toList();

class ImageFavoritesState extends State<ImageFavorites> {
  ImageFavoritesCompute? imageFavoritesCompute;
  List<ImageFavoritePro> allImageFavoritePros = [];
  static String separator = "*venera*";

  static ImageFavoritesFindComic fromStringToImageFavoritesFindComic(
      String str, String suffix, List<ImageFavoritesComic> tempComicsList) {
    List<String> temp = str.split(separator);
    String sourceKey = temp[0];
    String id = temp[1];
    ImageFavoritesComic comic = tempComicsList.firstWhere((e) {
      return e.sourceKey == sourceKey && e.id == id;
    });
    return ImageFavoritesFindComic(
        id,
        comic.title,
        '${comic.title.length > 36 ? comic.title.substring(0, 36) : comic.title}... $suffix',
        sourceKey);
  }

  // compute 需要传入字符串, 复杂对象无法传入
  static ImageFavoritesCompute computeImageFavorites(String temp) {
    List<ImageFavoritesComic> tempComics = List<ImageFavoritesComic>.from(
        jsonDecode(temp).map((e) => ImageFavoritesComic.fromJson(e)));
    Map<String, int> tagCount = {};
    Map<String, int> authorCount = {};
    Map<String, int> comicImageCount = {};
    Map<String, int> comicMaxPages = {};

    for (ImageFavoritesComic imageFavoritesComic in tempComics) {
      for (var tag in imageFavoritesComic.tags) {
        String finalTag = tag;
        tagCount[finalTag] = (tagCount[finalTag] ?? 0) + 1;
      }

      if (imageFavoritesComic.author != "") {
        String finalAuthor = imageFavoritesComic.author;
        authorCount[finalAuthor] = (authorCount[finalAuthor] ?? 0) +
            imageFavoritesComic.sortedImageFavoritePros.length;
      }
      // 小于10页的漫画不统计
      if (imageFavoritesComic.maxPageFromEp < 10) {
        continue;
      }
      // 统计漫画图片数和总页数
      String comicId =
          '${imageFavoritesComic.sourceKey}$separator${imageFavoritesComic.id}';
      comicImageCount[comicId] = (comicImageCount[comicId] ?? 0) +
          imageFavoritesComic.sortedImageFavoritePros.length;
      comicMaxPages[comicId] =
          (comicMaxPages[comicId] ?? 0) + imageFavoritesComic.maxPageFromEp;
    }

    // 按数量排序标签
    List<String> sortedTags = tagCount.keys.toList()
      ..sort((a, b) => tagCount[b]!.compareTo(tagCount[a]!));

    // 按数量排序作者
    List<String> sortedAuthors = authorCount.keys.toList()
      ..sort((a, b) => authorCount[b]!.compareTo(authorCount[a]!));

    // 按收藏数量排序漫画
    List<MapEntry<String, int>> sortedComicsByNum = comicImageCount.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 按收藏比例排序漫画
    List<MapEntry<String, int>> sortedComicsByPercentage = comicImageCount
        .entries
        .toList()
      ..sort((a, b) {
        double percentageA = comicImageCount[a.key]! / comicMaxPages[a.key]!;
        double percentageB = comicImageCount[b.key]! / comicMaxPages[b.key]!;
        return percentageB.compareTo(percentageA);
      });

    return ImageFavoritesCompute(
        sortedTags
            .where((tag) => !exceptTags.contains(tag.toLowerCase()))
            .map((tag) => ImageFavoritesTextWithCount(tag, tagCount[tag]!))
            .toList(),
        sortedAuthors
            .map((author) =>
                ImageFavoritesTextWithCount(author, authorCount[author]!))
            .toList(),
        sortedComicsByNum
            .map((comic) => fromStringToImageFavoritesFindComic(
                comic.key, '(${comic.value})', tempComics))
            .toList(),
        sortedComicsByPercentage
            .map((comic) => fromStringToImageFavoritesFindComic(
                comic.key,
                '(${(comicImageCount[comic.key]! / comicMaxPages[comic.key]! * 100).toStringAsFixed(1)}%)',
                tempComics))
            .toList());
  }

  void refreshImageFavorites() async {
    if (mounted) {
      imageFavoritesCompute = null;
      allImageFavoritePros = [];
      for (var comic in ImageFavoriteManager.imageFavoritesComicList) {
        allImageFavoritePros.addAll(comic.sortedImageFavoritePros);
      }
      setState(() {});
      // 避免性能开销, 开一个线程计算
      imageFavoritesCompute = await compute(computeImageFavorites,
          jsonEncode(ImageFavoriteManager.imageFavoritesComicList));
      setState(() {});
    }
  }

  @override
  void initState() {
    refreshImageFavorites();
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
    ImageFavoriteManager().removeListener(refreshImageFavorites);
    super.dispose();
  }

  Widget roundBtn(
    Object text,
    ImageFavoritesComputeType type,
  ) {
    bool textWithCount = text is ImageFavoritesTextWithCount;
    bool isAuthor = type == ImageFavoritesComputeType.authors;
    var enableTranslate = App.locale.languageCode == 'zh';
    String translateText = '';
    if (textWithCount) {
      translateText = enableTranslate ? text.text.translateTagsToCN : text.text;
      if (isAuthor) {
        translateText = TagsTranslation.artistTags[text.text] ?? text.text;
      }
    }
    return InkWell(
      onTap: () {
        RegExp regExpForTag = RegExp(r" \(\d+\)$");
        context.to(() => ImageFavoritesPage(
            initialKeyword: (textWithCount
                ? text.text.replaceAll(regExpForTag, '')
                : (text as ImageFavoritesFindComic).fullTitle)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          textWithCount
              ? "${enableTranslate ? translateText : text.text} (${text.count})"
              : (text as ImageFavoritesFindComic).showTitle,
        ),
      ),
    );
  }

  Widget listRoundBtn(List<Object> list, ImageFavoritesComputeType type) {
    return Expanded(
        child: SizedBox(
            height: 24,
            child: ListView.separated(
                separatorBuilder: (BuildContext context, int index) {
                  return SizedBox(width: 4);
                },
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  return roundBtn(list[index], type);
                })));
  }

  @override
  Widget build(BuildContext context) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Calculate your favorite from @a comics and @b images, After the parentheses are the number of pictures or the number of pictures compared to the number of comic pages"
                        .tlParams({
                      "a": ImageFavoriteManager.length.toString(),
                      "b": allImageFavoritePros.length
                    }),
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (imageFavoritesCompute != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "Author: ".tl,
                          style: const TextStyle(fontSize: 13),
                        ),
                        listRoundBtn(imageFavoritesCompute!.authors,
                            ImageFavoritesComputeType.authors)
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "Tags: ".tl,
                          style: const TextStyle(fontSize: 13),
                        ),
                        listRoundBtn(imageFavoritesCompute!.tags,
                            ImageFavoritesComputeType.tags)
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "Comics(number): ".tl,
                          style: const TextStyle(fontSize: 13),
                        ),
                        listRoundBtn(imageFavoritesCompute!.comicByNum,
                            ImageFavoritesComputeType.comicByNum)
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "Comics(percentage): ".tl,
                          style: const TextStyle(fontSize: 13),
                        ),
                        listRoundBtn(imageFavoritesCompute!.comicByPercentage,
                            ImageFavoritesComputeType.comicByPercentage)
                      ],
                    ),
                  ],
                ],
              ).paddingHorizontal(16).paddingBottom(16),
            ],
          ),
        ),
      ),
    );
  }
}
