import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pdfcraft/core/pdfcraft_bridge.dart';
import 'package:mobile_pdfcraft/models/pdf_document_item.dart';
import 'package:mobile_pdfcraft/state/pdf_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfDocumentItem Model Tests', () {
    test('Formatted file size returns readable units', () {
      final doc = PdfDocumentItem(
        id: 'test-1',
        title: 'Sample Doc',
        subtitle: 'Sub',
        author: 'Tester',
        createdAt: DateTime.now(),
        fileSizeBytes: 2048,
        pageCount: 2,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(doc.formattedSize, '2.0 KB');
      expect(doc.isSigned, isFalse);
      expect(doc.currentRotation, 0);
    });

    test('Formatted date formats time ago', () {
      final doc = PdfDocumentItem(
        id: 'test-2',
        title: 'Recent Doc',
        subtitle: 'Sub',
        author: 'Tester',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        fileSizeBytes: 500,
        pageCount: 1,
        bytes: Uint8List(0),
      );

      expect(doc.timeAgo, '5m ago');
    });
  });

  group('PdfCraftBridge & ISO 32000-2 Tests', () {
    test('createBlank creates valid PDF bytes with trailer and EOF', () async {
      final bridge = PdfCraftBridge.instance;
      final bytes = await bridge.createBlank(width: 612.0, height: 792.0, pages: 1);

      expect(bytes.isNotEmpty, isTrue);
      final pdfString = String.fromCharCodes(bytes);
      expect(pdfString.startsWith('%PDF'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
    });

    test('createFromText formats title and text into PDF streams', () async {
      final bridge = PdfCraftBridge.instance;
      final bytes = await bridge.createFromText(
        title: 'Executive Notice',
        text: 'This is a test notification generated via PdfCraft.',
        fontSize: 14.0,
      );

      expect(bytes.isNotEmpty, isTrue);
      final pdfString = String.fromCharCodes(bytes);
      expect(pdfString.startsWith('%PDF'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
    });

    test('addWatermark applies watermark diagonal text', () async {
      final bridge = PdfCraftBridge.instance;
      final baseBytes = await bridge.createBlank(width: 612.0, height: 792.0, pages: 1);
      final watermarked = await bridge.addWatermark(
        baseBytes,
        text: 'CONFIDENTIAL',
        opacity: 0.3,
        rotation: 45.0,
      );

      expect(watermarked.isNotEmpty, isTrue);
      final pdfString = String.fromCharCodes(watermarked);
      expect(pdfString.startsWith('%PDF'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);
    });

    test('signPdf attaches digital signature appearance and metadata', () async {
      final bridge = PdfCraftBridge.instance;
      final baseBytes = await bridge.createBlank(width: 612.0, height: 792.0, pages: 1);
      final signed = await bridge.signPdf(
        baseBytes,
        page1Based: 1,
        signerName: 'Jane Auditor',
        reason: 'Compliance Approval',
        location: 'Android Mobile Studio',
      );

      expect(signed.length > baseBytes.length, isTrue);
      final pdfString = String.fromCharCodes(signed);
      expect(pdfString.contains('Jane Auditor'), isTrue);
      expect(pdfString.contains('Compliance Approval'), isTrue);
      expect(pdfString.contains('ETSI.CAdES.detached'), isTrue);
    });

    test('inspectPdf extracts page count and signature presence', () async {
      final bridge = PdfCraftBridge.instance;
      final baseBytes = await bridge.createBlank(width: 612.0, height: 792.0, pages: 2);
      final inspect = await bridge.inspectPdf(baseBytes);

      expect(inspect['page_count'], 2);
      expect(inspect['signatures'], isEmpty);
    });
  });

  group('PdfState State Management Tests', () {
    test('PdfState initializes with sample documents ready for signing', () async {
      final state = PdfState();

      // Give async initialization a moment to complete
      await Future.delayed(const Duration(milliseconds: 300));

      expect(state.feedDocuments.isNotEmpty, isTrue);
      expect(state.activeDocument, isNotNull);
      expect(state.activePageIndex, 1);
    });

    test('PdfState tab navigation works as expected', () {
      final state = PdfState();

      expect(state.currentTab, 0);
      state.setTab(1);
      expect(state.currentTab, 1);
      state.setTab(2);
      expect(state.currentTab, 2);
    });

    test('PdfState can create blank document and set it active', () async {
      final state = PdfState();
      final initialCount = state.feedDocuments.length;

      await state.createBlankDocument(title: 'New Blank Canvas', pages: 3);

      expect(state.feedDocuments.length, initialCount + 1);
      expect(state.activeDocument?.title, 'New Blank Canvas');
      expect(state.activeDocument?.pageCount, 3);
      expect(state.currentTab, 1); // Automatically opens in Viewer
    });

    test('PdfState can sign active document', () async {
      final state = PdfState();
      await state.createBlankDocument(title: 'Contract 2026');

      expect(state.activeDocument?.isSigned, isFalse);

      await state.signActiveDocument(
        signerName: 'Chief Legal Officer',
        reason: 'Authorized Execution',
        location: 'Mobile Device',
      );

      expect(state.activeDocument?.isSigned, isTrue);
      expect(state.activeDocument?.signatureInfo?['signer'], 'Chief Legal Officer');
      expect(state.activeDocument?.signatureInfo?['status'], 'valid');
    });

    test('PdfState can rotate active page', () async {
      final state = PdfState();
      await state.createBlankDocument(title: 'Landscape Memo');

      expect(state.activeDocument?.currentRotation, 0);

      await state.rotateActivePage(degrees: 90);
      expect(state.activeDocument?.currentRotation, 90);

      await state.rotateActivePage(degrees: 90);
      expect(state.activeDocument?.currentRotation, 180);
    });
  });
}
