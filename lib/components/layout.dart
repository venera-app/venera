part of 'components.dart';

class SliverGridViewWithFixedItemHeight extends StatelessWidget {
  const SliverGridViewWithFixedItemHeight(
      {required this.delegate,
      required this.maxCrossAxisExtent,
      required this.itemHeight,
      super.key});

  final SliverChildDelegate delegate;

  final double maxCrossAxisExtent;

  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        delegate: delegate,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          childAspectRatio: calcChildAspectRatio(constraints.crossAxisExtent),
        ),
      ),
    );
  }

  double calcChildAspectRatio(double width) {
    var crossItems = width ~/ maxCrossAxisExtent;
    if (width % maxCrossAxisExtent != 0) {
      crossItems += 1;
    }
    final itemWidth = width / crossItems;
    return itemWidth / itemHeight;
  }
}

class SliverGridDelegateWithFixedHeight extends SliverGridDelegate {
  const SliverGridDelegateWithFixedHeight({
    required this.maxCrossAxisExtent,
    required this.itemHeight,
  });

  final double maxCrossAxisExtent;

  final double itemHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    var crossItems = width ~/ maxCrossAxisExtent;
    if (width % maxCrossAxisExtent != 0) {
      crossItems += 1;
    }
    return SliverGridRegularTileLayout(
        crossAxisCount: crossItems,
        mainAxisStride: itemHeight,
        crossAxisStride: width / crossItems,
        childMainAxisExtent: itemHeight,
        childCrossAxisExtent: width / crossItems,
        reverseCrossAxis: false);
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithFixedHeight) return true;
    if (oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.itemHeight != itemHeight) {
      return true;
    }
    return false;
  }
}

class SliverGridDelegateWithComics extends SliverGridDelegate {
  SliverGridDelegateWithComics();

  final bool useBriefMode = appdata.settings['comicDisplayMode'] == 'brief';

  final double scale = (appdata.settings['comicTileScale'] as num).toDouble();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (useBriefMode) {
      return getBriefModeLayout(
        constraints,
        scale,
      );
    } else {
      return getDetailedModeLayout(
        constraints,
        scale,
      );
    }
  }

  SliverGridLayout getDetailedModeLayout(
      SliverConstraints constraints, double scale) {
    const minCrossAxisExtent = 360;
    final itemHeight = 152 * scale;
    final width = constraints.crossAxisExtent;
    var crossItems = width ~/ minCrossAxisExtent;
    crossItems = math.max(1, crossItems);
    return SliverGridRegularTileLayout(
        crossAxisCount: crossItems,
        mainAxisStride: itemHeight,
        crossAxisStride: width / crossItems,
        childMainAxisExtent: itemHeight,
        childCrossAxisExtent: width / crossItems,
        reverseCrossAxis: false);
  }

  SliverGridLayout getBriefModeLayout(
      SliverConstraints constraints, double scale) {
    final maxCrossAxisExtent = 192.0 * scale;
    const childAspectRatio = 0.64;
    const crossAxisSpacing = 0.0;
    int crossAxisCount =
        (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = math.max(1, crossAxisCount);
    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithComics) return true;
    if (oldDelegate.scale != scale ||
        oldDelegate.useBriefMode != useBriefMode) {
      return true;
    }
    return false;
  }
}

class SliverLazyToBoxAdapter extends StatelessWidget {
  /// Creates a sliver that contains a single box widget which can be lazy loaded.
  const SliverLazyToBoxAdapter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(children: [
      SizedBox(),
      child,
    ]);
  }
}

class SliverAnimatedVisibility extends StatelessWidget {
  const SliverAnimatedVisibility({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var child = visible ? this.child : const SizedBox.shrink();

    return SliverToBoxAdapter(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}
