import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/translations.dart';

class ComicSourcePage extends StatefulWidget {
  const ComicSourcePage({super.key});

  static void checkComicSourceUpdate([bool showLoading = false]) async {
    if (ComicSource.all().isEmpty) {
      return;
    }
    var controller = showLoading ? showLoadingDialog(App.rootContext) : null;
    var dio = AppDio();
    var res = await dio.get<String>(
        "https://raw.githubusercontent.com/venera-app/venera-configs/master/index.json");
    if (res.statusCode != 200) {
      App.rootContext.showMessage(message: "Network error".tl);
      return;
    }
    var list = jsonDecode(res.data!) as List;
    var versions = <String, String>{};
    for (var source in list) {
      versions[source['key']] = source['version'];
    }
    var shouldUpdate = <String>[];
    for (var source in ComicSource.all()) {
      if (versions.containsKey(source.key) &&
          versions[source.key] != source.version) {
        shouldUpdate.add(source.key);
      }
    }
    controller?.close();
    if (shouldUpdate.isEmpty) {
      return;
    }
    var msg = "";
    for (var key in shouldUpdate) {
      msg += "${ComicSource.find(key)?.name}: v${versions[key]}\n";
    }
    msg = msg.trim();
    showConfirmDialog(App.rootContext, "Updates Available".tl, msg, () {
      for (var key in shouldUpdate) {
        var source = ComicSource.find(key);
        _BodyState.update(source!);
      }
    });
  }

  @override
  State<ComicSourcePage> createState() => _ComicSourcePageState();
}

