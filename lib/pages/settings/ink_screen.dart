part of 'settings_page.dart';

class InkScreenSettings extends StatefulWidget {
  const InkScreenSettings({
    super.key,
    this.onChanged,
    this.comicId,
    this.comicSource,
  });

  final void Function(String key)? onChanged;
  final String? comicId;
  final String? comicSource;

  @override
  State<InkScreenSettings> createState() => _InkScreenSettingsState();
}

class _InkScreenSettingsState extends State<InkScreenSettings> {

  @override
  Widget build(BuildContext context) {
    final comicId = widget.comicId;
    final sourceKey = widget.comicSource;

    bool isEnabledSpecificSettings =
        comicId != null &&
        appdata.settings.isComicSpecificSettingsEnabled(comicId, sourceKey);

    final disableInertialScrolling =
        appdata.settings['disableInertialScrolling'] as bool;

    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Ink Screen Settings".tl)),
        _SwitchSetting(
          title: "Page animation".tl,
          settingKey: "enablePageAnimation",
          onChanged: () {
            widget.onChanged?.call("enablePageAnimation");
          },
          comicId: isEnabledSpecificSettings ? widget.comicId : null,
          comicSource: isEnabledSpecificSettings ? widget.comicSource : null,
        ).toSliver(),
        SelectSetting(
          title: "Image Scaling Filter".tl,
          settingKey: "inkImageFilterQuality",
          optionTranslation: {
            'none': 'Off'.tl,
            'low': 'Low (Bilinear)'.tl,
            'medium': 'Medium (Default)'.tl,
            'high': 'High (Smoother)'.tl,
          },
        ).toSliver(),
        _SwitchSetting(
          title: "Disable UI Animations".tl,
          settingKey: "disableAnimation",
        ).toSliver(),
        _SwitchSetting(
          title: "Disable Inertial Scrolling".tl,
          settingKey: "disableInertialScrolling",
          onChanged: () {
            setState(() {});
            widget.onChanged?.call("disableInertialScrolling");
          },
        ).toSliver(),
        SliverAnimatedVisibility(
          visible: disableInertialScrolling,
          child: _SliderSetting(
            title: "Page Turn Distance".tl,
            settingsIndex: "inkScrollPageFraction",
            interval: 0.05,
            min: 0.1,
            max: 1.0,
          ),
        ),
      ],
    );
  }
}

