import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/epub.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/pdf.dart';
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
                  appdata.implicitData["local_sort"] = sortType.value;
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
    void selectAll() {
      setState(() {
        selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
      });
    }

    void deSelect() {
      setState(() {
        selectedComics.clear();
      });
    }

    void invertSelection() {
      setState(() {
        comics.asMap().forEach((k, v) {
          selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
        });
        selectedComics.removeWhere((k, v) => !v);
      });
    }

    void selectRange() {
      setState(() {
        List<int> l = [];
        selectedComics.forEach((k, v) {
          l.add(comics.indexOf(k as LocalComic));
        });
        if (l.isEmpty) {
          return;
        }
        l.sort();
        int start = l.first;
        int end = l.last;
        selectedComics.clear();
        selectedComics.addEntries(List.generate(end - start + 1, (i) {
          return MapEntry(comics[start + i], true);
        }));
      });
    }

    List<Widget> selectActions = [
      IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: "Select All".tl,
          onPressed: selectAll),
      IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: "Deselect".tl,
          onPressed: deSelect),
      IconButton(
          icon: const Icon(Icons.flip),
          tooltip: "Invert Selection".tl,
          onPressed: invertSelection),
      IconButton(
          icon: const Icon(Icons.border_horizontal_outlined),
          tooltip: "Select in range".tl,
          onPressed: selectRange),
    ];

    var body = Scaffold(
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
              leading: Tooltip(
                message: "Cancel".tl,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      multiSelectMode = false;
                      selectedComics.clear();
                    });
                  },
                ),
              ),
              title: Text(
                  "Selected @c comics".tlParams({"c": selectedComics.length})),
              actions: selectActions,
            )
          else if (searchMode)
            SliverAppbar(
              leading: Tooltip(
                message: "Cancel".tl,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      searchMode = false;
                      keyword = "";
                      update();
                    });
                  },
                ),
              ),
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
                            return StatefulBuilder(builder: (context, state) {
                              return ContentDialog(
                                title: "Delete".tl,
                                content: CheckboxListTile(
                                  title: Text("Also remove files on disk".tl),
                                  value: removeComicFile,
                                  onChanged: (v) {
                                    state(() {
                                      removeComicFile = !removeComicFile;
                                    });
                                  },
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () {
                                      context.pop();
                                      if (multiSelectMode) {
                                        for (var comic in selectedComics.keys) {
                                          LocalManager().deleteComic(
                                              comic as LocalComic,
                                              removeComicFile);
                                        }
                                        setState(() {
                                          selectedComics.clear();
                                        });
                                      } else {
                                        LocalManager().deleteComic(
                                            c as LocalComic, removeComicFile);
                                      }
                                    },
                                    child: Text("Confirm".tl),
                                  ),
                                ],
                              );
                            });
                          });
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
                if (!multiSelectMode)
                  MenuEntry(
                    icon: Icons.picture_as_pdf_outlined,
                    text: "Export as pdf".tl,
                    onClick: () async {
                      var cache = FilePath.join(App.cachePath, 'temp.pdf');
                      var controller = showLoadingDialog(
                        context,
                        allowCancel: false,
                      );
                      try {
                        await createPdfFromComicIsolate(
                          comic: c as LocalComic,
                          savePath: cache,
                        );
                        await saveFile(
                          file: File(cache),
                          filename: "${c.title}.pdf",
                        );
                      } catch (e, s) {
                        Log.error("PDF Export", e, s);
                        context.showMessage(message: e.toString());
                      } finally {
                        controller.close();
                        File(cache).deleteIgnoreError();
                      }
                    },
                  ),
                if (!multiSelectMode)
                  MenuEntry(
                    icon: Icons.import_contacts_outlined,
                    text: "Export as epub".tl,
                    onClick: () async {
                      var controller = showLoadingDialog(
                        context,
                        allowCancel: false,
                      );
                      File? file;
                      try {
                        file = await createEpubWithLocalComic(
                          c as LocalComic,
                        );
                        await saveFile(
                          file: file,
                          filename: "${c.title}.epub",
                        );
                      } catch (e, s) {
                        Log.error("EPUB Export", e, s);
                        context.showMessage(message: e.toString());
                      } finally {
                        controller.close();
                        file?.deleteIgnoreError();
                      }
                    },
                  )
              ];
            },
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            update();
          });
        }
      },
      child: body,
    );
  }
}
