import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/state_controller.dart';
import 'package:venera/pages/search_page.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/translations.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({
    super.key,
    required this.text,
    required this.sourceKey,
    this.options,
  });

  final String text;

  final String sourceKey;

  final List<String>? options;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late SearchBarController controller;

  late String sourceKey;

  late List<String> options;

  late String text;

  OverlayEntry? get suggestionOverlay => suggestionsController.entry;

  late _SuggestionsController suggestionsController;

  void search([String? text]) {
    if (text != null) {
      if (suggestionsController.entry != null) {
        suggestionsController.remove();
      }
      setState(() {
        this.text = text;
      });
      appdata.addSearchHistory(text);
      controller.currentText = text;
    }
  }

  void onChanged(String s) {
    if (!ComicSource.find(sourceKey)!.enableTagsSuggestions) {
      return;
    }
    suggestionsController.findSuggestions();
    if (suggestionOverlay != null) {
      if (suggestionsController.suggestions.isEmpty) {
        suggestionsController.remove();
      } else {
        suggestionsController.updateWidget();
      }
    } else if (suggestionsController.suggestions.isNotEmpty) {
      suggestionsController.entry = OverlayEntry(
        builder: (context) {
          return Positioned(
            top: context.padding.top + 56,
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              child: _Suggestions(
                controller: suggestionsController,
              ),
            ),
          );
        },
      );
      Overlay.of(context).insert(suggestionOverlay!);
    }
  }

  @override
  void dispose() {
    Future.microtask(() {
      suggestionsController.remove();
    });
    super.dispose();
  }

  @override
  void initState() {
    controller = SearchBarController(
      currentText: widget.text,
      onSearch: search,
    );
    sourceKey = widget.sourceKey;
    options = widget.options ?? const [];
    validateOptions();
    text = widget.text;
    appdata.addSearchHistory(text);
    suggestionsController = _SuggestionsController(controller);
    super.initState();
  }

  void validateOptions() {
    var source = ComicSource.find(sourceKey);
    if (source == null) {
      return;
    }
    var searchOptions = source.searchPageData!.searchOptions;
    if (searchOptions == null) {
      return;
    }
    if (options.length != searchOptions.length) {
      options = searchOptions.map((e) => e.defaultValue).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(sourceKey);
    return ComicList(
      key: Key(text + options.toString() + sourceKey),
      errorLeading: AppSearchBar(
        controller: controller,
        action: buildAction(),
      ),
      leadingSliver: SliverSearchBar(
        controller: controller,
        onChanged: onChanged,
        action: buildAction(),
      ),
      loadPage: source!.searchPageData!.loadPage == null
          ? null
          : (i) {
              return source.searchPageData!.loadPage!(
                text,
                i,
                options,
              );
            },
      loadNext: source.searchPageData!.loadNext == null
          ? null
          : (i) {
              return source.searchPageData!.loadNext!(
                text,
                i,
                options,
              );
            },
    );
  }

  Widget buildAction() {
    return Tooltip(
      message: "Settings".tl,
      child: IconButton(
        icon: const Icon(Icons.tune),
        onPressed: () async {
          await showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) {
              return _SearchSettingsDialog(state: this);
            },
          );
          setState(() {});
        },
      ),
    );
  }
}

class _SuggestionsController {
  _SuggestionsState? _state;

  final SearchBarController controller;

  OverlayEntry? entry;

  void updateWidget() {
    _state?.update();
  }

  void remove() {
    entry?.remove();
    entry = null;
  }

  var suggestions = <Pair<String, TranslationType>>[];

  void findSuggestions() {
    var text = controller.text.split(" ").last;
    var suggestions = this.suggestions;

    suggestions.clear();

    bool check(String text, String key, String value) {
      if (text.removeAllBlank == "") {
        return false;
      }
      if (key.length >= text.length && key.substring(0, text.length) == text ||
          (key.contains(" ") &&
              key.split(" ").last.length >= text.length &&
              key.split(" ").last.substring(0, text.length) == text)) {
        return true;
      } else if (value.length >= text.length && value.contains(text)) {
        return true;
      }
      return false;
    }

    void find(Map<String, String> map, TranslationType type) {
      for (var element in map.entries) {
        if (suggestions.length > 200) {
          break;
        }
        if (check(text, element.key, element.value)) {
          suggestions.add(Pair(element.key, type));
        }
      }
    }

    find(TagsTranslation.femaleTags, TranslationType.female);
    find(TagsTranslation.maleTags, TranslationType.male);
    find(TagsTranslation.parodyTags, TranslationType.parody);
    find(TagsTranslation.characterTranslations, TranslationType.character);
    find(TagsTranslation.otherTags, TranslationType.other);
    find(TagsTranslation.mixedTags, TranslationType.mixed);
    find(TagsTranslation.languageTranslations, TranslationType.language);
    find(TagsTranslation.artistTags, TranslationType.artist);
    find(TagsTranslation.groupTags, TranslationType.group);
    find(TagsTranslation.cosplayerTags, TranslationType.cosplayer);
  }

