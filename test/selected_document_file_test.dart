import 'package:autoclair_app/features/documents/selected_document_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectedDocumentFile', () {
    test('normalise jpeg vers jpg', () {
      expect(SelectedDocumentFile.normalizedExtension('JPEG'), 'jpg');
    });

    test('reconnaît les types MIME autorisés', () {
      expect(
        SelectedDocumentFile.mimeTypeForExtension('pdf'),
        'application/pdf',
      );
      expect(SelectedDocumentFile.mimeTypeForExtension('jpg'), 'image/jpeg');
      expect(SelectedDocumentFile.mimeTypeForExtension('png'), 'image/png');
    });

    test('refuse une extension non autorisée', () {
      expect(SelectedDocumentFile.mimeTypeForExtension('docx'), isNull);
    });

    test('extrait correctement une extension', () {
      expect(SelectedDocumentFile.extensionFromName('devis.final.pdf'), 'pdf');
      expect(SelectedDocumentFile.extensionFromName('sans_extension'), '');
    });
  });
}
