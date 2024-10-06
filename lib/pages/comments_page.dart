import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/utils/translations.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage(
      {super.key, required this.data, required this.source, this.replyId});

  final ComicDetails data;

  final ComicSource source;

  final String? replyId;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  bool _loading = true;
  List<Comment>? _comments;
  String? _error;
  int _page = 1;
  int? maxPage;
  var controller = TextEditingController();
  bool sending = false;

  void firstLoad() async {
    var res = await widget.source.commentsLoader!(
        widget.data.comicId, widget.data.subId, 1, widget.replyId);
    if (res.error) {
      setState(() {
        _error = res.errorMessage;
        _loading = false;
      });
    } else {
      setState(() {
        _comments = res.data;
        _loading = false;
        maxPage = res.subData;
      });
    }
  }

  void loadMore() async {
    var res = await widget.source.commentsLoader!(
        widget.data.comicId, widget.data.subId, _page + 1, widget.replyId);
    if (res.error) {
      context.showMessage(message: res.errorMessage ?? "Unknown Error");
    } else {
      setState(() {
        _comments!.addAll(res.data);
        _page++;
        if (maxPage == null && res.data.isEmpty) {
          maxPage = _page;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Comments".tl),
      ),
      body: buildBody(context),
    );
  }

  Widget buildBody(BuildContext context) {
    if (_loading) {
      firstLoad();
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_error != null) {
      return NetworkError(
        message: _error!,
        retry: () {
          setState(() {
            _loading = true;
          });
        },
        withAppbar: false,
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: _comments!.length + 1,
              itemBuilder: (context, index) {
                if (index == _comments!.length) {
                  if (_page < (maxPage ?? _page + 1)) {
                    loadMore();
                    return const ListLoadingIndicator();
                  } else {
                    return const SizedBox();
                  }
                }

                return _CommentTile(
                  comment: _comments![index],
                  source: widget.source,
                  comic: widget.data,
                );
              },
            ),
          ),
          buildBottom(context)
        ],
      );
    }
  }

  Widget buildBottom(BuildContext context) {
    if (widget.source.sendCommentFunc == null) {
      return const SizedBox(
        height: 0,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Material(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: "Comment".tl),
                minLines: 1,
                maxLines: 5,
              ),
            ),
            if (sending)
              const Padding(
                padding: EdgeInsets.all(8.5),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: () async {
                  if (controller.text.isEmpty) {
                    return;
                  }
                  setState(() {
                    sending = true;
                  });
                  var b = await widget.source.sendCommentFunc!(
                      widget.data.comicId,
                      widget.data.subId,
                      controller.text,
                      widget.replyId);
                  if (!b.error) {
                    controller.text = "";
                    setState(() {
                      sending = false;
                      _loading = true;
                      _comments?.clear();
                      _page = 1;
                      maxPage = null;
                    });
                  } else {
                    context.showMessage(message: b.errorMessage ?? "Error");
                    setState(() {
                      sending = false;
                    });
                  }
                },
                icon: Icon(
                  Icons.send,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              )
          ],
        ).paddingVertical(2).paddingLeft(16).paddingRight(4),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.source,
    required this.comic,
  });

  final Comment comment;

  final ComicSource source;

  final ComicDetails comic;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  @override
  void initState() {
    likes = widget.comment.score ?? 0;
    isLiked = widget.comment.isLiked ?? false;
    voteStatus = widget.comment.voteStatus;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.comment.avatar != null)
            Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).colorScheme.secondaryContainer),
              child: AnimatedImage(
                image: CachedImageProvider(
                  widget.comment.avatar!,
                  sourceKey: widget.source.key,
                ),
              ),
            ).paddingRight(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.comment.userName),
                if (widget.comment.time != null)
                  Text(widget.comment.time!, style: ts.s12),
                const SizedBox(height: 4),
                Text(widget.comment.content),
                buildActions(),
              ],
            ),
          )
        ],
      ).paddingAll(16),
    );
  }

  Widget buildActions() {
    if (widget.comment.score == null && widget.comment.replyCount == null) {
      return const SizedBox();
    }
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.comment.score != null &&
              widget.source.voteCommentFunc != null)
            buildVote(),
          if (widget.comment.score != null &&
              widget.source.likeCommentFunc != null)
            buildLike(),
          if (widget.comment.replyCount != null) buildReply(),
        ],
      ),
    ).paddingTop(8);
  }

  Widget buildReply() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showSideBar(
            context,
            CommentsPage(
              data: widget.comic,
              source: widget.source,
              replyId: widget.comment.id,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_comment_outlined, size: 16),
            const SizedBox(width: 8),
            Text(widget.comment.replyCount.toString()),
          ],
        ).padding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      ),
    );
  }

  bool isLiking = false;

  bool isLiked = false;

  var likes = 0;

  Widget buildLike() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (isLiking) return;
          setState(() {
            isLiking = true;
          });
          var res = await widget.source.likeCommentFunc!(
            widget.comic.comicId,
            widget.comic.subId,
            widget.comment.id!,
            !isLiked,
          );
          if (res.success) {
            isLiked = !isLiked;
            likes += isLiked ? 1 : -1;
          } else {
            context.showMessage(message: res.errorMessage ?? "Error");
          }
          setState(() {
            isLiking = false;
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLiking)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(),
              )
            else if (isLiked)
              const Icon(Icons.favorite, size: 16)
            else
              const Icon(Icons.favorite_border, size: 16),
            const SizedBox(width: 8),
            Text(likes.toString()),
          ],
        ).padding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      ),
    );
  }

  int? voteStatus;

  bool isVoteUp = false;

  bool isVoteDown = false;

  void vote(bool isUp) async {
    if (isVoteUp || isVoteDown) return;
    setState(() {
      if (isUp) {
        isVoteUp = true;
      } else {
        isVoteDown = true;
      }
    });
    var res = await widget.source.voteCommentFunc!(
      widget.comic.comicId,
      widget.comic.subId,
      widget.comment.id!,
      isUp,
      (isUp && voteStatus == 1) || (!isUp && voteStatus == -1),
    );
    if (res.success) {
      if (isUp) {
        voteStatus = 1;
      } else {
        voteStatus = -1;
      }
    } else {
      context.showMessage(message: res.errorMessage ?? "Error");
    }
    setState(() {
      isVoteUp = false;
      isVoteDown = false;
    });
  }

  Widget buildVote() {
    var upColor = context.colorScheme.outline;
    if (voteStatus == 1) {
      upColor = context.useTextColor(Colors.red);
    }
    var downColor = context.colorScheme.outline;
    if (voteStatus == -1) {
      downColor = context.useTextColor(Colors.blue);
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button.icon(
            isLoading: isVoteUp,
            icon: const Icon(Icons.arrow_upward),
            size: 18,
            color: upColor,
            onPressed: () => vote(true),
          ),
          const SizedBox(width: 4),
          Text(widget.comment.score.toString()),
          const SizedBox(width: 4),
          Button.icon(
            isLoading: isVoteDown,
            icon: const Icon(Icons.arrow_downward),
            size: 18,
            color: downColor,
            onPressed: () => vote(false),
          ),
        ],
      ),
    );
  }
}
