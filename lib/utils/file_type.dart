import 'package:mime/mime.dart';

class FileType {
  final String ext;
  final String mime;

  const FileType(this.ext, this.mime);

  static FileType fromExtension(String ext) {
    if(ext.startsWith('.')) {
      ext = ext.substring(1);
    }
    var mime = lookupMimeType('no-file.$ext') ?? 'application/octet-stream';
    // Android doesn't support some mime types
    mime = switch(mime) {
      'text/javascript' => 'application/octet-stream',
      'application/x-cbr' => 'application/octet-stream',
      _ => mime,
    };
    return FileType(".$ext", mime);
  }
}

FileType detectFileType(List<int> data) {
  var mime = lookupMimeType('no-file', headerBytes: data);
  var ext = mime == null ? '' : extensionFromMime(mime);
  if(ext == 'jpe') {
    ext = 'jpg';
  }
  return FileType(".$ext", mime ?? 'application/octet-stream');
}