  _SuggestionsController(this.controller);
}

class _Suggestions extends StatefulWidget {
  const _Suggestions({required this.controller});

  final _SuggestionsController controller;

  @override
  State<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends State<_Suggestions> {
  void update() {
    setState(() {});
  }

  @override
  void initState() {
    widget.controller._state = this;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _Suggestions oldWidget) {
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return buildSuggestions(context);
  }

  Widget buildSuggestions(BuildContext context) {
    bool showMethod = MediaQuery.of(context).size.width < 600;
    bool showTranslation = App.locale.languageCode == "zh";

    Widget buildItem(Pair<String, TranslationType> value) {
      var subTitle = TagsTranslation.translationTagWithNamespace(
          value.left, value.right.name);
      return ListTile(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                value.left,
                maxLines: 2,
              ),
            ),
            if (!showMethod)
              const SizedBox(
                width: 12,
              ),
            if (!showMethod && showTranslation)
              Text(
                subTitle,
                style: TextStyle(
                    fontSize: 14, color: Theme.of(context).colorScheme.outline),
              )
          ],
        ),
        subtitle: (showMethod && showTranslation) ? Text(subTitle) : null,
        trailing: Text(
          value.right.name,
          style: const TextStyle(fontSize: 13),
        ),
        onTap: () => onSelected(value.left, value.right),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.hub_outlined),
          title: Text("Suggestions".tl),
          trailing: Tooltip(
            message: "Clear".tl,
            child: IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                widget.controller.suggestions.clear();
                widget.controller.remove();
              },
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.controller.suggestions.length,
            itemBuilder: (context, index) =>
                buildItem(widget.controller.suggestions[index]),
          ),
        )
      ],
    );
  }

  bool check(String text, String key, String value) {
    if (text.removeAllBlank == "") {
      return false;
    }
    if (key.length >= text.length && key.substring(0, text.length) == text ||
        (key.contains(" ") &&
            key.split(" ").last.length >= text.length &&
            key.split(" ").last.substring(0, text.length) == text)) {
      return true;
    } else if (value.length >= text.length && value.contains(text)) {
      return true;
    }
    return false;
  }

  void onSelected(String text, TranslationType? type) {
    var controller = widget.controller.controller;
    var words = controller.text.split(" ");
    if (words.length >= 2 &&
        check("${words[words.length - 2]} ${words[words.length - 1]}", text,
            text.translateTagsToCN)) {
      controller.text = controller.text.replaceLast(
          "${words[words.length - 2]} ${words[words.length - 1]}", "");
    } else {
      controller.text =
          controller.text.replaceLast(words[words.length - 1], "");
    }
    if (text.contains(' ')) {
      text = "'$text'";
    }
    if (type != null) {
      controller.text += "${type.name}:$text ";
    } else {
      controller.text += "$text ";
    }
    widget.controller.suggestions.clear();
    widget.controller.remove();
  }
}

class _SearchSettingsDialog extends StatefulWidget {
  const _SearchSettingsDialog({required this.state});

  final _SearchResultPageState state;

  @override
  State<_SearchSettingsDialog> createState() => _SearchSettingsDialogState();
}

class _SearchSettingsDialogState extends State<_SearchSettingsDialog> {
  late String searchTarget;

  late List<String> options;

  @override
  void initState() {
    searchTarget = widget.state.sourceKey;
    options = widget.state.options;
    super.initState();
  }

  void onChanged() {
    widget.state.sourceKey = searchTarget;
    widget.state.options = options;
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "Settings".tl,
      content: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text("Search in".tl),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ComicSource.all().map((e) {
              return OptionChip(
                text: e.name.tl,
                isSelected: searchTarget == e.key,
                onTap: () {
                  setState(() {
                    searchTarget = e.key;
                    options.clear();
                    final searchOptions = ComicSource.find(searchTarget)!
                            .searchPageData!
                            .searchOptions ??
                        <SearchOptions>[];
                    options = searchOptions.map((e) => e.defaultValue).toList();
                    onChanged();
                  });
                },
              );
            }).toList(),
          ).fixWidth(double.infinity).paddingHorizontal(16),
          buildSearchOptions(),
          const SizedBox(height: 24),
          FilledButton(
            child: Text("Confirm".tl),
            onPressed: () {
              context.pop();
            },
          ),
        ],
      ).fixWidth(double.infinity),
    );
  }

  Widget buildSearchOptions() {
    var children = <Widget>[];

    final searchOptions =
        ComicSource.find(searchTarget)!.searchPageData!.searchOptions ??
            <SearchOptions>[];
    if (searchOptions.length != options.length) {
      options = searchOptions.map((e) => e.defaultValue).toList();
    }
    if (searchOptions.isEmpty) {
      return const SizedBox();
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(SearchOptionWidget(
        option: option,
        value: options[i],
        onChanged: (value) {
          setState(() {
            options[i] = value;
          });
        },
        sourceKey: searchTarget,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