class _ComicSourcePageState extends State<ComicSourcePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text('Comic Source'.tl),
      ),
      body: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  var url = "";

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        buildCard(context),
        buildSettings(),
        for (var source in ComicSource.all()) buildSource(context, source),
        SliverPadding(padding: EdgeInsets.only(bottom: context.padding.bottom)),
      ],
    );
  }

  Widget buildSettings() {
    return SliverToBoxAdapter(
      child: ListTile(
        leading: const Icon(Icons.update_outlined),
        title: Text("Check updates".tl),
        onTap: () => ComicSourcePage.checkComicSourceUpdate(true),
        trailing: const Icon(Icons.arrow_right),
      ),
    );
  }

  Widget buildSource(BuildContext context, ComicSource source) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Divider(),
          ListTile(
            title: Text(source.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (App.isDesktop)
                  Tooltip(
                    message: "Edit".tl,
                    child: IconButton(
                        onPressed: () => edit(source),
                        icon: const Icon(Icons.edit_note)),
                  ),
                Tooltip(
                  message: "Update".tl,
                  child: IconButton(
                      onPressed: () => update(source),
                      icon: const Icon(Icons.update)),
                ),
                Tooltip(
                  message: "Delete".tl,
                  child: IconButton(
                      onPressed: () => delete(source),
                      icon: const Icon(Icons.delete)),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text("Version"),
            subtitle: Text(source.version),
          )
        ],
      ),
    );
  }

  void delete(ComicSource source) {
    showConfirmDialog(
      App.rootContext,
      "Delete".tl,
      "Are you sure you want to delete it?".tl,
      () {
        var file = File(source.filePath);
        file.delete();
        ComicSource.remove(source.key);
        _validatePages();
        App.forceRebuild();
      },
    );
  }

  void edit(ComicSource source) async {
    try {
      await Process.run("code", [source.filePath], runInShell: true);
      await showDialog(
          context: App.rootContext,
          builder: (context) => AlertDialog(
                title: const Text("Reload Configs"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("cancel")),
                  TextButton(
                      onPressed: () async {
                        await ComicSource.reload();
                        App.forceRebuild();
                      },
                      child: const Text("continue")),
                ],
              ));
    } catch (e) {
      context.showMessage(message: "Failed to launch vscode");
    }
  }

  static void update(ComicSource source) async {
    if (!source.url.isURL) {
      App.rootContext.showMessage(message: "Invalid url config");
      return;
    }
    ComicSource.remove(source.key);
    bool cancel = false;
    var controller = showLoadingDialog(
      App.rootContext,
      onCancel: () => cancel = true,
      barrierDismissible: false,
    );
    try {
      var res = await AppDio().get<String>(source.url,
          options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await ComicSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
    } catch (e) {
      if (cancel) return;
      App.rootContext.showMessage(message: e.toString());
    }
    await ComicSource.reload();
    App.forceRebuild();
  }

  Widget buildCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Card.outlined(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("Add comic source".tl),
                leading: const Icon(Icons.dashboard_customize),
              ),
              TextField(
                      decoration: InputDecoration(
                          hintText: "URL",
                          border: const UnderlineInputBorder(),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          suffix: IconButton(
                              onPressed: () => handleAddSource(url),
                              icon: const Icon(Icons.check))),
                      onChanged: (value) {
                        url = value;
                      },
                      onSubmitted: handleAddSource)
                  .paddingHorizontal(16)
                  .paddingBottom(32),
              Row(
                children: [
                  TextButton(onPressed: selectFile, child: Text("Select file".tl))
                      .paddingLeft(8),
                  const Spacer(),
                  TextButton(
                      onPressed: () {
                        showPopUpWidget(
                            App.rootContext, _ComicSourceList(handleAddSource));
                      },
                      child: Text("View list".tl)),
                  const Spacer(),
                  TextButton(onPressed: help, child: Text("Open help".tl))
                      .paddingRight(8),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ).paddingHorizontal(12),
    );
  }

  void selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['js'],
    );
    final file = result?.files.first;
    if (file == null) return;
    try {
      var fileName = file.name;
      var bytes = file.bytes!;
      var content = utf8.decode(bytes);
      await addSource(content, fileName);
    } catch (e) {
      App.rootContext.showMessage(message: e.toString());
    }
  }

  void help() {
    launchUrlString(
        "https://github.com/venera-app/venera/blob/master/doc/comic_source.md");
  }

  Future<void> handleAddSource(String url) async {
    if (url.isEmpty) {
      return;
    }
    var splits = url.split("/");
    splits.removeWhere((element) => element == "");
    var fileName = splits.last;
    bool cancel = false;
    var controller = showLoadingDialog(App.rootContext,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await AppDio()
          .get<String>(url, options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await addSource(res.data!, fileName);
    } catch (e, s) {
      if (cancel) return;
      context.showMessage(message: e.toString());
      Log.error("Add comic source", "$e\n$s");
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var comicSource = await ComicSourceParser().createAndParse(js, fileName);
    ComicSource.add(comicSource);
    _addAllPagesWithComicSource(comicSource);
    appdata.saveData();
    App.forceRebuild();
  }
}

class _ComicSourceList extends StatefulWidget {
  const _ComicSourceList(this.onAdd);

  final Future<void> Function(String) onAdd;

  @override
  State<_ComicSourceList> createState() => _ComicSourceListState();
}

class _ComicSourceListState extends State<_ComicSourceList> {
  bool loading = true;
  List? json;

  void load() async {
    var dio = AppDio();
    var res = await dio.get<String>(
        "https://raw.githubusercontent.com/venera-app/venera-configs/master/index.json");
    if (res.statusCode != 200) {
      context.showMessage(message: "Network error".tl);
      return;
    }
    setState(() {
      json = jsonDecode(res.data!);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Comic Source".tl,
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (loading) {
      load();
      return const Center(child: CircularProgressIndicator());
    } else {
      var currentKey = ComicSource.all().map((e) => e.key).toList();
      return ListView.builder(
        itemCount: json!.length,
        itemBuilder: (context, index) {
          var key = json![index]["key"];
          var action = currentKey.contains(key)
              ? const Icon(Icons.check)
              : Tooltip(
                  message: "Add",
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      await widget.onAdd(
                          "https://raw.githubusercontent.com/venera-app/venera-configs/master/${json![index]["fileName"]}");
                      setState(() {});
                    },
                  ),
                );

          return ListTile(
            title: Text(json![index]["name"]),
            subtitle: Text(json![index]["version"]),
            trailing: action,
          );
        },
      );
    }
  }
}

void _validatePages() {
  List explorePages = appdata.settings['explore_pages'];
  List categoryPages = appdata.settings['categories'];
  List networkFavorites = appdata.settings['favorites'];

  var totalExplorePages = ComicSource.all()
      .map((e) => e.explorePages.map((e) => e.title))
      .expand((element) => element)
      .toList();
  var totalCategoryPages = ComicSource.all()
      .map((e) => e.categoryData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
  var totalNetworkFavorites = ComicSource.all()
      .map((e) => e.favoriteData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();

  for (var page in List.from(explorePages)) {
    if (!totalExplorePages.contains(page)) {
      explorePages.remove(page);
    }
  }
  for (var page in List.from(categoryPages)) {
    if (!totalCategoryPages.contains(page)) {
      categoryPages.remove(page);
    }
  }
  for (var page in List.from(networkFavorites)) {
    if (!totalNetworkFavorites.contains(page)) {
      networkFavorites.remove(page);
    }
  }

  appdata.settings['explore_pages'] = explorePages.toSet().toList();
  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();

  appdata.saveData();
}

void _addAllPagesWithComicSource(ComicSource source) {
  var explorePages = appdata.settings['explore_pages'];
  var categoryPages = appdata.settings['categories'];
  var networkFavorites = appdata.settings['favorites'];

  if (source.explorePages.isNotEmpty) {
    for (var page in source.explorePages) {
      if (!explorePages.contains(page.title)) {
        explorePages.add(page.title);
      }
    }
  }
  if (source.categoryData != null &&
      !categoryPages.contains(source.categoryData!.key)) {
    categoryPages.add(source.categoryData!.key);
  }
  if (source.favoriteData != null &&
      !networkFavorites.contains(source.favoriteData!.key)) {
    networkFavorites.add(source.favoriteData!.key);
  }

  appdata.settings['explore_pages'] = explorePages.toSet().toList();
  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();

  appdata.saveData();
}
