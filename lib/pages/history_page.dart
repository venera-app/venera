import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/translations.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    HistoryManager().addListener(onUpdate);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(onUpdate);
    super.dispose();
  }

  void onUpdate() {
    setState(() {
      comics = HistoryManager().getAll();
    });
  }

  var comics = HistoryManager().getAll();

  var controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            title: Text('History'.tl),
            actions: [
              Tooltip(
                message: 'Clear History'.tl,
                child: Flyout(
                  controller: controller,
                  flyoutBuilder: (context) {
                    return FlyoutContent(
                      title: 'Clear History'.tl,
                      content: Text(
                          'Are you sure you want to clear your history?'.tl),
                      actions: [
                        Button.filled(
                          color: context.colorScheme.error,
                          onPressed: () {
                            HistoryManager().clearHistory();
                            context.pop();
                          },
                          child: Text('Clear'.tl),
                        ),
                      ],
                    );
                  },
                  child: IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () {
                      controller.show();
                    },
                  ),
                ),
              )
            ],
          ),
          SliverGridComics(
            comics: comics.map(
              (e) {
                var cover = e.cover;
                if (!cover.isURL) {
                  var localComic = LocalManager().find(
                    e.id,
                    e.type,
                  );
                  if(localComic != null) {
                    cover = "file://${localComic.coverFile.path}";
                  }
                }
                return Comic(
                  e.title,
                  cover,
                  e.id,
                  e.subtitle,
                  null,
                  getDescription(e),
                  e.type.comicSource?.key ?? "Invalid:${e.type.value}",
                  null,
                  null,
                );
              },
            ).toList(),
            badgeBuilder: (c) {
              return ComicSource.find(c.sourceKey)?.name;
            },
            menuBuilder: (c) {
              return [
                MenuEntry(
                  icon: Icons.remove,
                  text: 'Remove'.tl,
                  onClick: () {
                    if (c.sourceKey.startsWith("Invalid")) {
                      HistoryManager().remove(
                        c.id,
                        ComicType(int.parse(c.sourceKey.split(':')[1])),
                      );
                    } else {
                      HistoryManager().remove(
                        c.id,
                        ComicType(c.sourceKey.hashCode),
                      );
                    }
                  },
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  String getDescription(History h) {
    var res = "";
    if (h.ep >= 1) {
      res += "@ep Chapter".tlParams({
        "ep": h.ep,
      });
    }
    if (h.page >= 1) {
      if (h.ep >= 1) {
        res += " - ";
      }
      res += "@page Page".tlParams({
        "page": h.page,
      });
    }
    return res;
  }
}
