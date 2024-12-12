part of 'settings_page.dart';

class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({
    required this.title,
    required this.settingKey,
    this.onChanged,
    this.subtitle,
  });

  final String title;

  final String settingKey;

  final VoidCallback? onChanged;

  final String? subtitle;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  @override
  Widget build(BuildContext context) {
    assert(appdata.settings[widget.settingKey] is bool);

    return ListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      trailing: Switch(
        value: appdata.settings[widget.settingKey],
        onChanged: (value) {
          setState(() {
            appdata.settings[widget.settingKey] = value;
          });
          appdata.saveData().then((_) {
            widget.onChanged?.call();
          });
        },
      ),
    );
  }
}

class SelectSetting extends StatelessWidget {
  const SelectSetting({
    super.key,
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return _DoubleLineSelectSettings(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
            );
          } else {
            return _EndSelectorSelectSetting(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
            );
          }
        },
      ),
    );
  }
}

class _DoubleLineSelectSettings extends StatefulWidget {
  const _DoubleLineSelectSettings({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  State<_DoubleLineSelectSettings> createState() =>
      _DoubleLineSelectSettingsState();
}

class _DoubleLineSelectSettingsState extends State<_DoubleLineSelectSettings> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const SizedBox(width: 4),
          if (widget.help != null)
            Button.icon(
              size: 18,
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: "Help".tl,
                      content: Text(widget.help!)
                          .paddingHorizontal(16)
                          .fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text("OK".tl),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      subtitle: Text(
          widget.optionTranslation[appdata.settings[widget.settingKey]] ??
              "None"),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        var renderBox = context.findRenderObject() as RenderBox;
        var offset = renderBox.localToGlobal(Offset.zero);
        var size = renderBox.size;
        var rect = offset & size;
        showMenu(
          elevation: 3,
          color: context.brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF1E1E1E),
          context: context,
          position: RelativeRect.fromRect(
            rect,
            Offset.zero & MediaQuery.of(context).size,
          ),
          items: widget.optionTranslation.keys
              .map((key) => PopupMenuItem(
                    value: key,
                    height: App.isMobile ? 46 : 40,
                    child: Text(widget.optionTranslation[key]!),
                  ))
              .toList(),
        ).then((value) {
          if (value != null) {
            setState(() {
              appdata.settings[widget.settingKey] = value;
            });
            appdata.saveData();
            widget.onChanged?.call();
          }
        });
      },
    );
  }
}

class _EndSelectorSelectSetting extends StatefulWidget {
  const _EndSelectorSelectSetting({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  State<_EndSelectorSelectSetting> createState() =>
      _EndSelectorSelectSettingState();
}

class _EndSelectorSelectSettingState extends State<_EndSelectorSelectSetting> {
  @override
  Widget build(BuildContext context) {
    var options = widget.optionTranslation;
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const SizedBox(width: 4),
          if (widget.help != null)
            Button.icon(
              size: 18,
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: "Help".tl,
                      content: Text(widget.help!)
                          .paddingHorizontal(16)
                          .fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text("OK".tl),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      trailing: Select(
        current: options[appdata.settings[widget.settingKey]],
        values: options.values.toList(),
        minWidth: 64,
        onTap: (index) {
          setState(() {
            appdata.settings[widget.settingKey] = options.keys.elementAt(index);
          });
          appdata.saveData();
          widget.onChanged?.call();
        },
      ),
    );
  }
}

class _SliderSetting extends StatefulWidget {
  const _SliderSetting({
    required this.title,
    required this.settingsIndex,
    required this.interval,
    required this.min,
    required this.max,
    this.onChanged,
  });

  final String title;

  final String settingsIndex;

  final double interval;

  final double min;

  final double max;

  final VoidCallback? onChanged;

  @override
  State<_SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<_SliderSetting> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const Spacer(),
          Text(
            appdata.settings[widget.settingsIndex].toString(),
            style: ts.s12,
          ),
        ],
      ),
      subtitle: Slider(
        value: appdata.settings[widget.settingsIndex].toDouble(),
        onChanged: (value) {
          if (value.toInt() == value) {
            setState(() {
              appdata.settings[widget.settingsIndex] = value.toInt();
              appdata.saveData();
            });
          } else {
            setState(() {
              appdata.settings[widget.settingsIndex] = value;
              appdata.saveData();
            });
          }
          widget.onChanged?.call();
        },
        divisions: ((widget.max - widget.min) / widget.interval).toInt(),
        min: widget.min,
        max: widget.max,
      ),
    );
  }
}

class _PopupWindowSetting extends StatelessWidget {
  const _PopupWindowSetting({required this.title, required this.builder});

  final Widget Function() builder;

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_right),
      onTap: () {
        showPopUpWidget(App.rootContext, builder());
      },
    );
  }
}

class _MultiPagesFilter extends StatefulWidget {
  const _MultiPagesFilter({
    required this.title,
    required this.settingsIndex,
    required this.pages,
  });

  final String title;

  final String settingsIndex;

  // key - name
  final Map<String, String> pages;

  @override
  State<_MultiPagesFilter> createState() => _MultiPagesFilterState();
}

class _MultiPagesFilterState extends State<_MultiPagesFilter> {
  late List<String> keys;

  @override
  void initState() {
    keys = List.from(appdata.settings[widget.settingsIndex]);
    keys.remove("");
    super.initState();
  }

  var reorderWidgetKey = UniqueKey();
  var scrollController = ScrollController();
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var tiles = keys.map((e) => buildItem(e)).toList();

    var view = ReorderableBuilder<String>(
      key: reorderWidgetKey,
      scrollController: scrollController,
      longPressDelay: App.isDesktop
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 500),
      dragChildBoxDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
              spreadRadius: 2)
        ],
      ),
      onReorder: (reorderFunc) {
        setState(() {
          keys = List.from(reorderFunc(keys));
        });
        updateSetting();
      },
      children: tiles,
      builder: (children) {
        return GridView(
          key: _key,
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 48,
          ),
          children: children,
        );
      },
    );

    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        if (keys.length < widget.pages.length)
          IconButton(onPressed: showAddDialog, icon: const Icon(Icons.add))
      ],
      body: view,
    );
  }

  Widget buildItem(String key) {
    Widget removeButton = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
          onPressed: () {
            setState(() {
              keys.remove(key);
            });
            updateSetting();
          },
          icon: const Icon(Icons.delete)),
    );

    return ListTile(
      title: Text(widget.pages[key] ?? "(Invalid) $key"),
      key: Key(key),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          removeButton,
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }

  void showAddDialog() {
    var canAdd = <String, String>{};
    widget.pages.forEach((key, value) {
      if (!keys.contains(key)) {
        canAdd[key] = value;
      }
    });
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: "Add".tl,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: canAdd.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.value),
                    key: Key(e.key),
                    onTap: () {
                      context.pop();
                      setState(() {
                        keys.add(e.key);
                      });
                      updateSetting();
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void updateSetting() {
    appdata.settings[widget.settingsIndex] = keys;
    appdata.saveData();
  }
}

class _CallbackSetting extends StatelessWidget {
  const _CallbackSetting({
    required this.title,
    required this.callback,
    required this.actionTitle,
    this.subtitle,
  });

  final String title;

  final String? subtitle;

  final VoidCallback callback;

  final String actionTitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Button.normal(
        onPressed: callback,
        child: Text(actionTitle),
      ).fixHeight(28),
      onTap: callback,
    );
  }
}

class _SettingPartTitle extends StatelessWidget {
  const _SettingPartTitle({required this.title, required this.icon});

  final String title;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(title, style: ts.s18),
          ],
        ),
      ),
    );
  }
}
