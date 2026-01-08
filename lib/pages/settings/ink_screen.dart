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
      ],
    );
  }
}

