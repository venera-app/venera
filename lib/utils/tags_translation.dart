/*
数据来自于:
https://github.com/EhTagTranslation/Database/tree/master/database

繁体中文由 @NeKoOuO (https://github.com/NeKoOuO) 提供
*/


import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/utils/ext.dart';

extension TagsTranslation on String{
  static final Map<String, Map<String, String>> _data = {};

  static Future<void> readData() async{
    var fileName = App.locale.countryCode == 'TW'
        ? "assets/tags_tw.json"
        : "assets/tags.json";
    var data = await rootBundle.load(fileName);
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    const JsonDecoder().convert(const Utf8Decoder().convert(bytes)).forEach((key, value){
      _data[key] = {};
      value.forEach((key1, value1){
        _data[key]?[key1] = value1;
      });
    });
  }

  static bool _haveNamespace(String key) {
    return _data.containsKey(key);
  }

  /// 对tag进行处理后进行翻译: 代表'或'的分割符'|', namespace.
  static String _translateTags(String tag){
    if (tag.contains('|')) {
      var splits = tag.split('|');
      return enTagsTranslations[splits[0].trim()]
          ?? enTagsTranslations[splits[1].trim()]
          ?? tag;
    } else if(tag.contains(':')) {
      var splits = tag.split(':');
      if(_haveNamespace(splits[0])) {
        return translationTagWithNamespace(splits[1], splits[0]);
      } else {
        return tag;
      }
    } else {
      return enTagsTranslations[tag]??tag;
    }
  }

  /// translate tag's text to chinese
  String get translateTagsToCN => _translateTags(this);

  String get translateTagIfNeed {
    var locale = App.locale;
    if (locale.languageCode == "zh") {
      return translateTagsToCN;
    } else {
      return this;
    }
  }

  static String translateTag(String tag) {
    if(tag.contains(':') && tag.indexOf(':') == tag.lastIndexOf(':')) {
      var [namespace, text] = tag.split(':');
      return translationTagWithNamespace(text, namespace);
    } else {
      return tag.translateTagsToCN;
    }
  }

  static String translationTagWithNamespace(String text, String namespace){
    text = text.toLowerCase();
    if(text != "reclass" && text.endsWith('s')){
      text.replaceLast('s', '');
    }
    return switch(namespace){
      "male" => maleTags[text] ?? text,
      "female" => femaleTags[text] ?? text,
      "mixed" => mixedTags[text] ?? text,
      "other" => otherTags[text] ?? text,
      "parody" => parodyTags[text] ?? text,
      "character" => characterTranslations[text] ?? text,
      "group" => groupTags[text] ?? text,
      "cosplayer" => cosplayerTags[text] ?? text,
      "reclass" => reclassTags[text] ?? text,
      "language" => languageTranslations[text] ?? text,
      "artist" => artistTags[text] ?? text,
      _ => text.translateTagsToCN
    };
  }

  String _categoryTextDynamic(String c){
    if(App.locale.languageCode == "zh"){
      return translateTagsCategoryToCN;
    }else{
      return this;
    }
  }

  String get categoryTextDynamic => _categoryTextDynamic(this);

  String get translateTagsCategoryToCN => tagsCategoryTranslations[this]??this;

  get tagsCategoryTranslations => switch(App.locale.countryCode){
    "CN" => tagsCategoryTranslationsCN,
    "TW" => tagsCategoryTranslationsTW,
    _ => tagsCategoryTranslationsCN
  };

  static const tagsCategoryTranslationsCN = {
    "language": "语言",
    "artist": "画师",
    "male": "男性",
    "female": "女性",
    "mixed": "混合",
    "other": "其它",
    "parody": "原作",
    "character": "角色",
    "group": "团队",
    "cosplayer": "Coser",
    "reclass": "重新分类",
    "Languages": "语言",
    "Artists": "画师",
    "Characters": "角色",
    "Groups": "团队",
    "Tags": "标签",
    "Parodies": "原作",
    "Categories": "分类",
    "Time": "时间"
  };

  static const tagsCategoryTranslationsTW = {
    "language": "語言",
    "artist": "畫師",
    "male": "男性",
    "female": "女性",
    "mixed": "混合",
    "other": "其他",
    "parody": "原作",
    "character": "角色",
    "group": "團隊",
    "cosplayer": "Coser",
    "reclass": "重新分類",
    "Languages": "語言",
    "Artists": "畫師",
    "Characters": "角色",
    "Groups": "團隊",
    "Tags": "標籤",
    "Parodies": "原作",
    "Categories": "分類",
    "Time": "時間"
  };

  static Map<String, String> get maleTags => _data["male"] ?? const {};

  static Map<String, String> get femaleTags => _data["female"] ?? const {};

  static Map<String, String> get languageTranslations => _data["language"] ?? const {};

  static Map<String, String> get parodyTags => _data["parody"] ?? const {};

  static Map<String, String> get characterTranslations => _data["character"] ?? const {};

  static Map<String, String> get otherTags => _data["other"] ?? const {};

  static Map<String, String> get mixedTags => _data["mixed"] ?? const {};

  static Map<String, String> get characterTags => _data["character"] ?? const {};

  static Map<String, String> get artistTags => _data["artist"] ?? const {};

  static Map<String, String> get groupTags => _data["group"] ?? const {};

  static Map<String, String> get cosplayerTags => _data["cosplayer"] ?? const {};

  static Map<String, String> get reclassTags => _data["reclass"] ?? const {};

  /// English to chinese translations
  ///
  /// Not include artists and group
  static MultipleMap<String, String> get enTagsTranslations => MultipleMap([
    maleTags, femaleTags, languageTranslations, parodyTags, characterTranslations,
    otherTags, mixedTags
  ]);
}

enum TranslationType{
  female, male, mixed, language, other, group, artist, cosplayer, parody,
  character, reclass
}

class MultipleMap<S, T>{
  final List<Map<S, T>> maps;

  MultipleMap(this.maps);

  T? operator[](S key) {
    for (var map in maps){
      var value = map[key];
      if(value != null){
        return value;
      }
    }
    return null;
  }
}