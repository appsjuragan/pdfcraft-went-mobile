import 'package:flutter/material.dart';
import '../../state/pdf_state.dart';
import '../theme/facebook_theme.dart';
import '../widgets/signature_pad.dart';

class SignView extends StatefulWidget {
  final PdfState state;

  const SignView({super.key, required this.state});

  @override
  State<SignView> createState() => _SignViewState();
}

class _SignViewState extends State<SignView> {
  final GlobalKey<SignaturePadState> _signaturePadKey = GlobalKey<SignaturePadState>();
  late TextEditingController _nameController;
  late TextEditingController _reasonController;
  late TextEditingController _locationController;

  String _placement = 'bottom_right'; // 'bottom_right', 'bottom_left', 'center'

  String _getPhoneLocation() {
    final tz = DateTime.now().timeZoneName;
    return 'Poco F5 ($tz)';
  }

  @override
  void initState() {
    super.initState();
    // Name and Reason start empty with clear placeholders as requested
    _nameController = TextEditingController();
    _reasonController = TextEditingController();
    // Location defaults to phone location
    _locationController = TextEditingController(text: _getPhoneLocation());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Rect _calculatePlacementRect() {
    // PDF standard coordinate system (origin bottom-left: x, y, width, height)
    switch (_placement) {
      case 'bottom_left':
        return const Rect.fromLTWH(50, 50, 200, 75);
      case 'center':
        return const Rect.fromLTWH(200, 350, 220, 80);
      case 'bottom_right':
      default:
        return const Rect.fromLTWH(360, 50, 200, 75);
    }
  }

  Future<void> _handleSign() async {
    final signerName = _nameController.text.trim();
    if (signerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your signer name'),
          backgroundColor: FacebookTheme.primaryColor,
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim().isEmpty
        ? 'Approved and Accepted'
        : _reasonController.text.trim();
    final location = _locationController.text.trim().isEmpty
        ? _getPhoneLocation()
        : _locationController.text.trim();

    final strokes = _signaturePadKey.currentState?.getStrokes();
    final rect = _calculatePlacementRect();

    await widget.state.signActiveDocument(
      signerName: signerName,
      reason: reason,
      location: location,
      strokes: strokes,
      placementRect: rect,
    );
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
                child: const Icon(Icons.draw_rounded, size: 48, color: FacebookTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Document to Sign',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a document from your feed or open a contract to place your cryptographic signature.',
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
                onPressed: () => widget.state.setTab(0),
                icon: const Icon(Icons.feed_outlined),
                label: const Text('Select from Feed'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Target Document Header Card
          Container(
            color: FacebookTheme.cardBg,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                    color: FacebookTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: doc.previewPng != null
                      ? Image.memory(doc.previewPng!, fit: BoxFit.cover)
                      : const Icon(Icons.picture_as_pdf_rounded, color: FacebookTheme.primaryColor),
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 2),
                      Text(
                        'Signing Page ${widget.state.activePageIndex} of ${doc.pageCount}',
                        style: const TextStyle(color: FacebookTheme.textSecondary, fontSize: 12),
                      ),
                      if (doc.isSigned)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '✓ Document already has digital signature(s)',
                            style: TextStyle(color: Color(0xFF45BD62), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.state.setTab(1),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('View'),
                ),
              ],
            ),
          ),

          // 2. Signer Identity Section with Placeholders & Location Options
          Container(
            color: FacebookTheme.cardBg,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_rounded, color: FacebookTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Signer Identity & Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Signer Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: FacebookTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    hintText: 'Enter signer full name (required)',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: FacebookTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Reason / Purpose', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: FacebookTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.assignment_outlined, size: 20),
                    hintText: 'e.g. Approved and Accepted, Contract Execution',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: FacebookTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Location / Pin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: FacebookTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                    hintText: 'Phone Location or Custom Pin',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: FacebookTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 8),
                // Location & Pin selection chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.phone_android_rounded, size: 14, color: FacebookTheme.primaryColor),
                      label: const Text('Phone Location', style: TextStyle(fontSize: 11)),
                      backgroundColor: FacebookTheme.surfaceColor,
                      onPressed: () {
                        setState(() {
                          _locationController.text = _getPhoneLocation();
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.push_pin_rounded, size: 14, color: Colors.deepOrange),
                      label: const Text('Custom Pin', style: TextStyle(fontSize: 11)),
                      backgroundColor: FacebookTheme.surfaceColor,
                      onPressed: () => _showCustomPinDialog(context),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.business_rounded, size: 14, color: Color(0xFF45BD62)),
                      label: const Text('Office HQ', style: TextStyle(fontSize: 11)),
                      backgroundColor: FacebookTheme.surfaceColor,
                      onPressed: () {
                        setState(() {
                          _locationController.text = 'Office Headquarters';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF9360F7)),
                      label: const Text('Remote Verified', style: TextStyle(fontSize: 11)),
                      backgroundColor: FacebookTheme.surfaceColor,
                      onPressed: () {
                        setState(() {
                          _locationController.text = 'Remote Verified Device';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Signature Drawing Canvas
          Container(
            color: FacebookTheme.cardBg,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gesture_rounded, color: FacebookTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Draw Vector Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Draw with your finger or stylus. Your vector strokes are recorded and embedded directly into the PDF signature appearance dictionary.',
                  style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SignaturePad(
                  key: _signaturePadKey,
                  height: 180,
                  strokeColor: const Color(0xFF0F3B82),
                  strokeWidth: 3.0,
                ),
              ],
            ),
          ),

          // 4. Placement Selector
          Container(
            color: FacebookTheme.cardBg,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.place_rounded, color: FacebookTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Stamp Placement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bottom_right', label: Text('Bottom Right')),
                    ButtonSegment(value: 'bottom_left', label: Text('Bottom Left')),
                    ButtonSegment(value: 'center', label: Text('Page Center')),
                  ],
                  selected: {_placement},
                  onSelectionChanged: (set) => setState(() => _placement = set.first),
                ),
              ],
            ),
          ),

          // 5. Cryptographic Security Details (Clean Meta info card)
          Container(
            color: FacebookTheme.cardBg,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF45BD62).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFF45BD62), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'P-256 ECDSA Digital Signatures',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Signatures are cryptographically signed using an on-device NIST P-256 private key and embedded as ETSI.CAdES.detached conforming to ISO 32000-2.',
                        style: TextStyle(color: FacebookTheme.textSecondary, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 6. Primary Execution Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FacebookTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              onPressed: widget.state.isLoading ? null : _handleSign,
              icon: widget.state.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.draw_rounded),
              label: Text(
                widget.state.isLoading ? 'Signing with PdfCraft Engine...' : 'Sign Document with P-256 ECDSA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomPinDialog(BuildContext context) {
    final pinController = TextEditingController(text: _locationController.text);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.push_pin_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text('Custom Location Pin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter custom city, address, or coordinate pin:', style: TextStyle(fontSize: 12, color: FacebookTheme.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: pinController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Jakarta, Indonesia (-6.2088, 106.8456)',
                  filled: true,
                  fillColor: FacebookTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FacebookTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.isNotEmpty) {
                  setState(() => _locationController.text = pin);
                }
                Navigator.pop(dialogCtx);
              },
              child: const Text('Set Pin'),
            ),
          ],
        );
      },
    );
  }
}
