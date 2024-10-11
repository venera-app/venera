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
        const SelectSetting(
          title: "Add new favorite to",
          settingKey: "newFavoriteAddTo",
          optionTranslation: {
            "start": "Start",
            "end": "End",
          },
        ).toSliver(),
        const SelectSetting(
          title: "Move favorite after read",
          settingKey: "moveFavoriteAfterRead",
          optionTranslation: {
            "none": "None",
            "end": "End",
            "start": "Start",
          },
        ).toSliver(),
      ],
    );
  }
}
