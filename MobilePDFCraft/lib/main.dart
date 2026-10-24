import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/pdf_state.dart';
import 'ui/dialogs/create_dialog.dart';
import 'ui/theme/facebook_theme.dart';
import 'ui/views/feed_view.dart';
import 'ui/views/inspect_view.dart';
import 'ui/views/sign_view.dart';
import 'ui/views/viewer_editor_view.dart';
import 'ui/widgets/fb_app_bar.dart';
import 'ui/widgets/fb_tab_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MobilePdfCraftApp());
}

class MobilePdfCraftApp extends StatefulWidget {
  const MobilePdfCraftApp({super.key});

  @override
  State<MobilePdfCraftApp> createState() => _MobilePdfCraftAppState();
}

class _MobilePdfCraftAppState extends State<MobilePdfCraftApp> {
  late final PdfState _pdfState;

  @override
  void initState() {
    super.initState();
    _pdfState = PdfState();
  }

  @override
  void dispose() {
    _pdfState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PdfCraft Mobile',
      debugShowCheckedModeBanner: false,
      theme: FacebookTheme.themeData,
      home: PdfCraftHomeScreen(state: _pdfState),
    );
  }
}

class PdfCraftHomeScreen extends StatelessWidget {
  final PdfState state;

  const PdfCraftHomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final unsignedCount = state.feedDocuments.where((d) => !d.isSigned).length;

        return Scaffold(
          backgroundColor: FacebookTheme.scaffoldBg,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Facebook-styled Top Header Bar
                FbAppBar(
                  engineStatus: state.engineStatus,
                  isNative: state.isNativeLoaded,
                  onSearchTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Search in ${state.feedDocuments.length} PDF documents'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  onAddTap: () => CreateDialogs.showCreateBlankDialog(context, state),
                ),

                // 2. Facebook-styled Icon Tab Navigation Bar
                FbTabBar(
                  selectedIndex: state.currentTab,
                  onTabSelected: (index) => state.setTab(index),
                  signBadgeCount: unsignedCount,
                ),

                // 3. Tab Views (Preserved with IndexedStack)
                Expanded(
                  child: IndexedStack(
                    index: state.currentTab,
                    children: [
                      FeedView(state: state),
                      ViewerEditorView(state: state),
                      SignView(state: state),
                      InspectView(state: state),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Floating Action Button on Feed tab
          floatingActionButton: state.currentTab == 0
              ? FloatingActionButton.extended(
                  backgroundColor: FacebookTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Craft PDF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCreationBottomSheet(context),
                )
              : null,
        );
      },
    );
  }

  void _showCreationBottomSheet(BuildContext context) {
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
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F8EE),
                    child: Icon(Icons.folder_open_rounded, color: Color(0xFF45BD62)),
                  ),
                  title: const Text('Open PDF from Storage', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick any PDF from your device storage'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    state.pickAndOpenDocument();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7F3FF),
                    child: Icon(Icons.note_add_rounded, color: FacebookTheme.primaryColor),
                  ),
                  title: const Text('Create Blank Document', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Configure page dimensions (US Letter, A4, Legal)'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    CreateDialogs.showCreateBlankDialog(context, state);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.post_add_rounded, color: Color(0xFF9360F7)),
                  ),
                  title: const Text('Create from Text', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Compile text notes directly into PDF'),
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
