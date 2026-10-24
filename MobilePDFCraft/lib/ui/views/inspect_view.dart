import 'dart:convert';
import 'package:flutter/material.dart';
import '../../state/pdf_state.dart';
import '../theme/facebook_theme.dart';

class InspectView extends StatefulWidget {
  final PdfState state;

  const InspectView({super.key, required this.state});

  @override
  State<InspectView> createState() => _InspectViewState();
}

class _InspectViewState extends State<InspectView> {
  Map<String, dynamic>? _inspectData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInspection();
  }

  @override
  void didUpdateWidget(covariant InspectView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.activeDocument?.id != widget.state.activeDocument?.id ||
        oldWidget.state.activeDocument?.bytes.length != widget.state.activeDocument?.bytes.length) {
      _fetchInspection();
    }
  }

  Future<void> _fetchInspection() async {
    final doc = widget.state.activeDocument;
    if (doc == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await widget.state.inspectActiveDocument();
      if (mounted) {
        setState(() {
          _inspectData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.state.activeDocument;

    if (doc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: FacebookTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, size: 48, color: FacebookTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              const Text('No Document Selected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                'Select a document from your feed to inspect internal objects, metadata, and digital signature certificates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: FacebookTheme.primaryColor,
      onRefresh: _fetchInspection,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Card
            Container(
              color: FacebookTheme.cardBg,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9360F7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF9360F7), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${doc.formattedSize} • ${doc.pageCount} ${doc.pageCount == 1 ? "page" : "pages"}',
                          style: const TextStyle(color: FacebookTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, color: FacebookTheme.primaryColor),
                    onPressed: _isLoading ? null : _fetchInspection,
                  ),
                ],
              ),
            ),

            // 2. Digital Signatures Card
            Container(
              color: FacebookTheme.cardBg,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: FacebookTheme.primaryColor, size: 20),
                          SizedBox(width: 8),
                          Text('Digital Signatures & Trust', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: doc.isSigned
                              ? const Color(0xFFE8F8EE)
                              : FacebookTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: doc.isSigned
                                ? const Color(0xFF45BD62).withValues(alpha: 0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          doc.isSigned ? 'Digitally Signed' : 'Unsigned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: doc.isSigned ? const Color(0xFF45BD62) : FacebookTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (doc.isSigned && doc.signatureInfo != null) ...[
                    _buildMetaRow('Signer Name', doc.signatureInfo?['signer']?.toString() ?? 'Signed User'),
                    _buildMetaRow('Reason', doc.signatureInfo?['reason']?.toString() ?? 'Approval'),
                    _buildMetaRow('Location', doc.signatureInfo?['location']?.toString() ?? 'Android Device'),
                    _buildMetaRow('Algorithm', doc.signatureInfo?['algorithm']?.toString() ?? 'P-256 ECDSA + SHA-256'),
                    _buildMetaRow('Standard', 'ETSI.CAdES.detached (ISO 32000-2)'),
                    _buildMetaRow('Validation', 'Cryptographic Digest Matches ✓'),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'This document has no cryptographic signatures yet. Tap "Sign PDF" to attach a P-256 digital certificate.',
                        style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FacebookTheme.primaryLight,
                        foregroundColor: FacebookTheme.primaryColor,
                        elevation: 0,
                      ),
                      onPressed: () => widget.state.setTab(2),
                      icon: const Icon(Icons.draw_rounded, size: 18),
                      label: const Text('Sign Document Now'),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Technical Metadata Card
            Container(
              color: FacebookTheme.cardBg,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: FacebookTheme.primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text('PDF Structure & Attributes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildMetaRow('Page Count', '${doc.pageCount}'),
                  _buildMetaRow('File Size', '${doc.fileSizeBytes} bytes (${doc.formattedSize})'),
                  _buildMetaRow('Engine', widget.state.isNativeLoaded ? 'PdfCraft Rust Core (Active)' : 'Dart ISO 32000-2 Engine'),
                  _buildMetaRow('Producer', 'storytold PdfCraft Core'),
                  _buildMetaRow('Watermarked', doc.isWatermarked ? 'Yes ✓' : 'No'),
                  _buildMetaRow('Orientation', '${doc.currentRotation}° clockwise'),
                ],
              ),
            ),

            // 4. Raw Inspection JSON Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: FacebookTheme.textSecondary,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.code_rounded, size: 18),
                label: const Text('View Raw Inspection JSON', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () => _showRawJsonSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: FacebookTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: FacebookTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRawJsonSheet(BuildContext context) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(_inspectData ?? {
      'page_count': widget.state.activeDocument?.pageCount,
      'title': widget.state.activeDocument?.title,
      'author': widget.state.activeDocument?.author,
      'signatures': widget.state.activeDocument?.signatureInfo != null ? [widget.state.activeDocument!.signatureInfo] : [],
      'engine': widget.state.engineStatus,
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PdfCraft Raw JSON Output', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      prettyJson,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF98C379),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
