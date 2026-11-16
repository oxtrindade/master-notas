import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

class StrokesPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Color? paper;

  StrokesPainter(this.strokes, {this.paper});

  @override
  void paint(Canvas canvas, Size size) {
    if (paper != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = paper!);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final s in strokes) {
      _drawStroke(canvas, s, size.width);
    }
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke s, double w) {
    final p = s.pts;
    if (p.length < 2) return;
    final color = s.highlighter ? Color(s.color).withAlpha(90) : Color(s.color);
    final sw = (s.width * w).clamp(0.5, 200.0).toDouble();

    if (p.length < 4) {
      canvas.drawCircle(
        Offset(p[0] * w, p[1] * w),
        sw / 2,
        Paint()..color = color,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = s.highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = sw
      ..isAntiAlias = true;

    final path = Path()..moveTo(p[0] * w, p[1] * w);
    if (p.length == 4) {
      path.lineTo(p[2] * w, p[3] * w);
    } else {
      for (int i = 2; i < p.length - 2; i += 2) {
        final mx = (p[i] + p[i + 2]) / 2 * w;
        final my = (p[i + 1] + p[i + 3]) / 2 * w;
        path.quadraticBezierTo(p[i] * w, p[i + 1] * w, mx, my);
      }
      path.lineTo(p[p.length - 2] * w, p[p.length - 1] * w);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StrokesPainter oldDelegate) => true;
}

class DrawResult {
  final List<Stroke> strokes;
  final double aspect;
  DrawResult(this.strokes, this.aspect);
}

enum _Tool { pen, highlighter, eraser }

const List<int> _palette = [
  0xFF000000,
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFF795548,
];

const List<double> _penSizes = [2.5, 5.0, 9.0];
const List<double> _hlSizes = [14.0, 22.0, 32.0];

class DrawScreen extends StatefulWidget {
  final List<Stroke> strokes;
  final double? aspect;

  const DrawScreen({super.key, required this.strokes, this.aspect});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  late List<Stroke> _strokes;
  final List<List<Stroke>> _undo = [];
  final List<List<Stroke>> _redo = [];
  Stroke? _cur;
  int? _pointer;
  bool _erasedAny = false;

  _Tool _tool = _Tool.pen;
  int _color = 0;
  int _size = 1;

  double? _aspect; // altura / largura
  double _canvasW = 1;

  @override
  void initState() {
    super.initState();
    _strokes = List<Stroke>.from(widget.strokes);
    _aspect = widget.strokes.isNotEmpty ? widget.aspect : null;
  }

  void _pushHistory() {
    _undo.add(List<Stroke>.from(_strokes));
    _redo.clear();
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    final x = e.localPosition.dx / _canvasW;
    final y = e.localPosition.dy / _canvasW;
    if (_tool == _Tool.eraser) {
      _pushHistory();
      _erasedAny = false;
      _erase(x, y);
    } else {
      _pushHistory();
      final px = _tool == _Tool.highlighter ? _hlSizes[_size] : _penSizes[_size];
      _cur = Stroke(
        color: _palette[_color],
        width: px / _canvasW,
        highlighter: _tool == _Tool.highlighter,
        pts: [x, y],
      );
      _strokes.add(_cur!);
    }
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final x = e.localPosition.dx / _canvasW;
    final y = e.localPosition.dy / _canvasW;
    if (_tool == _Tool.eraser) {
      _erase(x, y);
    } else {
      _cur?.pts.addAll([x, y]);
    }
    setState(() {});
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_tool == _Tool.eraser) {
      if (!_erasedAny && _undo.isNotEmpty) _undo.removeLast();
    }
    _cur = null;
    setState(() {});
  }

  void _erase(double x, double y) {
    const r = 0.035;
    final before = _strokes.length;
    _strokes = _strokes.where((s) {
      for (int i = 0; i + 1 < s.pts.length; i += 2) {
        final dx = s.pts[i] - x;
        final dy = s.pts[i + 1] - y;
        if (dx * dx + dy * dy < r * r) return false;
      }
      return true;
    }).toList();
    if (_strokes.length != before) _erasedAny = true;
  }

  void _undoStep() {
    if (_undo.isEmpty) return;
    _redo.add(List<Stroke>.from(_strokes));
    setState(() => _strokes = _undo.removeLast());
  }

  void _redoStep() {
    if (_redo.isEmpty) return;
    _undo.add(List<Stroke>.from(_strokes));
    setState(() => _strokes = _redo.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _pushHistory();
    setState(() => _strokes = <Stroke>[]);
  }

  void _finish() {
    Navigator.of(context).pop(DrawResult(_strokes, _aspect ?? 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _finish,
          ),
          title: const Text('Desenho'),
          actions: [
            IconButton(
              tooltip: 'Desfazer',
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty ? null : _undoStep,
            ),
            IconButton(
              tooltip: 'Refazer',
              icon: const Icon(Icons.redo),
              onPressed: _redo.isEmpty ? null : _redoStep,
            ),
            IconButton(
              tooltip: 'Limpar tudo',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _strokes.isEmpty ? null : _clear,
            ),
            TextButton(onPressed: _finish, child: const Text('Concluir')),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, c) {
            _aspect ??= c.maxHeight / c.maxWidth;
            final a = _aspect!;
            final w = (c.maxWidth - 24) < (c.maxHeight - 24) / a
                ? (c.maxWidth - 24)
                : (c.maxHeight - 24) / a;
            final h = w * a;
            _canvasW = w;
            return Center(
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: _up,
                    onPointerCancel: _up,
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: StrokesPainter(_strokes, paper: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: Material(
          color: cs.surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _toolBtn(Icons.edit, 'Caneta', _Tool.pen),
                      _toolBtn(Icons.border_color, 'Marca-texto',
                          _Tool.highlighter),
                      _toolBtn(Icons.cleaning_services_outlined, 'Borracha',
                          _Tool.eraser),
                      const Spacer(),
                      for (int i = 0; i < 3; i++) _sizeBtn(i),
                    ],
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (int i = 0; i < _palette.length; i++)
                          GestureDetector(
                            onTap: () => setState(() {
                              _color = i;
                              if (_tool == _Tool.eraser) _tool = _Tool.pen;
                            }),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color(_palette[i]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i == _color
                                      ? kAccent
                                      : cardBorder(context),
                                  width: i == _color ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tip, _Tool t) {
    final sel = _tool == t;
    return IconButton(
      tooltip: tip,
      icon: Icon(icon, color: sel ? kAccent : null),
      style: sel
          ? IconButton.styleFrom(backgroundColor: const Color(0x203E91FF))
          : null,
      onPressed: () => setState(() => _tool = t),
    );
  }

  Widget _sizeBtn(int i) {
    final sel = _size == i;
    final d = 8.0 + i * 5;
    return GestureDetector(
      onTap: () => setState(() => _size = i),
      child: Container(
        width: 34,
        height: 40,
        alignment: Alignment.center,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sel ? kAccent : Colors.grey,
          ),
        ),
      ),
    );
  }
}
