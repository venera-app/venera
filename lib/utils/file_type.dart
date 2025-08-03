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

final _resolver = MimeTypeResolver()
  // zip
  ..addMagicNumber([0x50, 0x4B], 'application/zip')
  // 7z
  ..addMagicNumber([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C], 'application/x-7z-compressed')
  // rar
  ..addMagicNumber([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07], 'application/vnd.rar')
  // avif
  ..addMagicNumber([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x61, 0x76, 0x69, 0x66], 'image/avif')
;

FileType detectFileType(List<int> data) {
  var mime = _resolver.lookup('no-file', headerBytes: data);
  var ext = mime == null ? '' : extensionFromMime(mime);
  if(ext == 'jpe') {
    ext = 'jpg';
  }
  return FileType(".$ext", mime ?? 'application/octet-stream');
}