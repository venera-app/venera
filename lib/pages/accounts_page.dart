import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/state_controller.dart';
import 'package:venera/network/cookie_jar.dart';
import 'package:venera/pages/webview.dart';
import 'package:venera/utils/translations.dart';

class AccountsPageLogic extends StateController {
  final _reLogin = <String, bool>{};
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  AccountsPageLogic get logic => StateController.find<AccountsPageLogic>();

  @override
  Widget build(BuildContext context) {
    var body = StateBuilder<AccountsPageLogic>(
      init: AccountsPageLogic(),
      builder: (logic) {
        return CustomScrollView(
          slivers: [
            SliverAppbar(title: Text("Accounts".tl)),
            SliverList(
              delegate: SliverChildListDelegate(
                buildContent(context).toList(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: context.padding.bottom),
            )
          ],
        );
      },
    );

    return Scaffold(
      body: body,
    );
  }

  Iterable<Widget> buildContent(BuildContext context) sync* {
    var sources = ComicSource.all().where((element) => element.account != null);
    if (sources.isEmpty) return;

    for (var element in sources) {
      final bool logged = element.isLogged;
      yield Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          element.name,
          style: const TextStyle(fontSize: 16),
        ),
      );
      if (!logged) {
        yield ListTile(
          title: Text("Log in".tl),
          trailing: const Icon(Icons.arrow_right),
          onTap: () async {
            await context.to(
              () => _LoginPage(
                config: element.account!,
                source: element,
              ),
            );
            element.saveData();
            ComicSource.notifyListeners();
            logic.update();
          },
        );
      }
      if (logged) {
        for (var item in element.account!.infoItems) {
          if (item.builder != null) {
            yield item.builder!(context);
          } else {
            yield ListTile(
              title: Text(item.title.tl),
              subtitle: item.data == null ? null : Text(item.data!()),
              onTap: item.onTap,
            );
          }
        }
        if (element.data["account"] is List) {
          bool loading = logic._reLogin[element.key] == true;
          yield ListTile(
            title: Text("Re-login".tl),
            subtitle: Text("Click if login expired".tl),
            onTap: () async {
              if (element.data["account"] == null) {
                context.showMessage(message: "No data".tl);
                return;
              }
              logic._reLogin[element.key] = true;
              logic.update();
              final List account = element.data["account"];
              var res = await element.account!.login!(account[0], account[1]);
              if (res.error) {
                context.showMessage(message: res.errorMessage!);
              } else {
                context.showMessage(message: "Success".tl);
              }
              logic._reLogin[element.key] = false;
              logic.update();
            },
            trailing: loading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          );
        }
        yield ListTile(
          title: Text("Log out".tl),
          onTap: () {
            element.data["account"] = null;
            element.account?.logout();
            element.saveData();
            ComicSource.notifyListeners();
            logic.update();
          },
          trailing: const Icon(Icons.logout),
        );
      }
      yield const Divider(thickness: 0.6);
    }
  }

  void setClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(
      message: "Copied".tl,
      icon: const Icon(Icons.check),
      context: App.rootContext,
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.config, required this.source});

  final AccountConfig config;

  final ComicSource source;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  String username = "";
  String password = "";
  bool loading = false;

  final Map<String, String> _cookies = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Appbar(
        title: Text(''),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Login".tl, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 32),
              if (widget.config.cookieFields == null)
                TextField(
                  decoration: InputDecoration(
                    labelText: "Username".tl,
                    border: const OutlineInputBorder(),
                  ),
                  enabled: widget.config.login != null,
                  onChanged: (s) {
                    username = s;
                  },
                ).paddingBottom(16),
              if (widget.config.cookieFields == null)
                TextField(
                  decoration: InputDecoration(
                    labelText: "Password".tl,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: widget.config.login != null,
                  onChanged: (s) {
                    password = s;
                  },
                  onSubmitted: (s) => login(),
                ).paddingBottom(16),
              for (var field in widget.config.cookieFields ?? <String>[])
                TextField(
                  decoration: InputDecoration(
                    labelText: field,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: widget.config.validateCookies != null,
                  onChanged: (s) {
                    _cookies[field] = s;
                  },
                ).paddingBottom(16),
              if (widget.config.login == null &&
                  widget.config.cookieFields == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 8),
                    Text("Login with password is disabled".tl),
                  ],
                )
              else
                Button.filled(
                  isLoading: loading,
                  onPressed: login,
                  child: Text("Continue".tl),
                ),
              const SizedBox(height: 24),
              if (widget.config.loginWebsite != null)
                TextButton(
                  onPressed: loginWithWebview,
                  child: Text("Login with webview".tl),
                ),
              const SizedBox(height: 8),
              if (widget.config.registerWebsite != null)
                TextButton(
                  onPressed: () =>
                      launchUrlString(widget.config.registerWebsite!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link),
                      const SizedBox(width: 8),
                      Text("Create Account".tl),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void login() {
    if (widget.config.login != null) {
      if (username.isEmpty || password.isEmpty) {
        showToast(
          message: "Cannot be empty".tl,
          icon: const Icon(Icons.error_outline),
          context: context,
        );
        return;
      }
      setState(() {
        loading = true;
      });
      widget.config.login!(username, password).then((value) {
        if (value.error) {
          context.showMessage(message: value.errorMessage!);
          setState(() {
            loading = false;
          });
        } else {
          if (mounted) {
            context.pop();
          }
        }
      });
    } else if (widget.config.validateCookies != null) {
      setState(() {
        loading = true;
      });
      var cookies =
          widget.config.cookieFields!.map((e) => _cookies[e] ?? '').toList();
      widget.config.validateCookies!(cookies).then((value) {
        if (value) {
          widget.source.data['account'] = 'ok';
          widget.source.saveData();
          context.pop();
        } else {
          context.showMessage(message: "Invalid cookies".tl);
          setState(() {
            loading = false;
          });
        }
      });
    }
  }

  void loginWithWebview() async {
    var url = widget.config.loginWebsite!;
    var title = '';
    bool success = false;

    void validate(InAppWebViewController c) async {
      if (widget.config.checkLoginStatus != null
          && widget.config.checkLoginStatus!(url, title)) {
        var cookies = (await c.getCookies(url)) ?? [];
        SingleInstanceCookieJar.instance?.saveFromResponse(
          Uri.parse(url),
          cookies,
        );
        success = true;
        widget.config.onLoginWithWebviewSuccess?.call();
        App.mainNavigatorKey?.currentContext?.pop();
      }
    }

    await context.to(
      () => AppWebview(
        initialUrl: widget.config.loginWebsite!,
        onNavigation: (u, c) {
          url = u;
          validate(c);
          return false;
        },
        onTitleChange: (t, c) {
          title = t;
          validate(c);
        },
      ),
    );
    if (success) {
      widget.source.data['account'] = 'ok';
      widget.source.saveData();
      context.pop();
    }
  }
}
