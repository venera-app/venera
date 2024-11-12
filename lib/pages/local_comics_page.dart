import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
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

  bool multiSelectMode = false;

  Map<Comic, bool> selectedComics = {};

  void update() {
    if (keyword.isEmpty) {
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
                  appdata.implicitData["local_sort"] =sortType.value;
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
          if (!searchMode && !multiSelectMode)
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
                ),
                Tooltip(
                  message: multiSelectMode
                      ? "Exit Multi-Select".tl
                      : "Multi-Select".tl,
                  child: IconButton(
                    icon: const Icon(Icons.checklist),
                    onPressed: () {
                      setState(() {
                        multiSelectMode = !multiSelectMode;
                      });
                    },
                  ),
                ),
              ],
            )
          else if (multiSelectMode)
            SliverAppbar(
              title: Text("Selected @c comics".tlParams({"c": selectedComics.length})),
              actions: [
                IconButton(
                  icon: const Icon(Icons.check_box_rounded),
                  tooltip: "Select All".tl,
                  onPressed: () {
                    setState(() {
                      selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outline_blank_outlined),
                  tooltip: "Deselect".tl,
                  onPressed: () {
                    setState(() {
                      selectedComics.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outlined),
                  tooltip: "Invert Selection".tl,
                  onPressed: () {
                    setState(() {
                      comics.asMap().forEach((k, v) {
                        selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
                      });
                      selectedComics.removeWhere((k, v) => !v);
                    });
                  },
                ),
                
                IconButton(
                  icon: const Icon(Icons.indeterminate_check_box_rounded),
                  tooltip: "Select in range".tl,
                  onPressed: () {
                    setState(() {
                      List<int> l = [];
                      selectedComics.forEach((k, v) {
                        l.add(comics.indexOf(k as LocalComic));
                      });
                      if(l.isEmpty) {
                        return;
                      }
                      l.sort();
                      int start = l.first;
                      int end = l.last;
                      selectedComics.clear();
                      selectedComics.addEntries(
                        List.generate(end - start + 1, (i) {
                          return MapEntry(comics[start + i], true);
                        })
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Exit Multi-Select".tl,
                  onPressed: () {
                    setState(() {
                      multiSelectMode = false;
                      selectedComics.clear();
                    });
                  },
                ),
                
              ],
            )
          else if (searchMode)
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
            selections: selectedComics,
            onTap: multiSelectMode
                ? (c) {
                    setState(() {
                      if (selectedComics.containsKey(c as LocalComic)) {
                        selectedComics.remove(c);
                      } else {
                        selectedComics[c] = true;
                      }
                    });
                  }
                : (c) {
                    (c as LocalComic).read();
                  },
            menuBuilder: (c) {
              return [
                MenuEntry(
                    icon: Icons.delete,
                    text: "Delete".tl,
                    onClick: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          bool removeComicFile = true;
                          return StatefulBuilder(
                            builder: (context, state) {
                              return ContentDialog(
                                title: "Delete".tl,
                                content: Column(
                                  children: [
                                    Text("Delete selected comics?".tl).paddingVertical(8),
                                    Transform.scale(
                                      scale: 0.9, 
                                      child: CheckboxListTile(
                                        title: Text("Also remove files on disk".tl),
                                        value: removeComicFile,
                                        onChanged: (v) { 
                                          state(() {
                                            removeComicFile = !removeComicFile; 
                                          });
                                        }
                                      )
                                    ),
                                  ],
                                ).paddingHorizontal(16).paddingVertical(8),
                                actions: [
                                  FilledButton(
                                    onPressed: () {
                                      context.pop();
                                      if(multiSelectMode) {
                                        for (var comic in selectedComics.keys) {
                                          LocalManager().deleteComic(comic as LocalComic, removeComicFile);
                                        }
                                        setState(() {
                                          selectedComics.clear();
                                        });
                                      } else {
                                        LocalManager().deleteComic(c as LocalComic, removeComicFile);
                                      }
                                    },
                                    child: Text("Confirm".tl),
                                  ),
                                ],
                              );
                            }
                          );
                        }
                      );
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
                        if (multiSelectMode) {
                          for (var comic in selectedComics.keys) {
                            var file = await CBZ.export(comic as LocalComic);
                            await saveFile(filename: file.name, file: file);
                            await file.delete();
                          }
                          setState(() {
                            selectedComics.clear();
                          });
                        } else {
                          var file = await CBZ.export(c as LocalComic);
                          await saveFile(filename: file.name, file: file);
                          await file.delete();
                        }
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
