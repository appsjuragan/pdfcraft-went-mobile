import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/pdfcraft_bridge.dart';
import '../models/pdf_document_item.dart';

class PdfState extends ChangeNotifier {
  final PdfCraftBridge _bridge = PdfCraftBridge.instance;

  final List<PdfDocumentItem> _feedDocuments = [];
  PdfDocumentItem? _activeDocument;
  int _activePageIndex = 1;
  int _currentTab = 0; // 0: Feed, 1: Viewer/Editor, 2: Sign Studio, 3: Inspect
  bool _isLoading = false;
  String? _statusMessage;

  PdfState() {
    _initializeDefaultDocuments();
  }

  List<PdfDocumentItem> get feedDocuments => List.unmodifiable(_feedDocuments);
  PdfDocumentItem? get activeDocument => _activeDocument;
  int get activePageIndex => _activePageIndex;
  int get currentTab => _currentTab;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  String get engineStatus => _bridge.engineStatus;
  bool get isNativeLoaded => _bridge.isNativeLoaded;

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void setPageIndex(int page) {
    if (_activeDocument != null && page >= 1 && page <= _activeDocument!.pageCount) {
      _activePageIndex = page;
      notifyListeners();
    }
  }

  Future<void> _initializeDefaultDocuments() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Sample Report Document
      final reportBytes = await _bridge.createFromText(
        title: 'PdfCraft Quarterly Mobile Report',
        text: 'EXECUTIVE OVERVIEW\n\n'
            'This document was generated using the core engine of PdfCraft.\n'
            'PdfCraft provides memory-safe PDF creation, non-destructive editing, '
            'and cryptographic digital signing conforming to PAdES B-B specifications.\n\n'
            'KEY HIGHLIGHTS\n'
            '• Fully clean Facebook-like interface targeting Android.\n'
            '• Headless core functions for open, edit, and digital signing.\n'
            '• Zero external login barriers: instant access to all PDF operations.\n'
            '• Direct rendering and vector signature contours.',
        fontSize: 12.0,
      );
      final reportPreview = await _bridge.renderPagePng(reportBytes, page1Based: 1);

      final reportItem = PdfDocumentItem(
        id: 'sample-report-1',
        title: 'Quarterly Executive Brief',
        subtitle: 'Created with PdfCraft Core Engine',
        author: 'PdfCraft Mobile Engine',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        fileSizeBytes: reportBytes.length,
        pageCount: 1,
        bytes: reportBytes,
        previewPng: reportPreview,
        isSample: true,
      );

      // 2. Sample Contract Ready for Signing
      final contractBytes = await _bridge.createFromText(
        title: 'Master Service Agreement #2026-PC',
        text: 'PARTIES AND RECITALS\n\n'
            'This Agreement is entered into by and between storytold PdfCraft and the User.\n'
            'WHEREAS, PdfCraft delivers fast, reliable, privacy-focused PDF processing.\n\n'
            'TERMS & CONDITIONS\n'
            '1. Scope of Work: Instant PDF generation, watermark application, and page rotation.\n'
            '2. Cryptographic Security: P-256 Elliptic Curve signatures with ETSI.CAdES.detached.\n'
            '3. Execution: Authorized signatures below validate acceptance in full.\n\n'
            'SIGNATURE SECTION:\n'
            'Please tap "Sign" to place your digital signature on this contract.',
        fontSize: 12.0,
      );
      final contractPreview = await _bridge.renderPagePng(contractBytes, page1Based: 1);

      final contractItem = PdfDocumentItem(
        id: 'sample-contract-2',
        title: 'Master Service Agreement 2026',
        subtitle: 'Pending Cryptographic Signature',
        author: 'Legal Operations',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        fileSizeBytes: contractBytes.length,
        pageCount: 1,
        bytes: contractBytes,
        previewPng: contractPreview,
        isSample: true,
      );

