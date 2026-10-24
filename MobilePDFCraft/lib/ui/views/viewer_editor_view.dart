import 'package:flutter/material.dart';
import '../../state/pdf_state.dart';
import '../dialogs/create_dialog.dart';
import '../theme/facebook_theme.dart';

class ViewerEditorView extends StatelessWidget {
  final PdfState state;

  const ViewerEditorView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final doc = state.activeDocument;

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
                child: const Icon(Icons.picture_as_pdf_outlined, size: 48, color: FacebookTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Document Selected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a document from your feed, open an existing PDF file, or create a new blank document.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FacebookTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => state.setTab(0),
                icon: const Icon(Icons.feed_outlined),
                label: const Text('Go to Documents Feed'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 1. Document Info & Page Bar (Facebook Header style)
        Container(
          color: FacebookTheme.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: FacebookTheme.textPrimary),
                tooltip: 'Back to Feed',
                onPressed: () => state.setTab(0),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${doc.formattedSize} • Page ${state.activePageIndex} of ${doc.pageCount}${doc.isSigned ? " • Digitally Signed" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: doc.isSigned ? const Color(0xFF45BD62) : FacebookTheme.textSecondary,
                        fontWeight: doc.isSigned ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: FacebookTheme.primaryColor),
                tooltip: 'Share / Export',
                onPressed: () => state.shareOrExportDocument(doc, context),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: FacebookTheme.dividerColor),

        // 2. Interactive Canvas showing rendered PDF from PdfCraft engine
        Expanded(
          child: Container(
            color: const Color(0xFFE4E6EB),
            alignment: Alignment.center,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: doc.previewPng != null
                            ? Image.memory(
                                doc.previewPng!,
                                key: ValueKey('${doc.id}_${doc.previewPng.hashCode}_${state.activePageIndex}'),
                                fit: BoxFit.contain,
                              )
                            : Container(
                                width: 320,
                                height: 440,
                                color: Colors.white,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(strokeWidth: 2),
                                      SizedBox(height: 12),
                                      Text(
                                        'Rendering with PdfCraft Engine...',
                                        style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // Multi-page navigation floating badge
                if (doc.pageCount > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: state.activePageIndex > 1
                                  ? () => state.setPageIndex(state.activePageIndex - 1)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${state.activePageIndex} / ${doc.pageCount}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: state.activePageIndex < doc.pageCount
                                  ? () => state.setPageIndex(state.activePageIndex + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. Edit & Sign Action Bar (Facebook-styled bottom card)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FacebookTheme.cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.water_drop_outlined,
                  label: 'Watermark',
                  color: const Color(0xFFF7B125),
                  onTap: () => CreateDialogs.showWatermarkDialog(context, state),
                ),
                _buildActionButton(
                  icon: Icons.rotate_right_rounded,
                  label: 'Rotate',
                  color: const Color(0xFF1877F2),
                  onTap: () => CreateDialogs.showRotateDialog(context, state),
                ),
                _buildActionButton(
                  icon: Icons.draw_rounded,
                  label: 'Sign PDF',
                  color: const Color(0xFF45BD62),
                  highlight: !doc.isSigned,
                  onTap: () => state.setTab(2),
                ),
                _buildActionButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Inspect',
                  color: const Color(0xFF9360F7),
                  onTap: () => state.setTab(3),
                ),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: FacebookTheme.textSecondary,
                  onTap: () => state.shareOrExportDocument(doc, context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: highlight
            ? BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? color : FacebookTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
