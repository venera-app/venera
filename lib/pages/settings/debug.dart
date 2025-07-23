part of 'settings_page.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => DebugPageState();
}

class DebugPageState extends State<DebugPage> {
  final controller = TextEditingController();

  var result = "";

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Debug".tl)),
        _CallbackSetting(
          title: "Reload Configs".tl,
          actionTitle: "Reload".tl,
          callback: () {
            ComicSourceManager().reload();
          },
        ).toSliver(),
        _CallbackSetting(
          title: "Open Log".tl,
          callback: () {
            context.to(() => const LogsPage());
          },
          actionTitle: 'Open'.tl,
        ).toSliver(),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                "JS Evaluator",
                style: TextStyle(fontSize: 16),
              ).toAlign(Alignment.centerLeft).paddingLeft(16),
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlign: TextAlign.start,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  try {
                    var res = JsEngine().runCode(controller.text);
                    setState(() {
                      result = res.toString();
                    });
                  } catch (e) {
                    setState(() {
                      result = e.toString();
                    });
                  }
                },
                child: const Text("Run"),
              ).toAlign(Alignment.centerRight).paddingRight(16),
              const Text(
                "Result",
                style: TextStyle(fontSize: 16),
              ).toAlign(Alignment.centerLeft).paddingLeft(16),
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(result).paddingAll(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
