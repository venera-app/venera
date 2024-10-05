import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/utils/translations.dart';

/// Open a dialog to create a new favorite folder.
Future<void> newFolder() async {
  return showDialog(context: App.rootContext, builder: (context) {
    var controller = TextEditingController();
    var folders = LocalFavoritesManager().folderNames;
    String? error;

    return StatefulBuilder(builder: (context, setState) {
      return ContentDialog(
        title: "New Folder".tl,
        content: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Folder Name".tl,
                errorText: error,
              ),
              onChanged: (s) {
                if(error != null) {
                  setState(() {
                    error = null;
                  });
                }
              },
            )
          ],
        ).paddingHorizontal(16),
        actions: [
          FilledButton(
            onPressed: () {
              if(controller.text.isEmpty) {
                setState(() {
                  error = "Folder name cannot be empty".tl;
                });
              } else if(controller.text.length > 50) {
                setState(() {
                  error = "Folder name is too long".tl;
                });
              } else if(folders.contains(controller.text)) {
                setState(() {
                  error = "Folder already exists".tl;
                });
              } else {
                LocalFavoritesManager().createFolder(controller.text);
                context.pop();
              }
            },
            child: Text("Create".tl),
          ),
        ],
      );
    });
  });
}