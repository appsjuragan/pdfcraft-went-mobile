import 'dart:typed_data';
import 'package:intl/intl.dart';

class PdfDocumentItem {
  final String id;
  String title;
  String subtitle;
  String author;
  final DateTime createdAt;
  int fileSizeBytes;
  int pageCount;
  Uint8List bytes;
  Uint8List? previewPng;
  bool isSigned;
  Map<String, dynamic>? signatureInfo;
  bool isWatermarked;
  int currentRotation; // 0, 90, 180, 270
  bool isSample;
  bool isProtected;

  PdfDocumentItem({
    required this.id,
    required this.title,
    this.subtitle = 'Created with PdfCraft Core',
    this.author = 'PdfCraft Mobile User',
    required this.createdAt,
    required this.fileSizeBytes,
    this.pageCount = 1,
    required this.bytes,
    this.previewPng,
    this.isSigned = false,
    this.signatureInfo,
    this.isWatermarked = false,
    this.currentRotation = 0,
    this.isSample = false,
    this.isProtected = false,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedDate {
    return DateFormat('MMM d, yyyy • h:mm a').format(createdAt);
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(createdAt);
    }
  }

  PdfDocumentItem copyWith({
    String? title,
    String? subtitle,
    String? author,
    int? fileSizeBytes,
    int? pageCount,
    Uint8List? bytes,
    Uint8List? previewPng,
    bool? isSigned,
    Map<String, dynamic>? signatureInfo,
    bool? isWatermarked,
    int? currentRotation,
  }) {
    return PdfDocumentItem(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      createdAt: createdAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      bytes: bytes ?? this.bytes,
      previewPng: previewPng ?? this.previewPng,
      isSigned: isSigned ?? this.isSigned,
      signatureInfo: signatureInfo ?? this.signatureInfo,
      isWatermarked: isWatermarked ?? this.isWatermarked,
      currentRotation: currentRotation ?? this.currentRotation,
      isSample: isSample,
    );
  }
}
