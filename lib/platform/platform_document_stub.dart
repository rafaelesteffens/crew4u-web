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
    return const PlatformDocumentResult(
      supported: false,
      message: 'Exportacao indisponivel nesta plataforma.',
    );
  }

  Future<PlatformDocumentResult> saveTextFile({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    return const PlatformDocumentResult(
      supported: false,
      message: 'Download indisponivel nesta plataforma.',
    );
  }
}