      _feedDocuments.addAll([reportItem, contractItem]);
      _activeDocument = contractItem;
    } catch (e) {
      debugPrint('Error initializing default documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void openDocument(PdfDocumentItem item, {int tab = 1}) {
    _activeDocument = item;
    _activePageIndex = 1;
    _currentTab = tab;
    notifyListeners();
  }

  Future<void> pickAndOpenDocument() async {
    try {
      _statusMessage = 'Selecting PDF file...';
      _isLoading = true;
      notifyListeners();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? fileBytes = file.bytes;

        if (fileBytes == null && file.path != null) {
          final f = File(file.path!);
          if (await f.exists()) {
            fileBytes = await f.readAsBytes();
          }
        }

        if (fileBytes == null && file.readStream != null) {
          final builder = BytesBuilder();
          await for (final chunk in file.readStream!) {
            builder.add(chunk);
          }
          fileBytes = builder.toBytes();
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          final inspect = await _bridge.inspectPdf(fileBytes);
          final pageCount = inspect['page_count'] as int? ?? 1;
          final title = (inspect['title'] as String?)?.isNotEmpty == true
              ? inspect['title'] as String
              : file.name.replaceAll('.pdf', '');

          final preview = await _bridge.renderPagePng(fileBytes, page1Based: 1);

          final docItem = PdfDocumentItem(
            id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            subtitle: 'Imported from device storage',
            author: inspect['author'] as String? ?? 'User Document',
            createdAt: DateTime.now(),
            fileSizeBytes: fileBytes.length,
            pageCount: pageCount,
            bytes: fileBytes,
            previewPng: preview,
            isSigned: (inspect['signatures'] as List?)?.isNotEmpty == true,
            signatureInfo: (inspect['signatures'] as List?)?.isNotEmpty == true
                ? Map<String, dynamic>.from(inspect['signatures'][0])
                : null,
          );

          _feedDocuments.insert(0, docItem);
          _activeDocument = docItem;
          _activePageIndex = 1;
          _currentTab = 1; // Open in Viewer
          _statusMessage = 'Opened "${docItem.title}"';
        } else {
          _statusMessage = 'Could not read data from "${file.name}"';
        }
      } else {
        _statusMessage = 'File picker closed';
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      _statusMessage = 'Failed to open PDF: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createBlankDocument({double width = 612.0, double height = 792.0, int pages = 1, String title = 'Blank Document'}) async {
    _isLoading = true;
    _statusMessage = 'Creating blank PDF with PdfCraft...';
    notifyListeners();

    try {
      final bytes = await _bridge.createBlank(width: width, height: height, pages: pages);
      final preview = await _bridge.renderPagePng(bytes, page1Based: 1);

      final docItem = PdfDocumentItem(
        id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        subtitle: '$pages page blank document (US Letter)',
        author: 'PdfCraft Core',
        createdAt: DateTime.now(),
        fileSizeBytes: bytes.length,
        pageCount: pages,
        bytes: bytes,
        previewPng: preview,
      );

      _feedDocuments.insert(0, docItem);
      _activeDocument = docItem;
      _activePageIndex = 1;
      _currentTab = 1;
      _statusMessage = 'Created "$title" successfully';
    } catch (e) {
      _statusMessage = 'Failed to create document: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTextDocument({required String title, required String text, double fontSize = 12.0}) async {
    _isLoading = true;
    _statusMessage = 'Formatting and creating PDF with PdfCraft...';
    notifyListeners();

    try {
      final bytes = await _bridge.createFromText(title: title, text: text, fontSize: fontSize);
      final preview = await _bridge.renderPagePng(bytes, page1Based: 1);

      final docItem = PdfDocumentItem(
        id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        subtitle: 'Created from text (${text.split("\n").length} paragraphs)',
        author: 'PdfCraft Core',
        createdAt: DateTime.now(),
        fileSizeBytes: bytes.length,
        pageCount: 1,
        bytes: bytes,
        previewPng: preview,
      );

      _feedDocuments.insert(0, docItem);
      _activeDocument = docItem;
      _activePageIndex = 1;
      _currentTab = 1;
      _statusMessage = 'Created "$title" successfully';
    } catch (e) {
      _statusMessage = 'Failed to create document: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWatermarkToActive({required String text, double opacity = 0.3, double rotation = 45.0}) async {
    if (_activeDocument == null) return;

    _isLoading = true;
    _statusMessage = 'Applying watermark with PdfCraft Core...';
    notifyListeners();

    try {
      final newBytes = await _bridge.addWatermark(
        _activeDocument!.bytes,
        text: text,
        opacity: opacity,
        rotation: rotation,
      );
      final newPreview = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);

      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = newPreview;
      _activeDocument!.isWatermarked = true;
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Watermark "$text" applied successfully';
    } catch (e) {
      _statusMessage = 'Watermark failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rotateActivePage({int degrees = 90}) async {
    if (_activeDocument == null) return;

    _isLoading = true;
    _statusMessage = 'Rotating page with PdfCraft Core...';
    notifyListeners();

    try {
      final newBytes = await _bridge.rotatePage(
        _activeDocument!.bytes,
        page1Based: _activePageIndex,
        degrees: degrees,
      );
      final newPreview = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);

      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = newPreview;
      _activeDocument!.currentRotation = (_activeDocument!.currentRotation + degrees) % 360;
      _statusMessage = 'Page $_activePageIndex rotated by $degrees°';
    } catch (e) {
      _statusMessage = 'Rotation failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signActiveDocument({
    required String signerName,
    String? reason,
    String? location,
    List<List<Offset>>? strokes,
    Rect? placementRect,
  }) async {
    if (_activeDocument == null) return;

    _isLoading = true;
    _statusMessage = 'Generating P-256 certificate & signing with PdfCraft...';
    notifyListeners();

    try {
      final signedBytes = await _bridge.signPdf(
        _activeDocument!.bytes,
        page1Based: _activePageIndex,
        rect: placementRect ?? const Rect.fromLTWH(50, 50, 220, 80),
        signerName: signerName,
        reason: reason ?? 'I accept and approve this document',
        location: location ?? 'Mobile Android Device',
        strokes: strokes,
      );

      final newPreview = await _bridge.renderPagePng(signedBytes, page1Based: _activePageIndex);

      _activeDocument!.bytes = signedBytes;
      _activeDocument!.previewPng = newPreview;
      _activeDocument!.isSigned = true;
      _activeDocument!.fileSizeBytes = signedBytes.length;
      _activeDocument!.signatureInfo = {
        'field': 'Signature1',
        'signed': true,
        'signer': signerName,
        'reason': reason ?? 'I accept and approve this document',
        'location': location ?? 'Mobile Android Device',
        'date': DateTime.now().toIso8601String(),
        'status': 'valid',
        'algorithm': 'P-256 ECDSA + SHA-256 (ETSI.CAdES.detached)',
      };

      _statusMessage = 'Document digitally signed by $signerName';
      _currentTab = 1; // Return to viewer to see signed PDF
    } catch (e) {
      _statusMessage = 'Signing failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---- WYSIWYG editing ----

  Future<void> addTextToActive({
    required String text,
    double x = 72,
    double y = 72,
    double width = 260,
    String font = 'helvetica',
    double fontSize = 14,
    bool bold = false,
    bool italic = false,
    Color color = const Color(0xFF000000),
    String align = 'left',
  }) async {
    if (_activeDocument == null) return;
    _isLoading = true;
    _statusMessage = 'Adding text...';
    notifyListeners();
    try {
      final newBytes = await _bridge.addText(
        _activeDocument!.bytes,
        page1Based: _activePageIndex,
        x: x,
        y: y,
        width: width,
        text: text,
        font: font,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        color: color,
        align: align,
      );
      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Text added';
    } catch (e) {
      _statusMessage = 'Add text failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addImageToActive({required Uint8List imageBytes, double? left, double? bottom, double? right, double? top}) async {
    if (_activeDocument == null) return;
    _isLoading = true;
    _statusMessage = 'Adding image...';
    notifyListeners();
    try {
      final newBytes = await _bridge.addImage(
        _activeDocument!.bytes,
        page1Based: _activePageIndex,
        imageBytes: imageBytes,
        left: left,
        bottom: bottom,
        right: right,
        top: top,
      );
      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Image added';
    } catch (e) {
      _statusMessage = 'Add image failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> listActiveContent() async {
    if (_activeDocument == null) return [];
    try {
      return await _bridge.listContent(_activeDocument!.bytes);
    } catch (e) {
      debugPrint('listContent failed: $e');
      return [];
    }
  }

  Future<void> updateActiveContent({
    required int page,
    required int index,
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    String? font,
    double? fontSize,
    bool? bold,
    bool? italic,
    Color? color,
    String? align,
  }) async {
    if (_activeDocument == null) return;
    _isLoading = true;
    _statusMessage = 'Updating item...';
    notifyListeners();
    try {
      final newBytes = await _bridge.updateContent(
        _activeDocument!.bytes,
        page1Based: page,
        index: index,
        text: text,
        x: x,
        y: y,
        width: width,
        height: height,
        font: font,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        color: color,
        align: align,
      );
      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Item updated';
    } catch (e) {
      _statusMessage = 'Update failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteActiveContent({required int page, required int index}) async {
    if (_activeDocument == null) return;
    _isLoading = true;
    _statusMessage = 'Deleting item...';
    notifyListeners();
    try {
      final newBytes = await _bridge.deleteContent(_activeDocument!.bytes, page1Based: page, index: index);
      _activeDocument!.bytes = newBytes;
      _activeDocument!.previewPng = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Item deleted';
    } catch (e) {
      _statusMessage = 'Delete failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> protectActive({
    String? openPassword,
    String? ownerPassword,
    int printingLevel = 2,
    int changesLevel = 0,
    bool allowCopy = true,
  }) async {
    if (_activeDocument == null) return;
    if (openPassword == null && ownerPassword == null) return;
    _isLoading = true;
    _statusMessage = 'Encrypting with AES-256...';
    notifyListeners();
    try {
      final newBytes = await _bridge.protect(
        _activeDocument!.bytes,
        openPassword: openPassword,
        ownerPassword: ownerPassword,
        printingLevel: printingLevel,
        changesLevel: changesLevel,
        allowCopy: allowCopy,
      );
      // Keep the pre-protect preview: encrypted bytes can't render without the password.
      _activeDocument!.bytes = newBytes;
      _activeDocument!.isProtected = true;
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Password protection applied';
    } catch (e) {
      _statusMessage = 'Protection failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> unprotectActive({String? password}) async {
    if (_activeDocument == null || !_activeDocument!.isProtected) return;
    _isLoading = true;
    _statusMessage = 'Removing protection...';
    notifyListeners();
    try {
      final newBytes = await _bridge.unprotect(_activeDocument!.bytes, password: password);
      _activeDocument!.bytes = newBytes;
      _activeDocument!.isProtected = false;
      _activeDocument!.previewPng = await _bridge.renderPagePng(newBytes, page1Based: _activePageIndex);
      _activeDocument!.fileSizeBytes = newBytes.length;
      _statusMessage = 'Protection removed';
    } catch (e) {
      _statusMessage = 'Remove protection failed (wrong password?): $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> shareOrExportDocument(PdfDocumentItem item, BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = item.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final file = File('${tempDir.path}/$sanitizedTitle.pdf');
      await file.writeAsBytes(item.bytes);

      await Share.shareXFiles(
        [XFile(file.path, name: '$sanitizedTitle.pdf')],
        text: '${item.title} - Exported via PdfCraft Mobile',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  void deleteDocument(String id) {
    _feedDocuments.removeWhere((d) => d.id == id);
    if (_activeDocument?.id == id) {
      _activeDocument = _feedDocuments.isNotEmpty ? _feedDocuments.first : null;
      _activePageIndex = 1;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> inspectActiveDocument() async {
    if (_activeDocument == null) return {};
    try {
      final info = await _bridge.inspectPdf(_activeDocument!.bytes);
      return info;
    } catch (e) {
      debugPrint('Error inspecting document: $e');
      return {
        'error': e.toString(),
        'page_count': _activeDocument?.pageCount,
        'title': _activeDocument?.title,
      };
    }
  }
}
