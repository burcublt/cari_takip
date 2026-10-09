/// `1536` -> `1,5 KB`, `5242880` -> `5,0 MB`
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${_one(kb)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${_one(mb)} MB';
  return '${_one(mb / 1024)} GB';
}

String _one(double value) => value.toStringAsFixed(1).replaceAll('.', ',');
