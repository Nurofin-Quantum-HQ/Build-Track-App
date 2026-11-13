// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

Future<void> openDocumentPlatform({
  required String doc,
  required String name,
}) async {
  if (doc.startsWith('data:')) {
    final parts = doc.split(';base64,');
    if (parts.length == 2) {
      final header = parts.first.replaceFirst('data:', '');
      final mime = header.split(';').first;
      final bytes = base64Decode(parts.last);
      final blob = html.Blob([bytes], mime.isNotEmpty ? mime : 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      return;
    }
  }
  html.window.open(doc, '_blank');
}
