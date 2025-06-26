part of 'settings_page.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("App".tl)),
        _SettingPartTitle(
          title: "Data".tl,
          icon: Icons.storage,
        ),
        ListTile(
          title: Text("Storage Path for local comics".tl),
          subtitle: Text(LocalManager().path, softWrap: false),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: LocalManager().path));
              context.showMessage(message: "Path copied to clipboard".tl);
            },
          ),
        ).toSliver(),
        _CallbackSetting(
          title: "Set New Storage Path".tl,
          actionTitle: "Set".tl,
          callback: () async {
            String? result;
            if (App.isAndroid) {
              var picker = DirectoryPicker();
              result = (await picker.pickDirectory())?.path;
            } else if (App.isIOS) {
              result = await selectDirectoryIOS();
            } else {
              result = await selectDirectory();
            }
            if (result == null) return;
            var loadingDialog = showLoadingDialog(
              App.rootContext,
              barrierDismissible: false,
              allowCancel: false,
            );
            var res = await LocalManager().setNewPath(result);
            loadingDialog.close();
            if (res != null) {
              context.showMessage(message: res);
            } else {
              context.showMessage(message: "Path set successfully".tl);
              setState(() {});
            }
          },
        ).toSliver(),
        ListTile(
          title: Text("Cache Size".tl),
          subtitle: Text(bytesToReadableString(CacheManager().currentSize)),
        ).toSliver(),
        _CallbackSetting(
          title: "Clear Cache".tl,
          actionTitle: "Clear".tl,
          callback: () async {
            var loadingDialog = showLoadingDialog(
              App.rootContext,
              barrierDismissible: false,
              allowCancel: false,
            );
            await CacheManager().clear();
            loadingDialog.close();
            context.showMessage(message: "Cache cleared".tl);
            setState(() {});
          },
        ).toSliver(),
        _CallbackSetting(
          title: "Cache Limit".tl,
          subtitle: "${appdata.settings['cacheSize']} MB",
          callback: () {
            showInputDialog(
              context: context,
              title: "Set Cache Limit".tl,
              hintText: "Size in MB".tl,
              inputValidator: RegExp(r"^\d+$"),
              onConfirm: (value) {
                appdata.settings['cacheSize'] = int.parse(value);
                appdata.saveData();
                setState(() {});
                CacheManager().setLimitSize(appdata.settings['cacheSize']);
                return null;
              },
            );
          },
          actionTitle: 'Set'.tl,
        ).toSliver(),
        _CallbackSetting(
          title: "Export App Data".tl,
          callback: () async {
            var controller = showLoadingDialog(context);
            var file = await exportAppData();
            await saveFile(filename: "data.venera", file: file);
            controller.close();
          },
          actionTitle: 'Export'.tl,
        ).toSliver(),
        _CallbackSetting(
          title: "Import App Data".tl,
          callback: () async {
            var controller = showLoadingDialog(context);
            var file = await selectFile(ext: ['venera', 'picadata']);
            if (file != null) {
              var cacheFile =
                  File(FilePath.join(App.cachePath, "import_data_temp"));
              await file.saveTo(cacheFile.path);
              try {
                if (file.name.endsWith('picadata')) {
                  await importPicaData(cacheFile);
                } else {
                  await importAppData(cacheFile);
                }
              } catch (e, s) {
                Log.error("Import data", e.toString(), s);
                context.showMessage(message: "Failed to import data".tl);
              } finally {
                cacheFile.deleteIgnoreError();
                App.forceRebuild();
              }
            }
            controller.close();
          },
          actionTitle: 'Import'.tl,
        ).toSliver(),
        _CallbackSetting(
          title: "Data Sync".tl,
          callback: () async {
            showPopUpWidget(context, const _WebdavSetting());
          },
          actionTitle: 'Set'.tl,
        ).toSliver(),
        _SettingPartTitle(
          title: "User".tl,
          icon: Icons.person_outline,
        ),
        SelectSetting(
          title: "Language".tl,
          settingKey: "language",
          optionTranslation: const {
            "system": "System",
            "zh-CN": "简体中文",
            "zh-TW": "繁體中文",
            "en-US": "English",
          },
          onChanged: () {
            App.forceRebuild();
          },
        ).toSliver(),
        if (!App.isLinux)
          _SwitchSetting(
            title: "Authorization Required".tl,
            settingKey: "authorizationRequired",
            onChanged: () async {
              var current = appdata.settings['authorizationRequired'];
              if (current) {
                final auth = LocalAuthentication();
                final bool canAuthenticateWithBiometrics =
                    await auth.canCheckBiometrics;
                final bool canAuthenticate = canAuthenticateWithBiometrics ||
                    await auth.isDeviceSupported();
                if (!canAuthenticate) {
                  context.showMessage(message: "Biometrics not supported".tl);
                  setState(() {
                    appdata.settings['authorizationRequired'] = false;
                  });
                  appdata.saveData();
                  return;
                }
              }
            },
          ).toSliver(),
      ],
    );
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String logLevelToShow = "all";

  @override
  Widget build(BuildContext context) {
    var logToShow = logLevelToShow == "all"
        ? Log.logs
        : Log.logs.where((log) => log.level.name == logLevelToShow).toList();
    return Scaffold(
      appBar: Appbar(
        title: Text("Logs".tl),
        actions: [
          IconButton(
              onPressed: () => setState(() {
                    final RelativeRect position = RelativeRect.fromLTRB(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).padding.top + kToolbarHeight,
                      0.0,
                      0.0,
                    );
                    showMenu(context: context, position: position, items: [
                      PopupMenuItem(
                          child: Text("all"),
                          onTap: () => setState(() => logLevelToShow = "all")
                      ),
                      PopupMenuItem(
                          child: Text("info"),
                          onTap: () => setState(() => logLevelToShow = "info")
                      ),
                      PopupMenuItem(
                          child: Text("warning"),
                          onTap: () => setState(() => logLevelToShow = "warning")
                      ),
                      PopupMenuItem(
                          child: Text("error"),
                          onTap: () => setState(() => logLevelToShow = "error")
                      ),
                    ]);
              }),
              icon: const Icon(Icons.filter_list_outlined)
          ),
          IconButton(
              onPressed: () => setState(() {
                    final RelativeRect position = RelativeRect.fromLTRB(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).padding.top + kToolbarHeight,
                      0.0,
                      0.0,
                    );
                    showMenu(context: context, position: position, items: [
                      PopupMenuItem(
                        child: Text("Clear".tl),
                        onTap: () => setState(() => Log.clear()),
                      ),
                      PopupMenuItem(
                        child: Text("Disable Length Limitation".tl),
                        onTap: () {
                          Log.ignoreLimitation = true;
                          context.showMessage(
                              message: "Only valid for this run".tl);
                        },
                      ),
                      PopupMenuItem(
                        child: Text("Export".tl),
                        onTap: () => saveLog(Log().toString()),
                      ),
                    ]);
                  }),
              icon: const Icon(Icons.more_horiz))
        ],
      ),
      body: ListView.builder(
        reverse: true,
        controller: ScrollController(),
        itemCount: logToShow.length,
        itemBuilder: (context, index) {
          index = logToShow.length - index - 1;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 5, 1),
                          child: Text(logToShow[index].title),
                        ),
                      ),
                      const SizedBox(
                        width: 3,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: [
                            Theme.of(context).colorScheme.error,
                            Theme.of(context).colorScheme.errorContainer,
                            Theme.of(context).colorScheme.primaryContainer
                          ][logToShow[index].level.index],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 5, 1),
                          child: Text(
                            logToShow[index].level.name,
                            style: TextStyle(
                                color: logToShow[index].level.index == 0
                                    ? Colors.white
                                    : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(logToShow[index].content),
                  Text(logToShow[index].time
                      .toString()
                      .replaceAll(RegExp(r"\.\w+"), "")),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: logToShow[index].content));
                    },
                    child: Text("Copy".tl),
                  ),
                  const Divider(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void saveLog(String log) async {
    saveFile(data: utf8.encode(log), filename: 'log.txt');
  }
}

