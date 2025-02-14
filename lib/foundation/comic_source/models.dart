part of 'comic_source.dart';

class Comment {
  final String userName;
  final String? avatar;
  final String content;
  final String? time;
  final int? replyCount;
  final String? id;
  int? score;
  final bool? isLiked;
  int? voteStatus; // 1: upvote, -1: downvote, 0: none

  static String? parseTime(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      if (value < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000)
            .toString()
            .substring(0, 19);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(value)
            .toString()
            .substring(0, 19);
      }
    }
    return value.toString();
  }

  Comment.fromJson(Map<String, dynamic> json)
      : userName = json["userName"],
        avatar = json["avatar"],
        content = json["content"],
        time = parseTime(json["time"]),
        replyCount = json["replyCount"],
        id = json["id"].toString(),
        score = json["score"],
        isLiked = json["isLiked"],
        voteStatus = json["voteStatus"];
}

class Comic {
  final String title;

  final String cover;

  final String id;

  final String? subtitle;

  final List<String>? tags;

  final String description;

  final String sourceKey;

  final int? maxPage;

  final String? language;

  final String? favoriteId;

  /// 0-5
  final double? stars;

  const Comic(
    this.title,
    this.cover,
    this.id,
    this.subtitle,
    this.tags,
    this.description,
    this.sourceKey,
    this.maxPage,
    this.language,
  )   : favoriteId = null,
        stars = null;

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "cover": cover,
      "id": id,
      "subTitle": subtitle,
      "tags": tags,
      "description": description,
      "sourceKey": sourceKey,
      "maxPage": maxPage,
      "language": language,
      "favoriteId": favoriteId,
    };
  }

  Comic.fromJson(Map<String, dynamic> json, this.sourceKey)
      : title = json["title"],
        subtitle = json["subtitle"] ?? json["subTitle"] ?? "",
        cover = json["cover"],
        id = json["id"],
        tags = List<String>.from(json["tags"] ?? []),
        description = json["description"] ?? "",
        maxPage = json["maxPage"],
        language = json["language"],
        favoriteId = json["favoriteId"],
        stars = (json["stars"] as num?)?.toDouble();

  @override
  bool operator ==(Object other) {
    if (other is! Comic) return false;
    return other.id == id && other.sourceKey == sourceKey;
  }

  @override
  int get hashCode => id.hashCode ^ sourceKey.hashCode;
}

class ComicDetails with HistoryMixin {
  @override
  final String title;

  @override
  final String? subTitle;

  @override
  final String cover;

  final String? description;

  final Map<String, List<String>> tags;

  /// id-name
  final Map<String, String>? chapters;

  /// key is group name.
  /// When this field is not null, [chapters] will be a merged map of all groups.
  /// Only available in some sources.
  final Map<String, Map<String, String>>? groupedChapters;

  final List<String>? thumbnails;

  final List<Comic>? recommend;

  final String sourceKey;

  final String comicId;

  final bool? isFavorite;

  final String? subId;

  final bool? isLiked;

  final int? likesCount;

  final int? commentCount;

  final String? uploader;

  final String? uploadTime;

  final String? updateTime;

  final String? url;

  final double? stars;

  @override
  final int? maxPage;

  final List<Comment>? comments;

  static Map<String, List<String>> _generateMap(Map<dynamic, dynamic> map) {
    var res = <String, List<String>>{};
    map.forEach((key, value) {
      res[key] = List<String>.from(value);
    });
    return res;
  }

  static Map<String, String>? _getChapters(dynamic chapters) {
    if (chapters == null) return null;
    var result = <String, String>{};
    if (chapters is Map) {
      for (var entry in chapters.entries) {
        var value = entry.value;
        if (value is Map) {
          result.addAll(Map.from(value));
        } else {
          result[entry.key.toString()] = value.toString();
        }
      }
    }
    return result;
  }

  static Map<String, Map<String, String>>? _getGroupedChapters(dynamic chapters) {
    if (chapters == null) return null;
    var result = <String, Map<String, String>>{};
    if (chapters is Map) {
      for (var entry in chapters.entries) {
        var value = entry.value;
        if (value is Map) {
          result[entry.key.toString()] = Map.from(value);
        }
      }
    }
    if (result.isEmpty) return null;
    return result;
  }

  ComicDetails.fromJson(Map<String, dynamic> json)
      : title = json["title"],
        subTitle = json["subtitle"],
        cover = json["cover"],
        description = json["description"],
        tags = _generateMap(json["tags"]),
        chapters = _getChapters(json["chapters"]),
        groupedChapters = _getGroupedChapters(json["chapters"]),
        sourceKey = json["sourceKey"],
        comicId = json["comicId"],
        thumbnails = ListOrNull.from(json["thumbnails"]),
        recommend = (json["recommend"] as List?)
            ?.map((e) => Comic.fromJson(e, json["sourceKey"]))
            .toList(),
        isFavorite = json["isFavorite"],
        subId = json["subId"],
        likesCount = json["likesCount"],
        isLiked = json["isLiked"],
        commentCount = json["commentCount"],
        uploader = json["uploader"],
        uploadTime = json["uploadTime"],
        updateTime = json["updateTime"],
        url = json["url"],
        stars = (json["stars"] as num?)?.toDouble(),
        maxPage = json["maxPage"],
        comments = (json["comments"] as List?)
            ?.map((e) => Comment.fromJson(e))
            .toList();

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "subTitle": subTitle,
      "cover": cover,
      "description": description,
      "tags": tags,
      "chapters": chapters,
      "thumbnails": thumbnails,
      "recommend": null,
      "sourceKey": sourceKey,
      "comicId": comicId,
      "isFavorite": isFavorite,
      "subId": subId,
      "isLiked": isLiked,
      "likesCount": likesCount,
      "commentsCount": commentCount,
      "uploader": uploader,
      "uploadTime": uploadTime,
      "updateTime": updateTime,
      "url": url,
    };
  }

  @override
  HistoryType get historyType => HistoryType(sourceKey.hashCode);

  @override
  String get id => comicId;

  ComicType get comicType => ComicType(sourceKey.hashCode);

  /// Convert tags map to plain list
  List<String> get plainTags {
    var res = <String>[];
    tags.forEach((key, value) {
      res.addAll(value.map((e) => "$key:$e"));
    });
    return res;
  }

  /// Find the first author tag
  String? findAuthor() {
    var authorNamespaces = [
      "author",
      "authors",
      "artist",
      "artists",
      "作者",
      "画师"
    ];
    for (var entry in tags.entries) {
      if (authorNamespaces.contains(entry.key.toLowerCase()) &&
          entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }
}

class ArchiveInfo {
  final String title;
  final String description;
  final String id;

  ArchiveInfo.fromJson(Map<String, dynamic> json)
      : title = json["title"],
        description = json["description"],
        id = json["id"];
}
