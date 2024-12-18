part of 'reader.dart';

class ReaderWithLoading extends StatefulWidget {
  const ReaderWithLoading({
    super.key,
    required this.id,
    required this.sourceKey,
  });

  final String id;

  final String sourceKey;

  @override
  State<ReaderWithLoading> createState() => _ReaderWithLoadingState();
}

class _ReaderWithLoadingState
    extends LoadingState<ReaderWithLoading, ReaderProps> {
  @override
  Widget buildContent(BuildContext context, ReaderProps data) {
    return Reader(
      type: data.type,
      cid: data.cid,
      name: data.name,
      chapters: data.chapters,
      history: data.history,
    );
  }

  @override
  Future<Res<ReaderProps>> loadData() async {
    var comicSource = ComicSource.find(widget.sourceKey);
    var history = HistoryManager().findSync(
      widget.id,
      ComicType.fromKey(widget.sourceKey),
    );
    if (comicSource == null) {
      var localComic = LocalManager().find(
        widget.id,
        ComicType.fromKey(widget.sourceKey),
      );
      if (localComic == null) {
        return Res.error("comic not found");
      }
      return Res(
        ReaderProps(
          type: ComicType.fromKey(widget.sourceKey),
          cid: widget.id,
          name: localComic.title,
          chapters: localComic.chapters,
          history: history ??
              History.fromModel(
                model: localComic,
                ep: 0,
                page: 0,
              ),
        ),
      );
    } else {
      var comic = await comicSource.loadComicInfo!(widget.id);
      if (comic.error) {
        return Res.fromErrorRes(comic);
      }
      return Res(
        ReaderProps(
          type: ComicType.fromKey(widget.sourceKey),
          cid: widget.id,
          name: comic.data.title,
          chapters: comic.data.chapters,
          history: history ??
              History.fromModel(
                model: comic.data,
                ep: 0,
                page: 0,
              ),
        ),
      );
    }
  }
}

class ReaderProps {
  final ComicType type;

  final String cid;

  final String name;

  final Map<String, String>? chapters;

  final History history;

  const ReaderProps({
    required this.type,
    required this.cid,
    required this.name,
    required this.chapters,
    required this.history,
  });
}
