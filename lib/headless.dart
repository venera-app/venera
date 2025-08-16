import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/comic_source_page.dart';
import 'package:venera/init.dart';
import 'package:venera/logic/follow_updates.dart';
import 'package:venera/foundation/appdata.dart';

void cliPrint(Map<String, dynamic> data) {
  print('[CLI PRINT] ${jsonEncode(data)}');
}

Future<void> runHeadlessMode(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.contains('--ignore-disheadless-log')) {
    Log.isMuted = true;
  }
  if(Platform.isLinux || Platform.isMacOS){
    Directory.current = Platform.environment['HOME']!;
  }
  // The first arg is '--headless', so we look at the next ones.
  var commandIndex = args.indexOf('--headless') + 1;
  if (commandIndex >= args.length) {
    cliPrint({'status': 'error', 'message': 'No command provided for headless mode.'});
    exit(1);
  }

  // Need to initialize the app for some features to work
  await init();

  var command = args[commandIndex];
  var subCommand = (commandIndex + 1 < args.length) ? args[commandIndex + 1] : null;

  switch (command) {
    case 'webdav':
      if (subCommand == 'up') {
        cliPrint({'status': 'running', 'message': 'Uploading WebDAV data...'});
        await DataSync().uploadData();
        cliPrint({'status': 'success', 'message': 'Upload complete.'});
      } else if (subCommand == 'down') {
        cliPrint({'status': 'running', 'message': 'Downloading WebDAV data...'});
        await DataSync().downloadData();
        cliPrint({'status': 'success', 'message': 'Download complete.'});
      } else {
        cliPrint({'status': 'error', 'message': 'Invalid webdav command. Use "up" or "down".'});
        exit(1);
      }
      break;
    case 'updatescript':
      if (subCommand == 'all') {
        cliPrint({'status': 'running', 'message': 'Checking for comic source script updates...'});
        await ComicSourcePage.checkComicSourceUpdate();
        var updates = ComicSourceManager().availableUpdates;
        if (updates.isEmpty) {
          cliPrint({'status': 'success', 'message': 'No updates found.'});
        } else {
          cliPrint({'status': 'running', 'message': 'Updating all comic source scripts...'});
          for (var key in updates.keys) {
            var source = ComicSource.find(key);
            if (source != null) {
              cliPrint({'status': 'running', 'message': 'Updating ${source.name}...'});
              await ComicSourcePage.update(source, false);
            }
          }
          cliPrint({'status': 'success', 'message': 'All scripts updated.'});
        }
      } else {
        cliPrint({'status': 'error', 'message': 'Invalid updatescript command. Use "all".'});
        exit(1);
      }
      break;
    case 'updatesubscribe':
      cliPrint({'status': 'running', 'message': 'Updating subscribed comics...'});
      var folder = appdata.settings["followUpdatesFolder"];
      if (folder == null) {
        cliPrint({'status': 'error', 'message': 'Follow updates folder is not configured.'});
        exit(1);
      }
      int total = 0;
      int updated = 0;
      int errors = 0;
      await for (var progress in updateFolder(folder, true)) {
        total = progress.total;
        updated = progress.updated;
        errors = progress.errors;
        Map<String, dynamic> data = {
          'current': progress.current,
          'total': progress.total,
        };
        if (progress.comic != null) {
          data['comic'] = {
            'id': progress.comic!.id,
            'name': progress.comic!.name,
            'coverUrl': progress.comic!.coverPath,
            'author': progress.comic!.author,
            'type': progress.comic!.type.sourceKey,
            'updateTime': progress.comic!.updateTime,
            'tags': progress.comic!.tags,
          };
        }
        var message = 'Progress';
        if (progress.errorMessage != null) {
          message = 'ProgressError';
          data['error'] = progress.errorMessage;
        }
        cliPrint({
          'status': 'running',
          'message': message,
          'data': data,
        });
      }
      cliPrint({
        'status': 'running',
        'message': 'Update check complete.',
        'data': {
          'total': total,
          'updated': updated,
          'errors': errors,
        }
      });
      await Future.delayed(const Duration(milliseconds: 500));
      var json = await getUpdatedComicsAsJson(folder);
      cliPrint({
        'status': errors > 0 ? 'error' : 'success',
        'message': 'Updated comics list.',
        'data': jsonDecode(json),
      });
      break;
    default:
      cliPrint({'status': 'error', 'message': 'Unknown command: $command'});
      exit(1);
  }

  // Exit after command execution
  exit(0);
}
