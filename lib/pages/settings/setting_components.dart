part of 'settings_page.dart';

class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({
    required this.title,
    required this.settingKey,
    this.onChanged,
  });

  final String title;

  final String settingKey;

  final VoidCallback? onChanged;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  @override
  Widget build(BuildContext context) {
    assert(appdata.settings[widget.settingKey] is bool);

    return ListTile(
      title: Text(widget.title),
      trailing: Switch(
        value: appdata.settings[widget.settingKey],
        onChanged: (value) {
          setState(() {
            appdata.settings[widget.settingKey] = value;
            appdata.saveData();
          });
          widget.onChanged?.call();
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
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

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
            );
          } else {
            return _EndSelectorSelectSetting(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
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
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  @override
  State<_DoubleLineSelectSettings> createState() =>
      _DoubleLineSelectSettingsState();
}

class _DoubleLineSelectSettingsState extends State<_DoubleLineSelectSettings> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle:
          Text(widget.optionTranslation[appdata.settings[widget.settingKey]]!),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        var renderBox = context.findRenderObject() as RenderBox;
        var offset = renderBox.localToGlobal(Offset.zero);
        var size = renderBox.size;
        var rect = offset & size;
        showMenu(
          elevation: 3,
          color: context.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
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
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  @override
  State<_EndSelectorSelectSetting> createState() =>
      _EndSelectorSelectSettingState();
}

class _EndSelectorSelectSettingState extends State<_EndSelectorSelectSetting> {
  @override
  Widget build(BuildContext context) {
    var options = widget.optionTranslation;
    return ListTile(
      title: Text(widget.title),
      trailing: Select(
        current: options[appdata.settings[widget.settingKey]]!,
        values: options.values.toList(),
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
