part of 'settings_page.dart';

class LocalFavoritesSettings extends StatefulWidget {
  const LocalFavoritesSettings({super.key});

  @override
  State<LocalFavoritesSettings> createState() => _LocalFavoritesSettingsState();
}

class _LocalFavoritesSettingsState extends State<LocalFavoritesSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Local Favorites".tl)),
        SelectSetting(
          title: "Add new favorite to".tl,
          settingKey: "newFavoriteAddTo",
          optionTranslation: const {
            "start": "Start",
            "end": "End",
          },
        ).toSliver(),
        SelectSetting(
          title: "Move favorite after reading".tl,
          settingKey: "moveFavoriteAfterRead",
          optionTranslation: const {
            "none": "None",
            "end": "End",
            "start": "Start",
          },
        ).toSliver(),
        SelectSetting(
          title: "Quick Favorite".tl,
          settingKey: "quickFavorite",
          help: "Long press on the favorite button to quickly add to this folder".tl,
          optionTranslation: {
            for (var e in LocalFavoritesManager().folderNames) e: e
          },
        ).toSliver(),
      ],
    );
  }
}
