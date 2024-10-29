import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
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

  void update() {
    setState(() {
      comics = LocalManager().getComics();
    });
  }

  @override
  void initState() {
    comics = LocalManager().getComics();
    LocalManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            title: Text("Local".tl),
            actions: [
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
                      }
                      catch (e) {
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
