//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_qjs/flutter_qjs_plugin.h>
#include <screen_retriever/screen_retriever_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterQjsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterQjsPlugin"));
  ScreenRetrieverPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverPlugin"));
  Sqlite3FlutterLibsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("Sqlite3FlutterLibsPlugin"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}
