import 'package:flutter/material.dart';
import '../../state/pdf_state.dart';
import '../dialogs/create_dialog.dart';
import '../theme/facebook_theme.dart';
import '../widgets/fb_post_card.dart';

class FeedView extends StatelessWidget {
  final PdfState state;

  const FeedView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: FacebookTheme.primaryColor,
      onRefresh: () async {
        // Quick visual refresh
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        slivers: [
          // 1. Facebook-styled "What's on your mind?" Composer Box
          SliverToBoxAdapter(
            child: _buildComposerCard(context),
          ),

          // 2. Stories / Quick Actions Carousel
          SliverToBoxAdapter(
            child: _buildQuickActionStories(context),
          ),

          // 3. Status Notification Banner (if any)
          if (state.statusMessage != null)
            SliverToBoxAdapter(
              child: _buildStatusBanner(context),
            ),

          // 4. Feed of Documents
          if (state.feedDocuments.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = state.feedDocuments[index];
                    return FbPostCard(
                      document: doc,
                      onTap: () => state.openDocument(doc, tab: 1),
                      onSign: () => state.openDocument(doc, tab: 2),
                      onEdit: () => state.openDocument(doc, tab: 1),
                      onInspect: () => state.openDocument(doc, tab: 3),
                      onShare: () => state.shareOrExportDocument(doc, context),
                      onDelete: () => state.deleteDocument(doc.id),
                    );
                  },
                  childCount: state.feedDocuments.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposerCard(BuildContext context) {
    return Container(
      color: FacebookTheme.cardBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF0D58C4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'PC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showQuickActionSheet(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: FacebookTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'What PDF would you like to craft today?',
                      style: TextStyle(
                        color: FacebookTheme.textSecondary,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: FacebookTheme.dividerColor),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComposerAction(
                icon: Icons.folder_open_rounded,
                iconColor: const Color(0xFF45BD62),
                label: 'Open PDF',
                onTap: () => state.pickAndOpenDocument(),
              ),
              _buildComposerAction(
                icon: Icons.post_add_rounded,
                iconColor: const Color(0xFFF3425F),
                label: 'New Blank',
                onTap: () => CreateDialogs.showCreateBlankDialog(context, state),
              ),
              _buildComposerAction(
                icon: Icons.draw_rounded,
                iconColor: FacebookTheme.primaryColor,
                label: 'Sign PDF',
                onTap: () {
                  if (state.activeDocument != null) {
                    state.setTab(2);
                  } else {
                    _showQuickActionSheet(context);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerAction({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: FacebookTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionStories(BuildContext context) {
    return Container(
      height: 110,
      color: FacebookTheme.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildStoryCard(
            title: 'Open Document',
            subtitle: 'From Device',
            icon: Icons.folder_rounded,
            color: const Color(0xFF45BD62),
            onTap: () => state.pickAndOpenDocument(),
          ),
          _buildStoryCard(
            title: 'Create Blank',
            subtitle: 'Letter / A4',
            icon: Icons.note_add_rounded,
            color: const Color(0xFF1877F2),
            onTap: () => CreateDialogs.showCreateBlankDialog(context, state),
          ),
          _buildStoryCard(
            title: 'Text to PDF',
            subtitle: 'Fast Compile',
            icon: Icons.text_fields_rounded,
            color: const Color(0xFF9360F7),
            onTap: () => CreateDialogs.showCreateTextDialog(context, state),
          ),
          _buildStoryCard(
            title: 'Sign Contract',
            subtitle: 'P-256 Crypto',
            icon: Icons.verified_user_rounded,
            color: const Color(0xFFF3425F),
            onTap: () {
              if (state.activeDocument != null) {
                state.setTab(2);
              } else {
                state.pickAndOpenDocument();
              }
            },
          ),
          _buildStoryCard(
            title: 'Watermark',
            subtitle: 'Overlay Stamp',
            icon: Icons.water_drop_rounded,
            color: const Color(0xFFF7B125),
            onTap: () {
              if (state.activeDocument != null) {
                CreateDialogs.showWatermarkDialog(context, state);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a document first')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FacebookTheme.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FacebookTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: FacebookTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.statusMessage ?? '',
              style: const TextStyle(color: FacebookTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              child: const Icon(Icons.picture_as_pdf_rounded, size: 48, color: FacebookTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              'No PDF Documents Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new blank document, compile text into PDF, or import an existing file from your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FacebookTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => state.pickAndOpenDocument(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Open or Create PDF'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Create & Manage PDFs',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7F3FF),
                    child: Icon(Icons.folder_open_rounded, color: FacebookTheme.primaryColor),
                  ),
                  title: const Text('Open PDF from Storage', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Inspect, edit, or sign an existing PDF'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    state.pickAndOpenDocument();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F8EE),
                    child: Icon(Icons.note_add_rounded, color: Color(0xFF45BD62)),
                  ),
                  title: const Text('Create Blank Document', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start fresh with custom page dimensions'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    CreateDialogs.showCreateBlankDialog(context, state);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.text_fields_rounded, color: Color(0xFF9360F7)),
                  ),
                  title: const Text('Generate PDF from Text', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Convert notes or articles to formatted PDF'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    CreateDialogs.showCreateTextDialog(context, state);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