class _WebdavSetting extends StatefulWidget {
  const _WebdavSetting();

  @override
  State<_WebdavSetting> createState() => _WebdavSettingState();
}

class _WebdavSettingState extends State<_WebdavSetting> {
  String url = "";
  String user = "";
  String pass = "";
  bool autoSync = true;

  bool isTesting = false;
  bool upload = true;

  @override
  void initState() {
    super.initState();
    if (appdata.settings['webdav'] is! List) {
      appdata.settings['webdav'] = [];
    }
    var configs = appdata.settings['webdav'] as List;
    if (configs.whereType<String>().length != 3) {
      return;
    }
    url = configs[0];
    user = configs[1];
    pass = configs[2];
    autoSync = appdata.implicitData['webdavAutoSync'] ?? true;
  }

  void onAutoSyncChanged(bool value) {
    setState(() {
      autoSync = value;
      appdata.implicitData['webdavAutoSync'] = value;
      appdata.writeImplicitData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Webdav",
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "URL",
                hintText: "A valid WebDav directory URL".tl,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: url),
              onChanged: (value) => url = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "Username".tl,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: user),
              onChanged: (value) => user = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "Password".tl,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: pass),
              onChanged: (value) => pass = value,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.sync),
              title: Text("Auto Sync Data".tl),
              contentPadding: EdgeInsets.zero,
              trailing: Switch(
                value: autoSync,
                onChanged: onAutoSyncChanged,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text("Operation".tl),
                Radio<bool>(
                  groupValue: upload,
                  value: true,
                  onChanged: (value) {
                    setState(() {
                      upload = value!;
                    });
                  },
                ),
                Text("Upload".tl),
                Radio<bool>(
                  groupValue: upload,
                  value: false,
                  onChanged: (value) {
                    setState(() {
                      upload = value!;
                    });
                  },
                ),
                Text("Download".tl),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: autoSync
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                "Once the operation is successful, app will automatically sync data with the server."
                                    .tl),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Center(
              child: Button.filled(
                isLoading: isTesting,
                onPressed: () async {
                  var oldConfig = appdata.settings['webdav'];
                  var oldAutoSync = appdata.implicitData['webdavAutoSync'];

                  if (url.trim().isEmpty &&
                      user.trim().isEmpty &&
                      pass.trim().isEmpty) {
                    appdata.settings['webdav'] = [];
                    appdata.implicitData['webdavAutoSync'] = false;
                    appdata.writeImplicitData();
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                    return;
                  }

                  appdata.settings['webdav'] = [url, user, pass];
                  appdata.implicitData['webdavAutoSync'] = autoSync;
                  appdata.writeImplicitData();

                  if (!autoSync) {
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                    return;
                  }

                  setState(() {
                    isTesting = true;
                  });
                  var testResult = upload
                      ? await DataSync().uploadData()
                      : await DataSync().downloadData();
                  if (testResult.error) {
                    setState(() {
                      isTesting = false;
                    });
                    appdata.settings['webdav'] = oldConfig;
                    appdata.implicitData['webdavAutoSync'] = oldAutoSync;
                    appdata.writeImplicitData();
                    appdata.saveData();
                    context.showMessage(message: testResult.errorMessage!);
                    context.showMessage(message: "Saved Failed".tl);
                  } else {
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                  }
                },
                child: Text("Continue".tl),
              ),
            )
          ],
        ).paddingHorizontal(16),
      ),
    );
  }
}
