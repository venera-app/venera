part of 'settings_page.dart';

class InkScreenSettings extends StatelessWidget {
  const InkScreenSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("墨水屏设置")),
        _SwitchSetting(
          title: "禁用UI动画",
          settingKey: "disableAnimation",
        ).toSliver(),
        _SwitchSetting(
          title: "禁用惯性滑动",
          settingKey: "disableInertialScrolling",
        ).toSliver(),
        _SliderSetting(
          title: "翻页距离（仅禁用惯性滑动时生效）",
          settingsIndex: "inkScrollPageFraction",
          interval: 0.05,
          min: 0.1,
          max: 1.0,
        ).toSliver(),
      ],
    );
  }
}

