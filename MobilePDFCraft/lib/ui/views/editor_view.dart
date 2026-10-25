import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../state/pdf_state.dart';
import '../theme/facebook_theme.dart';

/// Mobile WYSIWYG editor: tap the page to place text or an image, edit or
/// delete added items, and password-protect the document.
class EditorView extends StatefulWidget {
  final PdfState state;
  const EditorView({super.key, required this.state});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  List<Map<String, dynamic>> _items = [];
  // Page size in PDF points, from inspect (fallback: US Letter).
  double _pageW = 612, _pageH = 792;

  PdfState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final info = await state.inspectActiveDocument();
    if (!mounted) return;
    final pages = info['pages'];
    final page = state.activePageIndex;
    if (pages is List) {
      for (final p in pages) {
        if (p is Map && p['page'] == page) {
          final w = (p['width'] as num?)?.toDouble();
          final h = (p['height'] as num?)?.toDouble();
          if (w != null && w > 0 && h != null && h > 0) {
            _pageW = w;
            _pageH = h;
          }
        }
      }
    }
    _items = await state.listActiveContent();
    if (mounted) setState(() {});
  }

  /// Map a tap on the preview (BoxFit.contain) to a PDF point (y down from top).
  Offset _tapToPdf(Offset tap, Size boxSize) {
    final scale = boxSize.width / _pageW < boxSize.height / _pageH
        ? boxSize.width / _pageW
        : boxSize.height / _pageH;
    final dx = (boxSize.width - _pageW * scale) / 2;
    final dy = (boxSize.height - _pageH * scale) / 2;
    return Offset(((tap.dx - dx) / scale).clamp(0.0, _pageW), ((tap.dy - dy) / scale).clamp(0.0, _pageH));
  }

  Future<void> _addTextAt(Offset pdfPoint) async {
    final placed = await _showTextSheet(initialTopLeft: pdfPoint);
    if (placed == true) await _refresh();
  }

  Future<void> _addImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    final f = res?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    await state.addImageToActive(imageBytes: f.bytes!);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final doc = state.activeDocument;
    if (doc == null) return const SizedBox.shrink();
    final preview = doc.previewPng;

    return Scaffold(
      backgroundColor: const Color(0xFFE4E6EB),
      appBar: AppBar(
        backgroundColor: FacebookTheme.cardBg,
        foregroundColor: FacebookTheme.textPrimary,
        title: Text('Edit "${doc.title}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: doc.isProtected ? 'Remove password' : 'Set password',
            onPressed: () async {
              if (doc.isProtected) {
                await _showUnprotectSheet();
              } else {
                await _showProtectSheet();
              }
              await _refresh();
            },
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      body: Column(
        children: [
          if (doc.isProtected)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFE0B2),
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Encrypted — editing disabled until the password is removed',
                style: TextStyle(color: Color(0xFF8D6E00), fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: _pageW / _pageH,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final box = Size(constraints.maxWidth, constraints.maxHeight);
                        return GestureDetector(
                          onTapUp: doc.isProtected ? null : (d) => _addTextAt(_tapToPdf(d.localPosition, box)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: preview != null
                                ? Image.memory(preview, key: ValueKey('${doc.id}_${preview.hashCode}_${state.activePageIndex}'), fit: BoxFit.contain)
                                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FacebookTheme.cardBg,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _action(Icons.text_fields_rounded, 'Tap page\nto add text', const Color(0xFF1877F2)),
                  _action(Icons.image_rounded, 'Add\nimage', const Color(0xFF45BD62),
                      onTap: doc.isProtected ? null : _addImage),
                  _action(Icons.format_list_bulleted_rounded, 'Items\n(${_items.length})', const Color(0xFFF7B125),
                      onTap: _items.isEmpty || doc.isProtected ? null : _showItemsSheet),
                  _action(Icons.lock_outline_rounded, doc.isProtected ? 'Remove\npassword' : 'Password',
                      doc.isProtected ? const Color(0xFFE41E3F) : const Color(0xFF9360F7),
                      onTap: doc.isProtected ? _showUnprotectSheet : _showProtectSheet),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: FacebookTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ---- Text sheet (add + edit share this) ----

  Future<bool?> _showTextSheet({
    Offset? initialTopLeft,
    Map<String, dynamic>? item,
  }) {
    final editing = item != null;
    final ctrl = TextEditingController(text: editing ? (item['text'] as String? ?? '') : '');
    String font = editing ? (item['font'] as String? ?? 'helvetica') : 'helvetica';
    double size = editing ? ((item['size'] as num?)?.toDouble() ?? 14) : 14;
    bool bold = editing ? (item['bold'] as bool? ?? false) : false;
    bool italic = editing ? (item['italic'] as bool? ?? false) : false;
    String align = editing ? (item['align'] as String? ?? 'left') : 'left';
    Color color = Colors.black;
    if (editing) {
      final c = item['color'];
      if (c is List && c.length == 3) {
        color = Color.fromARGB(255, (c[0] * 255).round(), (c[1] * 255).round(), (c[2] * 255).round());
      }
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FacebookTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit text' : 'New text', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: !editing,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type your text…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in const ['helvetica', 'times', 'courier'])
                    ChoiceChip(
                      label: Text(f),
                      selected: font == f,
                      onSelected: (_) => setSheet(() => font = f),
                    ),
                  for (final a in const ['left', 'center', 'right', 'justify'])
                    ChoiceChip(
                      label: Text(a),
                      selected: align == a,
                      onSelected: (_) => setSheet(() => align = a),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.format_bold_rounded, color: bold ? FacebookTheme.primaryColor : FacebookTheme.textSecondary),
                    onPressed: () => setSheet(() => bold = !bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_italic_rounded, color: italic ? FacebookTheme.primaryColor : FacebookTheme.textSecondary),
                    onPressed: () => setSheet(() => italic = !italic),
                  ),
                  Expanded(
                    child: Slider(
                      value: size.clamp(6.0, 72.0),
                      min: 6,
                      max: 72,
                      label: size.round().toString(),
                      onChanged: (v) => setSheet(() => size = v),
                    ),
                  ),
                  Text('${size.round()}pt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in const [
                    Color(0xFF000000), Color(0xFF1877F2), Color(0xFFE41E3F),
                    Color(0xFF45BD62), Color(0xFFF7B125), Color(0xFFFFFFFF),
                  ])
                    GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: color == c ? FacebookTheme.primaryColor : Colors.grey, width: color == c ? 3 : 1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: FacebookTheme.primaryColor),
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.of(ctx).pop(true);
                    if (editing) {
                      await state.updateActiveContent(
                        page: item['page'] as int,
                        index: item['index'] as int,
                        text: text,
                        font: font,
                        fontSize: size,
                        bold: bold,
                        italic: italic,
                        color: color,
                        align: align,
                      );
                    } else {
                      final p = initialTopLeft ?? const Offset(72, 72);
                      await state.addTextToActive(
                        text: text,
                        x: p.dx,
                        y: p.dy,
                        font: font,
                        fontSize: size,
                        bold: bold,
                        italic: italic,
                        color: color,
                        align: align,
                      );
                    }
                    await _refresh();
                  },
                  child: Text(editing ? 'Save changes' : 'Add to page'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Items list ----  // ---- Items list ----

  Future<void> _showItemsSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: FacebookTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Added content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final item in _items)
              ListTile(
                leading: Icon(
                  item['type'] == 'image' ? Icons.image_rounded : Icons.text_fields_rounded,
                  color: FacebookTheme.primaryColor,
                ),
                title: Text(
                  item['type'] == 'image' ? 'Image (page ${item['page']})' : (item['text'] as String? ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: item['type'] == 'image' ? null : Text('page ${item['page']} • ${item['size']}pt'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item['type'] == 'text')
                      IconButton(
                        icon: const Icon(Icons.edit_rounded),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final done = await _showTextSheet(item: item);
                          if (done == true) await _refresh();
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE41E3F)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await state.deleteActiveContent(page: item['page'] as int, index: item['index'] as int);
                        await _refresh();
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---- Password sheets ----

  Future<void> _showProtectSheet() async {
    final openCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    int printing = 2; // 0 none, 1 low, 2 high
    int changes = 0; // 0 none … 4 any
    bool allowCopy = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FacebookTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password-protect PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('AES-256. Set an open password to require it for viewing, an owner password to restrict actions.',
                  style: TextStyle(fontSize: 12, color: FacebookTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: openCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Open password (optional)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ownerCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Owner password (optional)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: printing,
                decoration: const InputDecoration(labelText: 'Allow printing', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Not allowed')),
                  DropdownMenuItem(value: 1, child: Text('Low resolution')),
                  DropdownMenuItem(value: 2, child: Text('High resolution')),
                ],
                onChanged: (v) => setSheet(() => printing = v ?? 2),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: changes,
                decoration: const InputDecoration(labelText: 'Allow changes', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('None')),
                  DropdownMenuItem(value: 1, child: Text('Insert/rotate pages')),
                  DropdownMenuItem(value: 2, child: Text('Fill forms & sign')),
                  DropdownMenuItem(value: 3, child: Text('Comment')),
                  DropdownMenuItem(value: 4, child: Text('Any')),
                ],
                onChanged: (v) => setSheet(() => changes = v ?? 0),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow copying text & images', style: TextStyle(fontSize: 14)),
                value: allowCopy,
                onChanged: (v) => setSheet(() => allowCopy = v),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9360F7)),
                  onPressed: () {
                    final open = openCtrl.text.trim();
                    final owner = ownerCtrl.text.trim();
                    if (open.isEmpty && owner.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter at least one password')));
                      return;
                    }
                    if (open.isNotEmpty && open == owner) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Passwords must differ')));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    state.protectActive(
                      openPassword: open.isEmpty ? null : open,
                      ownerPassword: owner.isEmpty ? null : owner,
                      printingLevel: printing,
                      changesLevel: changes,
                      allowCopy: allowCopy,
                    );
                  },
                  child: const Text('Encrypt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _showUnprotectSheet() async {
    final pwCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FacebookTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Remove password protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password (open or owner)', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE41E3F)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  state.unprotectActive(password: pwCtrl.text.trim().isEmpty ? null : pwCtrl.text.trim());
                },
                child: const Text('Remove protection'),
              ),
            ),
          ],
        ),
      ),
    );
    await _refresh();
  }
}
