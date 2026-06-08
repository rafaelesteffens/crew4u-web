export 'platform_document_stub.dart'
    if (dart.library.html) 'platform_document_web.dart'
    if (dart.library.io) 'platform_document_io.dart';
