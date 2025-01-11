part of 'settings_page.dart';

class ReaderSettings extends StatefulWidget {
  const ReaderSettings({super.key, this.onChanged});

  final void Function(String key)? onChanged;

  @override
  State<ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<ReaderSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Reading".tl)),
        _SwitchSetting(
          title: "Tap to turn Pages".tl,
          settingKey: "enableTapToTurnPages",
          onChanged: () {
            widget.onChanged?.call("enableTapToTurnPages");
          },
        ).toSliver(),
        _SwitchSetting(
          title: "Page animation".tl,
          settingKey: "enablePageAnimation",
          onChanged: () {
            widget.onChanged?.call("enablePageAnimation");
          },
        ).toSliver(),
        SelectSetting(
          title: "Reading mode".tl,
          settingKey: "readerMode",
          optionTranslation: {
            "galleryLeftToRight": "Gallery (Left to Right)".tl,
            "galleryRightToLeft": "Gallery (Right to Left)".tl,
            "galleryTopToBottom": "Gallery (Top to Bottom)".tl,
            "continuousLeftToRight": "Continuous (Left to Right)".tl,
            "continuousRightToLeft": "Continuous (Right to Left)".tl,
            "continuousTopToBottom": "Continuous (Top to Bottom)".tl,
          },
          onChanged: () {
            var readerMode = appdata.settings['readerMode'];
            if (readerMode?.toLowerCase().startsWith('continuous') ?? false) {
              appdata.settings['readerScreenPicNumber'] = 1;
              widget.onChanged?.call('readerScreenPicNumber');
            }
            widget.onChanged?.call("readerMode");
          },
        ).toSliver(),
        _SliderSetting(
          title: "Auto page turning interval".tl,
          settingsIndex: "autoPageTurningInterval",
          interval: 1,
          min: 1,
          max: 20,
          onChanged: () {
            widget.onChanged?.call("autoPageTurningInterval");
          },
        ).toSliver(),
        SliverToBoxAdapter(
          child: AbsorbPointer(
            absorbing: (appdata.settings['readerMode']
                    ?.toLowerCase()
                    .startsWith('continuous') ??
                false),
            child: AnimatedOpacity(
              opacity: (appdata.settings['readerMode']
                          ?.toLowerCase()
                          .startsWith('continuous') ??
                      false)
                  ? 0.5
                  : 1.0,
              duration: Duration(milliseconds: 300),
              child: _SliderSetting(
                title: "The number of pic in screen (Only Gallery Mode)".tl,
                settingsIndex: "readerScreenPicNumber",
                interval: 1,
                min: 1,
                max: 5,
                onChanged: () {
                  widget.onChanged?.call("readerScreenPicNumber");
                },
              ),
            ),
          ),
        ),
        _SwitchSetting(
          title: 'Long press to zoom'.tl,
          settingKey: 'enableLongPressToZoom',
          onChanged: () {
            widget.onChanged?.call('enableLongPressToZoom');
          },
        ).toSliver(),
        _SwitchSetting(
          title: 'Limit image width'.tl,
          subtitle: 'When using Continuous(Top to Bottom) mode'.tl,
          settingKey: 'limitImageWidth',
          onChanged: () {
            widget.onChanged?.call('limitImageWidth');
          },
        ).toSliver(),
        if (App.isAndroid)
          _SwitchSetting(
            title: 'Turn page by volume keys'.tl,
            settingKey: 'enableTurnPageByVolumeKey',
            onChanged: () {
              widget.onChanged?.call('enableTurnPageByVolumeKey');
            },
          ).toSliver(),
        _SwitchSetting(
          title: "Display time & battery info in reader".tl,
          settingKey: "enableClockAndBatteryInfoInReader",
          onChanged: () {
            widget.onChanged?.call("enableClockAndBatteryInfoInReader");
          },
        ).toSliver(),
        SelectSetting(
          title: "Quick collect image".tl,
          settingKey: "quickCollectImage",
          optionTranslation: {
            "No": "Not enable".tl,
            "DoubleTap": "Double Tap".tl,
            "Swipe": "Swipe".tl,
          },
          onChanged: () {
            widget.onChanged?.call("quickCollectImage");
          },
          help:
              "On the image browsing page, you can quickly collect images by sliding horizontally or vertically according to your reading mode"
                  .tl,
        ).toSliver(),
        _PopupWindowSetting(
          title: "Custom Image Processing".tl,
          builder: () => _CustomImageProcessing(),
        ).toSliver(),
      ],
    );
  }
}

class _CustomImageProcessing extends StatefulWidget {
  const _CustomImageProcessing();

  @override
  State<_CustomImageProcessing> createState() => __CustomImageProcessingState();
}

class __CustomImageProcessingState extends State<_CustomImageProcessing> {
  var current = '';

  @override
  void initState() {
    super.initState();
    current = appdata.settings['customImageProcessing'];
  }

  @override
  void dispose() {
    appdata.settings['customImageProcessing'] = current;
    appdata.saveData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Custom Image Processing".tl,
      body: Column(
        children: [
          _SwitchSetting(
            title: "Enable".tl,
            settingKey: "enableCustomImageProcessing",
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.colorScheme.outlineVariant),
              ),
              child: SizedBox.expand(
                child: CodeEditor(
                  initialValue: appdata.settings['customImageProcessing'],
                  onChanged: (value) {
                    current = value;
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
