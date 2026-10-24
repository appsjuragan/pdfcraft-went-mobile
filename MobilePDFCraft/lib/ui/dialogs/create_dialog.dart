import 'package:flutter/material.dart';
import '../theme/facebook_theme.dart';
import '../../state/pdf_state.dart';

class CreateDialogs {
  /// Dialog for creating a new Blank PDF with customizable dimensions and page count
  static Future<void> showCreateBlankDialog(BuildContext context, PdfState state) async {
    final titleController = TextEditingController(text: 'Untitled Document');
    int pageCount = 1;
    String pageSize = 'Letter'; // Letter, A4, Legal

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FacebookTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.note_add_rounded, color: FacebookTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('Create Blank PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Document Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: FacebookTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Page Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: pageSize,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: FacebookTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Letter', child: Text('US Letter (8.5 × 11 in)')),
                        DropdownMenuItem(value: 'A4', child: Text('A4 (210 × 297 mm)')),
                        DropdownMenuItem(value: 'Legal', child: Text('US Legal (8.5 × 14 in)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => pageSize = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Number of Pages', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: FacebookTheme.primaryColor),
                              onPressed: pageCount > 1 ? () => setState(() => pageCount--) : null,
                            ),
                            Text('$pageCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: FacebookTheme.primaryColor),
                              onPressed: pageCount < 50 ? () => setState(() => pageCount++) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: FacebookTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FacebookTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    double width = 612.0;
                    double height = 792.0;
                    if (pageSize == 'A4') {
                      width = 595.28;
                      height = 841.89;
                    } else if (pageSize == 'Legal') {
                      width = 612.0;
                      height = 1008.0;
                    }
                    final title = titleController.text.trim().isEmpty ? 'Untitled Document' : titleController.text.trim();
                    state.createBlankDocument(
                      width: width,
                      height: height,
                      pages: pageCount,
                      title: title,
                    );
                  },
                  child: const Text('Create PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog for creating a PDF directly from plain or formatted text
  static Future<void> showCreateTextDialog(BuildContext context, PdfState state) async {
    final titleController = TextEditingController(text: 'Notes & Document');
    final textController = TextEditingController(
      text: 'This document was compiled instantly using the PdfCraft Core engine.\n\n'
          'Key Features:\n'
          '1. Direct PDF font metrics embedding.\n'
          '2. High-speed vector rendering.\n'
          '3. Cryptographic signature support ready.\n'
          '4. Clean Facebook aesthetic layout.',
    );
    double fontSize = 12.0;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FacebookTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.post_add_rounded, color: FacebookTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('Text to PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: FacebookTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Content', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Type or paste document content here...',
                        filled: true,
                        fillColor: FacebookTheme.surfaceColor,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                        Text('${fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: FacebookTheme.primaryColor)),
                      ],
                    ),
                    Slider(
                      value: fontSize,
                      min: 9.0,
                      max: 24.0,
                      divisions: 15,
                      activeColor: FacebookTheme.primaryColor,
                      onChanged: (val) => setState(() => fontSize = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: FacebookTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FacebookTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    final title = titleController.text.trim().isEmpty ? 'Document' : titleController.text.trim();
                    state.createTextDocument(
                      title: title,
                      text: textController.text,
                      fontSize: fontSize,
                    );
                  },
                  child: const Text('Generate PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog for applying watermarks to current active document
  static Future<void> showWatermarkDialog(BuildContext context, PdfState state) async {
    final textController = TextEditingController(text: 'CONFIDENTIAL');
    double opacity = 0.3;
    double rotation = 45.0;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FacebookTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop_outlined, color: FacebookTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('Apply Watermark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Watermark Text', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'e.g. CONFIDENTIAL, DRAFT, APPROVED',
                        filled: true,
                        fillColor: FacebookTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: ['CONFIDENTIAL', 'DRAFT', 'APPROVED', 'INTERNAL ONLY'].map((preset) {
                        return ActionChip(
                          label: Text(preset, style: const TextStyle(fontSize: 11)),
                          backgroundColor: FacebookTheme.surfaceColor,
                          onPressed: () => setState(() => textController.text = preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opacity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                        Text('${(opacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: FacebookTheme.primaryColor)),
                      ],
                    ),
                    Slider(
                      value: opacity,
                      min: 0.1,
                      max: 0.8,
                      divisions: 7,
                      activeColor: FacebookTheme.primaryColor,
                      onChanged: (val) => setState(() => opacity = val),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Angle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: FacebookTheme.textSecondary)),
                        Text('${rotation.toInt()}°', style: const TextStyle(fontWeight: FontWeight.bold, color: FacebookTheme.primaryColor)),
                      ],
                    ),
                    Slider(
                      value: rotation,
                      min: 0.0,
                      max: 90.0,
                      divisions: 6,
                      activeColor: FacebookTheme.primaryColor,
                      onChanged: (val) => setState(() => rotation = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: FacebookTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FacebookTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    final text = textController.text.trim().isEmpty ? 'CONFIDENTIAL' : textController.text.trim();
                    state.addWatermarkToActive(
                      text: text,
                      opacity: opacity,
                      rotation: rotation,
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog for rotating current page
  static Future<void> showRotateDialog(BuildContext context, PdfState state) async {
    int degrees = 90;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FacebookTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.rotate_right_rounded, color: FacebookTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('Rotate Page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rotate Page ${state.activePageIndex} clockwise:'),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 90, label: Text('90°')),
                      ButtonSegment(value: 180, label: Text('180°')),
                      ButtonSegment(value: 270, label: Text('270°')),
                    ],
                    selected: {degrees},
                    onSelectionChanged: (set) {
                      setState(() => degrees = set.first);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: FacebookTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FacebookTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    state.rotateActivePage(degrees: degrees);
                  },
                  child: const Text('Rotate'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
