part of 'settings_page.dart';

class InkScreenSettings extends StatelessWidget {
  const InkScreenSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("墨水屏设置")),
        SelectSetting(
          title: "图片缩放滤波（开启后缩放更平滑）",
          settingKey: "inkImageFilterQuality",
          optionTranslation: {
            'none': '关闭',
            'low': '低（双线性）',
            'medium': '中（默认/与原程序一致）',
            'high': '高（更平滑）',
          },
        ).toSliver(),
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

