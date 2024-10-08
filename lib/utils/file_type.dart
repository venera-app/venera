import 'dart:typed_data';

import 'package:mime/mime.dart';

class FileType {
  final String ext;
  final String mime;

  const FileType(this.ext, this.mime);
}

FileType detectFileType(List<int> data) {
  var mime = lookupMimeType('no-file', headerBytes: data);
  var ext = mime == null ? '' : extensionFromMime(mime);
  if(ext == 'jpe') {
    ext = 'jpg';
  }
  return FileType(".$ext", mime ?? 'application/octet-stream');
}