part of 'reader.dart';

class _ChaptersView extends StatefulWidget {
  const _ChaptersView(this.reader);

  final _ReaderState reader;

  @override
  State<_ChaptersView> createState() => _ChaptersViewState();
}

class _ChaptersViewState extends State<_ChaptersView> {
  bool desc = false;

  late final ScrollController _scrollController;

  var downloaded = <String>[];

  @override
  void initState() {
    super.initState();
    int epIndex = widget.reader.chapter - 2;
    _scrollController = ScrollController(
      initialScrollOffset: (epIndex * 48.0 + 52).clamp(0, double.infinity),
    );
    var local = LocalManager().find(widget.reader.cid, widget.reader.type);
    if (local != null) {
      downloaded = local.downloadedChapters;
    }
  }

  @override
  Widget build(BuildContext context) {
    var chapters = widget.reader.widget.chapters!;
    var current = widget.reader.chapter - 1;
    return Scaffold(
      body: SmoothCustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppbar(
            style: AppbarStyle.shadow,
            title: Text("Chapters".tl),
            actions: [
              Tooltip(
                message: "Click to change the order".tl,
                child: TextButton.icon(
                  icon: Icon(
                    !desc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                  ),
                  label: Text(!desc ? "Ascending".tl : "Descending".tl),
                  onPressed: () {
                    setState(() {
                      desc = !desc;
                    });
                  },
                ),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (desc) {
                  index = chapters.length - 1 - index;
                }
                var chapter = chapters.titles.elementAt(index);
                return _ChapterListTile(
                  onTap: () {
                    widget.reader.toChapter(index + 1);
                    Navigator.of(context).pop();
                  },
                  title: chapter,
                  isActive: current == index,
                  isDownloaded:
                      downloaded.contains(chapters.ids.elementAt(index)),
                );
              },
              childCount: chapters.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedChaptersView extends StatefulWidget {
  const _GroupedChaptersView(this.reader);

  final _ReaderState reader;

  @override
  State<_GroupedChaptersView> createState() => _GroupedChaptersViewState();
}

class _GroupedChaptersViewState extends State<_GroupedChaptersView>
    with SingleTickerProviderStateMixin {
  ComicChapters get chapters => widget.reader.widget.chapters!;

  late final TabController tabController;

  late final ScrollController _scrollController;

  late final String initialGroupName;

  var downloaded = <String>[];

  bool _enableTabViewSwitchAnimationSetting = true;

  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _enableTabViewSwitchAnimationSetting =
        appdata.settings["enableTabViewSwitchAnimation"] != false;
    int index = 0;
    int epIndex = widget.reader.chapter - 1;
    while (epIndex >= 0) {
      epIndex -= chapters.getGroupByIndex(index).length;
      index++;
    }
    tabController = TabController(
      length: chapters.groups.length,
      vsync: this,
      initialIndex: index - 1,
    );
    initialGroupName = chapters.groups.elementAt(index - 1);
    var epIndexAtGroup = widget.reader.chapter - 1;
    for (var i = 0; i < index - 1; i++) {
      epIndexAtGroup -= chapters.getGroupByIndex(i).length;
    }
    _scrollController = ScrollController(
      initialScrollOffset: (epIndexAtGroup * 48.0).clamp(0, double.infinity),
    );
    var local = LocalManager().find(widget.reader.cid, widget.reader.type);
    if (local != null) {
      downloaded = local.downloadedChapters;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enablePageSwitchAnimation = _enableTabViewSwitchAnimationSetting &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    return Column(
      children: [
        Appbar(title: Text("Chapters".tl)),
        AppTabBar(
          controller: tabController,
          enableSwitchAnimation: enablePageSwitchAnimation,
          tabs: chapters.groups.map((e) => Tab(text: e)).toList(),
        ),
        Expanded(
          child: enablePageSwitchAnimation
              ? TabBarView(
                  controller: tabController,
                  children: chapters.groups.map(buildGroup).toList(),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    void switchByDragEnd(double velocity) {
                      if (chapters.groups.length <= 1) {
                        return;
                      }
                      final double distanceThreshold =
                          (constraints.maxWidth * 0.15).clamp(48.0, 140.0);
                      const double velocityThreshold = 900.0;
                      final bool shouldTurnByVelocity =
                          velocity.abs() >= velocityThreshold;
                      final bool shouldTurnByDistance =
                          _horizontalDragDistance.abs() >= distanceThreshold;
                      if (!shouldTurnByVelocity && !shouldTurnByDistance) {
                        return;
                      }
                      final bool goNext = shouldTurnByVelocity
                          ? (velocity < 0)
                          : (_horizontalDragDistance < 0);
                      final int newIndex =
                          (goNext ? tabController.index + 1 : tabController.index - 1)
                              .clamp(0, chapters.groups.length - 1);
                      if (newIndex != tabController.index) {
                        tabController.index = newIndex;
                      }
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        _horizontalDragDistance = 0;
                      },
                      onHorizontalDragUpdate: (details) {
                        _horizontalDragDistance += details.delta.dx;
                      },
                      onHorizontalDragEnd: (details) {
                        switchByDragEnd(details.velocity.pixelsPerSecond.dx);
                      },
                      child: TabViewBody(
                        controller: tabController,
                        children: chapters.groups.map(buildGroup).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildGroup(String groupName) {
    var group = chapters.getGroup(groupName);
    return SmoothCustomScrollView(
      controller: initialGroupName == groupName ? _scrollController : null,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              var name = group.values.elementAt(index);
              var i = 0;
              for (var g in chapters.groups) {
                if (g == groupName) {
                  break;
                }
                i += chapters.getGroup(g).length;
              }
              i += index + 1;
              return _ChapterListTile(
                onTap: () {
                  widget.reader.toChapter(i);
                  context.pop();
                },
                title: name,
                isActive: widget.reader.chapter == i,
                isDownloaded: downloaded.contains(group.keys.elementAt(index)),
              );
            },
            childCount: group.length,
          ),
        ),
      ],
    );
  }
}

class _ChapterListTile extends StatelessWidget {
  const _ChapterListTile({
    required this.title,
    required this.isActive,
    required this.isDownloaded,
    required this.onTap,
  });

  final String title;

  final bool isActive;

  final bool isDownloaded;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color:
                  isActive ? context.colorScheme.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: isActive
                  ? ts.withColor(context.colorScheme.primary).bold.s16
                  : ts.s16,
            ),
            const Spacer(),
            if (isDownloaded)
              Icon(
                Icons.download_done_rounded,
                color: context.colorScheme.secondary,
              ),
          ],
        ),
      ),
    );
  }
}
