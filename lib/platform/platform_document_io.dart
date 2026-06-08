import 'dart:io';

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
    final path = await _writeTempFile(filename, content);
    return PlatformDocumentResult(
      supported: true,
      message: 'Arquivo gerado em $path.',
    );
  }

  Future<PlatformDocumentResult> saveTextFile({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    final path = await _writeTempFile(filename, content);
    return PlatformDocumentResult(
      supported: true,
      message: 'Arquivo gerado em $path.',
    );
  }

  Future<String> _writeTempFile(String filename, String content) async {
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final file = File('${Directory.systemTemp.path}/$safeName');
    await file.writeAsString(content);
    return file.path;
  }
}
