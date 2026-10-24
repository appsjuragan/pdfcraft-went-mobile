import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/facebook_theme.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<List<List<Offset>>>? onStrokesChanged;
  final VoidCallback? onClear;
  final double height;
  final Color strokeColor;
  final double strokeWidth;

  const SignaturePad({
    super.key,
    this.onStrokesChanged,
    this.onClear,
    this.height = 180.0,
    this.strokeColor = const Color(0xFF0F3B82),
    this.strokeWidth = 3.0,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
    widget.onStrokesChanged?.call([]);
    widget.onClear?.call();
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      _notifyNormalizedStrokes();
    }
  }

  int get strokeCount => _strokes.length;
  bool get hasStrokes => _strokes.isNotEmpty;

  List<List<Offset>> getStrokes() {
    if (_strokes.isEmpty) return [];

    final renderBox = context.findRenderObject() as RenderBox?;
    final width = (renderBox != null && renderBox.hasSize && renderBox.size.width > 0)
        ? renderBox.size.width
        : 340.0;
    final height = widget.height;

    return _strokes.map((stroke) {
      return stroke.map((p) {
        final nx = (p.dx / width).clamp(0.0, 1.0);
        final ny = ((height - p.dy) / height).clamp(0.0, 1.0); // PDF uses bottom-up Y coordinates
        return Offset(nx, ny);
      }).toList();
    }).toList();
  }

  void _notifyNormalizedStrokes() {
    final normalized = getStrokes();
    widget.onStrokesChanged?.call(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Signature Canvas Box
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _strokes.isNotEmpty ? FacebookTheme.primaryColor : FacebookTheme.fbCardBorder,
              width: _strokes.isNotEmpty ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Guidelines
              Positioned(
                left: 20,
                right: 20,
                bottom: 35,
                child: Container(
                  height: 1,
                  color: FacebookTheme.fbDivider.withValues(alpha: 0.6),
                ),
              ),
              Positioned(
                left: 24,
                bottom: 12,
                child: Row(
                  children: [
                    const Text(
                      '✕ Sign on the line above',
                      style: TextStyle(
                        color: FacebookTheme.fbTextSubdued,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_strokes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_strokes.length} ${_strokes.length == 1 ? "stroke" : "strokes"}',
                          style: const TextStyle(
                            color: Color(0xFF31A24C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Interactive Drawing Surface with EagerGestureRecognizer & Raw Pointer Listener
              Positioned.fill(
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                      (EagerGestureRecognizer instance) {},
                    ),
                  },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      setState(() {
                        _currentStroke = [event.localPosition];
                        _strokes.add(_currentStroke!);
                      });
                    },
                    onPointerMove: (event) {
                      setState(() {
                        _currentStroke?.add(event.localPosition);
                      });
                    },
                    onPointerUp: (event) {
                      _currentStroke = null;
                      _notifyNormalizedStrokes();
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          color: widget.strokeColor,
                          width: widget.strokeWidth,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Canvas Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _strokes.isNotEmpty ? undo : null,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo'),
              style: TextButton.styleFrom(
                foregroundColor: FacebookTheme.fbTextSecondary,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _strokes.isNotEmpty ? clear : null,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: FacebookTheme.fbRed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  _SignaturePainter({
    required this.strokes,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, width / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);

        for (int i = 1; i < stroke.length; i++) {
          final p0 = stroke[i - 1];
          final p1 = stroke[i];
          final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
