import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'store.dart';

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(BuildContext c, String title, String body, {String ok = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Text field that keeps its own controller-less state via initialValue.
class Field extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? type;
  final int maxLines;
  final bool obscure;
  final String? hint;
  final Widget? suffix;
  const Field(this.label, this.value, this.onChanged,
      {super.key, this.type, this.maxLines = 1, this.obscure = false, this.hint, this.suffix});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: type ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          minLines: 1,
          maxLines: maxLines,
          obscureText: obscure,
          textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              suffixIcon: suffix,
              border: const OutlineInputBorder()),
        ),
      );
}

const numType = TextInputType.numberWithOptions(decimal: true);

String numStr(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
double parseNum(String s) => double.tryParse(s.trim()) ?? 0;

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Image chooser (logo / signature / QR / profile).
class ImageField extends StatefulWidget {
  final String label;
  final String path;
  final ValueChanged<String> onChanged;
  final bool signatureDraw;
  final double size;
  final bool circle;
  const ImageField(this.label, this.path, this.onChanged,
      {super.key, this.signatureDraw = false, this.size = 84, this.circle = false});
  @override
  State<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<ImageField> {
  late String path = widget.path;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000);
    if (x == null) return;
    final saved = await Store.i.saveImage(x.path, widget.label.replaceAll(' ', '_'));
    setState(() => path = saved);
    widget.onChanged(saved);
  }

  Future<void> _draw() async {
    final bytes = await Navigator.push<Uint8List>(
        context, MaterialPageRoute(builder: (_) => const SignaturePad()));
    if (bytes == null) return;
    final saved = await Store.i.saveBytes(bytes, 'signature');
    setState(() => path = saved);
    widget.onChanged(saved);
  }

  @override
  Widget build(BuildContext context) {
    final has = path.isNotEmpty && File(path).existsSync();
    final img = has ? Image.file(File(path), fit: BoxFit.contain) : const Icon(Icons.image_outlined);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: widget.size,
          height: widget.size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
            color: Colors.white,
          ),
          child: img,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            OutlinedButton.icon(
                onPressed: _pick, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose')),
            if (widget.signatureDraw)
              OutlinedButton.icon(
                  onPressed: _draw, icon: const Icon(Icons.draw_outlined), label: const Text('Draw')),
            if (has)
              IconButton(
                  onPressed: () {
                    setState(() => path = '');
                    widget.onChanged('');
                  },
                  icon: const Icon(Icons.close)),
          ]),
        ),
      ]),
    );
  }
}

/// Finger-drawn signature; pops PNG bytes.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> strokes = [];
  Size size = const Size(300, 200);

  Future<void> _done() async {
    if (strokes.isEmpty) return;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    _SigPainter(strokes).paint(canvas, size);
    final img = await rec.endRecording().toImage(size.width.ceil(), size.height.ceil());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || bd == null) return;
    Navigator.pop(context, bd.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Draw signature'), actions: [
          TextButton(onPressed: () => setState(strokes.clear), child: const Text('Clear')),
          TextButton(onPressed: _done, child: const Text('Done')),
        ]),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (ctx, cons) {
              size = Size(cons.maxWidth, cons.maxHeight.clamp(120, 320).toDouble());
              return Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: size.width,
                  height: size.height,
                  decoration: BoxDecoration(border: Border.all(), color: Colors.white),
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => strokes.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() => strokes.last.add(d.localPosition)),
                    child: CustomPaint(painter: _SigPainter(strokes), size: size),
                  ),
                ),
              );
            }),
          ),
        ),
      );
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SigPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawPoints(ui.PointMode.points, s, p);
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final o in s.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}
