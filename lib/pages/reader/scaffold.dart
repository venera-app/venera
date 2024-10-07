part of 'reader.dart';

class _ReaderScaffold extends StatefulWidget {
  const _ReaderScaffold({required this.child});

  final Widget child;

  @override
  State<_ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends State<_ReaderScaffold> {
  bool _isOpen = false;

  static const kTopBarHeight = 56.0;

  static const kBottomBarHeight = 105.0;

  bool get isOpen => _isOpen;

  void openOrClose() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  bool? rotation;

  void update() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.child,
        ),
        buildPageInfoText(),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          top: _isOpen ? 0 : -(kTopBarHeight + context.padding.top),
          left: 0,
          right: 0,
          height: kTopBarHeight + context.padding.top,
          child: buildTop(),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          bottom: _isOpen ? 0 : -(kBottomBarHeight + context.padding.bottom),
          left: 0,
          right: 0,
          height: kBottomBarHeight + context.padding.bottom,
          child: buildBottom(),
        ),
      ],
    );
  }

  Widget buildTop() {
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.reader.widget.name, style: ts.s18),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottom() {
    var text = "E${context.reader.chapter} : P${context.reader.page}";
    if (context.reader.widget.chapters == null) {
      text = "P${context.reader.page}";
    }

    Widget child = SizedBox(
      height: kBottomBarHeight + MediaQuery.of(context).padding.bottom,
      child: Column(
        children: [
          const SizedBox(
            height: 8,
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: context.reader.toPrevChapter,
                icon: const Icon(Icons.first_page),
              ),
              Expanded(
                child: buildSlider(),
              ),
              IconButton.filledTonal(
                  onPressed: context.reader.toNextChapter,
                  icon: const Icon(Icons.last_page)),
              const SizedBox(
                width: 8,
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 16,
              ),
              Container(
                height: 24,
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(text),
              ),
              const Spacer(),
              if (App.isWindows)
                Tooltip(
                  message: "${"Full Screen".tl}(F12)",
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      context.reader.fullscreen();
                    },
                  ),
                ),
              if (App.isAndroid)
                Tooltip(
                  message: "Screen Rotation".tl,
                  child: IconButton(
                    icon: () {
                      if (rotation == null) {
                        return const Icon(Icons.screen_rotation);
                      } else if (rotation == false) {
                        return const Icon(Icons.screen_lock_portrait);
                      } else {
                        return const Icon(Icons.screen_lock_landscape);
                      }
                    }.call(),
                    onPressed: () {
                      if (rotation == null) {
                        setState(() {
                          rotation = false;
                        });
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                      } else if (rotation == false) {
                        setState(() {
                          rotation = true;
                        });
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight
                        ]);
                      } else {
                        setState(() {
                          rotation = null;
                        });
                        SystemChrome.setPreferredOrientations(
                            DeviceOrientation.values);
                      }
                    },
                  ),
                ),
              Tooltip(
                message: "Auto Page Turning".tl,
                child: IconButton(
                  icon: context.reader.autoPageTurningTimer != null
                      ? const Icon(Icons.timer)
                      : const Icon(Icons.timer_sharp),
                  onPressed: context.reader.autoPageTurning,
                ),
              ),
              if (context.reader.widget.chapters != null)
                Tooltip(
                  message: "Chapters".tl,
                  child: IconButton(
                    icon: const Icon(Icons.library_books),
                    onPressed: openChapterDrawer,
                  ),
                ),
              Tooltip(
                message: "Save Image".tl,
                child: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: saveCurrentImage,
                ),
              ),
              Tooltip(
                message: "Share".tl,
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: share,
                ),
              ),
              const SizedBox(width: 4)
            ],
          )
        ],
      ),
    );

    return BlurEffect(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        padding: EdgeInsets.only(bottom: context.padding.bottom),
        child: child,
      ),
    );
  }

  Widget buildSlider() {
    return Slider(
      value: context.reader.page.toDouble(),
      min: 1,
      max: context.reader.maxPage.clamp(context.reader.page, 1 << 16).toDouble(),
      divisions: (context.reader.maxPage - 1).clamp(2, 1 << 16),
      onChanged: (i) {
        context.reader.toPage(i.toInt());
      },
    );
  }

  Widget buildPageInfoText() {
    var epName = context.reader.widget.chapters?.values
            .elementAt(context.reader.chapter - 1) ??
        "E${context.reader.chapter}";
    if (epName.length > 8) {
      epName = "${epName.substring(0, 8)}...";
    }
    var pageText = "${context.reader.page}/${context.reader.maxPage}";
    var text = context.reader.widget.chapters != null
        ? "$epName : $pageText"
        : pageText;

    return Positioned(
      bottom: 13,
      left: 25,
      child: Stack(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = context.colorScheme.onInverseSurface,
            ),
          ),
          Text(text),
        ],
      ),
    );
  }

  void openChapterDrawer() {
    // TODO
  }

  void saveCurrentImage() {
    // TODO
  }

  void share() {
    // TODO
  }

  void openSetting() {
    // TODO
  }
}
