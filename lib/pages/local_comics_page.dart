import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';

class LocalComicsPage extends StatefulWidget {
  const LocalComicsPage({super.key});

  @override
  State<LocalComicsPage> createState() => _LocalComicsPageState();
}

class _LocalComicsPageState extends State<LocalComicsPage> {
  late List<LocalComic> comics;

  late LocalSortType sortType;

  String keyword = "";

  bool searchMode = false;

  void update() {
    if(keyword.isEmpty) {
      setState(() {
        comics = LocalManager().getComics(sortType);
      });
    } else {
      setState(() {
        comics = LocalManager().search(keyword);
      });
    }
  }

  @override
  void initState() {
    var sort = appdata.implicitData["local_sort"] ?? "name";
    sortType = LocalSortType.fromString(sort);
    comics = LocalManager().getComics(sortType);
    LocalManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(update);
    super.dispose();
  }

  void sort() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Sort".tl,
            content: Column(
              children: [
                RadioListTile<LocalSortType>(
                  title: Text("Name".tl),
                  value: LocalSortType.name,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date".tl),
                  value: LocalSortType.timeAsc,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date Desc".tl),
                  value: LocalSortType.timeDesc,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  appdata.implicitData["local_sort"] =
                      sortType.value;
                  appdata.writeImplicitData();
                  Navigator.pop(context);
                  update();
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          if(!searchMode)
            SliverAppbar(
              title: Text("Local".tl),
              actions: [
                Tooltip(
                  message: "Search".tl,
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        searchMode = true;
                      });
                    },
                  ),
                ),
                Tooltip(
                  message: "Sort".tl,
                  child: IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: sort,
                  ),
                ),
                Tooltip(
                  message: "Downloading".tl,
                  child: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      showPopUpWidget(context, const DownloadingPage());
                    },
                  ),
                )
              ],
            )
          else
            SliverAppbar(
              title: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search".tl,
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  keyword = v;
                  update();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      searchMode = false;
                      keyword = "";
                      update();
                    });
                  },
                ),
              ],
            ),
          SliverGridComics(
            comics: comics,
            onTap: (c) {
              (c as LocalComic).read();
            },
            menuBuilder: (c) {
              return [
                MenuEntry(
                    icon: Icons.delete,
                    text: "Delete".tl,
                    onClick: () {
                      LocalManager().deleteComic(c as LocalComic);
                    }),
                MenuEntry(
                    icon: Icons.outbox_outlined,
                    text: "Export as cbz".tl,
                    onClick: () async {
                      var controller = showLoadingDialog(
                        context,
                        allowCancel: false,
                      );
                      try {
                        var file = await CBZ.export(c as LocalComic);
                        await saveFile(filename: file.name, file: file);
                        await file.delete();
                      } catch (e) {
                        context.showMessage(message: e.toString());
                      }
                      controller.close();
                    }),
              ];
            },
          ),
        ],
      ),
    );
  }
}
