part of 'settings_page.dart';

class ExploreSettings extends StatefulWidget {
  const ExploreSettings({super.key});

  @override
  State<ExploreSettings> createState() => _ExploreSettingsState();
}

class _ExploreSettingsState extends State<ExploreSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Explore".tl)),
        SelectSetting(
          title: "Display mode of comic tile".tl,
          settingKey: "comicDisplayMode",
          optionTranslation: {
            "detailed": "Detailed".tl,
            "brief": "Brief".tl,
          },
        ).toSliver(),
        _SliderSetting(
          title: "Size of comic tile".tl,
          settingsIndex: "comicTileScale",
          interval: 0.05,
          min: 0.75,
          max: 1.25,
        ).toSliver(),
        _PopupWindowSetting(
          title: "Explore Pages".tl,
          builder: () {
            var pages = <String, String>{};
            for (var c in ComicSource.all()) {
              for (var page in c.explorePages) {
                pages[page.title] = page.title;
              }
            }
            return _MultiPagesFilter(
              title: "Explore Pages".tl,
              settingsIndex: "explore_pages",
              pages: pages,
            );
          },
        ).toSliver(),
        _PopupWindowSetting(
          title: "Category Pages".tl,
          builder: () {
            var pages = <String, String>{};
            for (var c in ComicSource.all()) {
              if (c.categoryData != null) {
                pages[c.categoryData!.key] = c.categoryData!.title;
              }
            }
            return _MultiPagesFilter(
              title: "Category Pages".tl,
              settingsIndex: "categories",
              pages: pages,
            );
          },
        ).toSliver(),
        _PopupWindowSetting(
          title: "Network Favorite Pages".tl,
          builder: () {
            var pages = <String, String>{};
            for (var c in ComicSource.all()) {
              if (c.favoriteData != null) {
                pages[c.favoriteData!.key] = c.favoriteData!.title;
              }
            }
            return _MultiPagesFilter(
              title: "Network Favorite Pages".tl,
              settingsIndex: "favorites",
              pages: pages,
            );
          },
        ).toSliver(),
        _SwitchSetting(
          title: "Show favorite status on comic tile".tl,
          settingKey: "showFavoriteStatusOnTile",
        ).toSliver(),
        _SwitchSetting(
          title: "Show history on comic tile".tl,
          settingKey: "showHistoryStatusOnTile",
        ).toSliver(),
        _PopupWindowSetting(
          title: "Keyword blocking".tl,
          builder: () => const _ManageBlockingWordView(),
        ).toSliver(),
      ],
    );
  }
}

class _ManageBlockingWordView extends StatefulWidget {
  const _ManageBlockingWordView();

  @override
  State<_ManageBlockingWordView> createState() =>
      _ManageBlockingWordViewState();
}

class _ManageBlockingWordViewState extends State<_ManageBlockingWordView> {
  @override
  Widget build(BuildContext context) {
    assert(appdata.settings["blockedWords"] is List);
    return PopUpWidgetScaffold(
      title: "Keyword blocking".tl,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: add,
        ),
      ],
      body: ListView.builder(
        itemCount: appdata.settings["blockedWords"].length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(appdata.settings["blockedWords"][index]),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                appdata.settings["blockedWords"].removeAt(index);
                appdata.saveData();
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  void add() {
    showDialog(
      context: App.rootContext,
      barrierColor: Colors.black.toOpacity(0.1),
      builder: (context) {
        var controller = TextEditingController();
        String? error;
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Add keyword".tl,
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: Text("Keyword".tl),
                errorText: error,
              ),
              onChanged: (s) {
                if(error != null){
                  setState(() {
                    error = null;
                  });
                }
              },
            ).paddingHorizontal(12),
            actions: [
              Button.filled(
                onPressed: () {
                  if(appdata.settings["blockedWords"].contains(controller.text)){
                    setState(() {
                      error = "Keyword already exists".tl;
                    });
                    return;
                  }
                  appdata.settings["blockedWords"].add(controller.text);
                  appdata.saveData();
                  this.setState(() {});
                  context.pop();
                },
                child: Text("Add".tl),
              ),
            ],
          );
        });
      },
    );
  }
}
