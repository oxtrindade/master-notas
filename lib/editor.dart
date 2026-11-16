import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialogs.dart';
import 'drawing.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';

class EditorScreen extends StatefulWidget {
  final NotesStore store;
  final Note note;
  final bool isNew;

  const EditorScreen({
    super.key,
    required this.store,
    required this.note,
    this.isNew = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Note note;
  late final TextEditingController _title;
  final FocusNode _titleFocus = FocusNode();
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focus = {};
  String? _lastFocus;
  Timer? _timer;
  bool _dirty = false;
  bool _trashed = false;

  @override
  void initState() {
    super.initState();
    note = widget.note;
    if (note.blocks.isEmpty) note.blocks.add(Block(type: BlockType.text));
    _title = TextEditingController(text: note.title);
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty && !_trashed) {
      widget.store.saveNote(note, defer: true);
    }
    _title.dispose();
    _titleFocus.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ utilidades

  TextEditingController _ctl(Block b) =>
      _ctrls.putIfAbsent(b.id, () => TextEditingController(text: b.text));

  FocusNode _fn(Block b) => _focus.putIfAbsent(b.id, () {
        final f = FocusNode();
        f.addListener(() {
          if (f.hasFocus) _lastFocus = b.id;
        });
        return f;
      });

  void _changed() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (!_trashed) widget.store.saveNote(note);
    });
  }

  Block? _focusedBlock() {
    for (final b in note.blocks) {
      final f = _focus[b.id];
      if (f != null && f.hasFocus) return b;
    }
    if (_lastFocus != null) {
      for (final b in note.blocks) {
        if (b.id == _lastFocus) return b;
      }
    }
    return null;
  }

  void _focusLater(Block b) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fn(b).requestFocus();
      final c = _ctl(b);
      c.selection = TextSelection.collapsed(offset: c.text.length);
    });
  }

  void _insertAfter(Block? ref, Block nb) {
    final i = ref == null ? -1 : note.blocks.indexOf(ref);
    if (i < 0) {
      note.blocks.add(nb);
    } else {
      note.blocks.insert(i + 1, nb);
    }
  }

  void _removeBlock(Block b) {
    setState(() {
      note.blocks.remove(b);
      if (note.blocks.isEmpty) note.blocks.add(Block(type: BlockType.text));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrls.remove(b.id)?.dispose();
      _focus.remove(b.id)?.dispose();
    });
    _changed();
  }

  // ------------------------------------------------------------------ ações

  void _addCheck() {
    final b = _focusedBlock();
    if (b != null && b.type == BlockType.check) {
      setState(() => b.type = BlockType.text);
      _focusLater(b);
      _changed();
      return;
    }
    if (b != null && b.type == BlockType.text && b.text.trim().isEmpty) {
      setState(() => b.type = BlockType.check);
      _focusLater(b);
      _changed();
      return;
    }
    final nb = Block(type: BlockType.check);
    setState(() => _insertAfter(b, nb));
    _focusLater(nb);
    _changed();
  }

  Future<void> _addDrawing() async {
    final nb = Block(type: BlockType.draw);
    setState(() => _insertAfter(_focusedBlock(), nb));
    await _editDrawing(nb);
  }

  Future<void> _editDrawing(Block b) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await Navigator.of(context).push<DrawResult>(
      MaterialPageRoute<DrawResult>(
        builder: (_) => DrawScreen(
          strokes: List<Stroke>.from(b.strokes),
          aspect: b.strokes.isEmpty ? null : b.aspect,
        ),
      ),
    );
    if (!mounted) return;
    if (res == null || res.strokes.isEmpty) {
      _removeBlock(b);
      return;
    }
    setState(() {
      b.strokes = res.strokes;
      b.aspect = res.aspect;
    });
    _changed();
  }

  void _onCheckChanged(Block b, String v) {
    if (!v.contains('\n')) {
      b.text = v;
      _changed();
      return;
    }
    final i = v.indexOf('\n');
    final before = v.substring(0, i);
    final after = v.substring(i + 1).replaceAll('\n', ' ');
    if (before.trim().isEmpty && after.trim().isEmpty) {
      // Enter em item vazio: sai da lista
      final c = _ctl(b);
      c.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      b.text = '';
      setState(() => b.type = BlockType.text);
      _focusLater(b);
      _changed();
      return;
    }
    final c = _ctl(b);
    c.value = TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );
    b.text = before;
    final nb = Block(type: BlockType.check, text: after);
    setState(() {
      final idx = note.blocks.indexOf(b);
      note.blocks.insert(idx + 1, nb);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fn(nb).requestFocus();
      _ctl(nb).selection = const TextSelection.collapsed(offset: 0);
    });
    _changed();
  }

  void _focusEnd() {
    var last = note.blocks.last;
    if (last.type == BlockType.draw) {
      last = Block(type: BlockType.text);
      final nb = last;
      setState(() => note.blocks.add(nb));
    }
    _focusLater(last);
  }

  void _togglePin() {
    setState(() => note.pinned = !note.pinned);
    _changed();
  }

  Future<void> _pickColor() async {
    final i = await pickNoteColor(context, note.colorIndex);
    if (i != null && mounted) {
      setState(() => note.colorIndex = i);
      _changed();
    }
  }

  Future<void> _pickFolder() async {
    final r = await pickFolder(context, widget.store, current: note.folderId);
    if (r != null && mounted) {
      setState(() => note.folderId = r.id);
      _changed();
    }
  }

  void _copyText() {
    final t = '${note.title}\n${note.plainText}'.trim();
    Clipboard.setData(ClipboardData(text: t));
    snack(context, 'Texto copiado');
  }

  void _delete() {
    _timer?.cancel();
    _trashed = true;
    final inStore = widget.store.notes.any((n) => n.id == note.id);
    if (inStore) widget.store.trashNotes([note.id]);
    Navigator.of(context).pop<String>(inStore ? note.id : null);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final bg = noteBg(context, note.colorIndex);
    final folder = widget.store.folderName(note.folderId);
    final cs = Theme.of(context).colorScheme;
    final meta = [
      widget.isNew && !_dirty ? 'Agora' : fmtDate(note.updated),
      if (folder != null) folder,
    ].join('  •  ');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: note.pinned ? 'Desafixar' : 'Fixar',
            icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: _togglePin,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'copy':
                  _copyText();
                  break;
                case 'folder':
                  _pickFolder();
                  break;
                case 'color':
                  _pickColor();
                  break;
                case 'delete':
                  _delete();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Copiar texto')),
              PopupMenuItem(value: 'folder', child: Text('Mover para pasta')),
              PopupMenuItem(value: 'color', child: Text('Cor da nota')),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              maxLines: null,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Título',
              ),
              onChanged: (v) {
                note.title = v;
                _changed();
              },
              onSubmitted: (_) {
                for (final b in note.blocks) {
                  if (b.type != BlockType.draw) {
                    _fn(b).requestFocus();
                    break;
                  }
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              meta,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 14),
            for (final b in note.blocks) _blockWidget(b),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focusEnd,
              child: const SizedBox(height: 260, width: double.infinity),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _toolbar(cs),
    );
  }

  Widget _blockWidget(Block b) {
    switch (b.type) {
      case BlockType.text:
        return _textBlock(b);
      case BlockType.check:
        return _checkBlock(b);
      case BlockType.draw:
        return _drawBlock(b);
    }
  }

  Widget _textBlock(Block b) {
    final only = note.blocks.length == 1;
    return Padding(
      key: ValueKey(b.id),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: _ctl(b),
        focusNode: _fn(b),
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 17, height: 1.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: only ? 'Escreva aqui' : null,
        ),
        onChanged: (v) {
          b.text = v;
          _changed();
        },
      ),
    );
  }

  Widget _checkBlock(Block b) {
    final cs = Theme.of(context).colorScheme;
    final fn = _fn(b);
    return Padding(
      key: ValueKey(b.id),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 26,
            child: Checkbox(
              value: b.checked,
              shape: const CircleBorder(),
              activeColor: kAccent,
              side: BorderSide(
                color: cs.onSurface.withAlpha(150),
                width: 1.6,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (v) {
                setState(() => b.checked = v ?? false);
                _changed();
              },
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctl(b),
              focusNode: fn,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                decoration:
                    b.checked ? TextDecoration.lineThrough : TextDecoration.none,
                color: b.checked ? cs.onSurface.withAlpha(120) : null,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (v) => _onCheckChanged(b, v),
            ),
          ),
          ListenableBuilder(
            listenable: fn,
            builder: (context, _) => fn.hasFocus
                ? SizedBox(
                    width: 32,
                    height: 26,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Remover item',
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeBlock(b),
                    ),
                  )
                : const SizedBox(width: 32),
          ),
        ],
      ),
    );
  }

  Widget _drawBlock(Block b) {
    final a = b.aspect <= 0 ? 1.0 : b.aspect;
    return Padding(
      key: ValueKey(b.id),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => _editDrawing(b),
        child: Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark(context)
                ? const Color(0x33FFFFFF)
                : const Color(0x0D000000),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    aspectRatio: 1 / a,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CustomPaint(
                        painter: StrokesPainter(b.strokes, paper: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: 'Remover desenho',
                  iconSize: 20,
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeBlock(b),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(ColorScheme cs) {
    return Material(
      color: cs.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Lista de tarefas',
                icon: const Icon(Icons.check_box_outlined),
                onPressed: _addCheck,
              ),
              IconButton(
                tooltip: 'Desenhar',
                icon: const Icon(Icons.brush_outlined),
                onPressed: _addDrawing,
              ),
              IconButton(
                tooltip: 'Cor da nota',
                icon: const Icon(Icons.palette_outlined),
                onPressed: _pickColor,
              ),
              IconButton(
                tooltip: 'Pasta',
                icon: const Icon(Icons.folder_outlined),
                onPressed: _pickFolder,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Ocultar teclado',
                icon: const Icon(Icons.keyboard_hide_outlined),
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
