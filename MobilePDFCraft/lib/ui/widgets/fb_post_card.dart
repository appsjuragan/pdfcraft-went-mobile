import 'package:flutter/material.dart';
import '../../models/pdf_document_item.dart';
import '../theme/facebook_theme.dart';

class FbPostCard extends StatelessWidget {
  final PdfDocumentItem item;
  final VoidCallback onOpen;
  final VoidCallback onSign;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onInspect;
  final VoidCallback? onEdit;

  FbPostCard({
    super.key,
    PdfDocumentItem? item,
    PdfDocumentItem? document,
    VoidCallback? onOpen,
    VoidCallback? onTap,
    required this.onSign,
    required this.onShare,
    required this.onDelete,
    this.onInspect,
    this.onEdit,
  })  : item = (item ?? document)!,
        onOpen = (onOpen ?? onTap ?? onEdit ?? () {});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: const BoxDecoration(
        color: FacebookTheme.fbCardSurface,
        border: Border.symmetric(
          horizontal: BorderSide(color: FacebookTheme.fbCardBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Post Header: Avatar, Name, Timestamp, Privacy Icon, More Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: FacebookTheme.fbBlue,
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FacebookTheme.fbTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.author,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: FacebookTheme.fbTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: FacebookTheme.fbTextSubdued,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.timeAgo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FacebookTheme.fbTextSubdued,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.public,
                            size: 13,
                            color: FacebookTheme.fbTextSubdued,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Overflow Menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: FacebookTheme.fbTextSecondary,
                  ),
                  onSelected: (val) {
                    if (val == 'share') onShare();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Share / Export'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: FacebookTheme.fbRed),
                          SizedBox(width: 8),
                          Text('Remove from feed', style: TextStyle(color: FacebookTheme.fbRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subtitle / Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              item.subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: FacebookTheme.fbTextPrimary,
                height: 1.35,
              ),
            ),
          ),

          // Badges Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (item.isSigned)
                  _buildStatusChip(
                    label: 'Cryptographically Signed',
                    icon: Icons.verified,
                    bgColor: const Color(0xFFE7F3FF),
                    textColor: FacebookTheme.fbBlueDark,
                  ),
                if (item.isWatermarked)
                  _buildStatusChip(
                    label: 'Watermark Applied',
                    icon: Icons.layers,
                    bgColor: const Color(0xFFFEF3D6),
                    textColor: const Color(0xFF8F5B00),
                  ),
                if (item.currentRotation != 0)
                  _buildStatusChip(
                    label: 'Rotated ${item.currentRotation}°',
                    icon: Icons.rotate_right,
                    bgColor: const Color(0xFFE4E6EB),
                    textColor: FacebookTheme.fbTextPrimary,
                  ),
                _buildStatusChip(
                  label: '${item.pageCount} ${item.pageCount == 1 ? "Page" : "Pages"}',
                  icon: Icons.description_outlined,
                  bgColor: const Color(0xFFF0F2F5),
                  textColor: FacebookTheme.fbTextSecondary,
                ),
                _buildStatusChip(
                  label: item.formattedSize,
                  icon: Icons.storage_outlined,
                  bgColor: const Color(0xFFF0F2F5),
                  textColor: FacebookTheme.fbTextSecondary,
                ),
              ],
            ),
          ),

          // Document Thumbnail Preview Box
          GestureDetector(
            onTap: onOpen,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FacebookTheme.fbCardBorder, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: item.previewPng != null
                    ? Image.memory(
                        item.previewPng!,
                        fit: BoxFit.contain,
                      )
                    : const Center(
                        child: Icon(
                          Icons.picture_as_pdf,
                          size: 64,
                          color: FacebookTheme.fbBlue,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          const Divider(height: 1),

          // Facebook Action Row: [Open & Edit] [Sign] [Share]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit_note,
                    label: 'Open & Edit',
                    onTap: onOpen,
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.draw_outlined,
                    label: item.isSigned ? 'Re-sign' : 'Sign PDF',
                    color: item.isSigned ? FacebookTheme.fbTextSecondary : FacebookTheme.fbBlue,
                    onTap: onSign,
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final effectiveColor = color ?? FacebookTheme.fbTextSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
