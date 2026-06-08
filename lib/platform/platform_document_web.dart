// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class PlatformDocumentResult {
  final bool supported;
  final String message;

  const PlatformDocumentResult({
    required this.supported,
    required this.message,
  });
}

class PlatformDocumentService {
  const PlatformDocumentService();

  Future<PlatformDocumentResult> openPrintableHtml({
    required String filename,
    required String content,
  }) async {
    final blob = html.Blob([content], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');

    return const PlatformDocumentResult(
      supported: true,
      message: 'Documento aberto em uma nova aba.',
    );
  }

  Future<PlatformDocumentResult> saveTextFile({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    final blob = html.Blob([content], '$mimeType;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);

    return const PlatformDocumentResult(
      supported: true,
      message: 'Arquivo baixado.',
    );
  }
}
