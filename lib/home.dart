import 'package:flutter/material.dart';

import 'backup.dart';
import 'dialogs.dart';
import 'drawing.dart';
import 'editor.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'trash.dart';
import 'util.dart';

class HomeScreen extends StatefulWidget {
  final NotesStore store;

  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  final Set<String> _selected = <String>{};

  NotesStore get store => widget.store;
  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- ações

  Future<void> _open(Note n, {bool isNew = false}) async {
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => EditorScreen(store: store, note: n, isNew: isNew),
      ),
    );
    if (res != null && mounted) {
      snack(
        context,
        'Nota movida para a lixeira',
        action: 'Desfazer',
        onAction: () => store.restoreNotes([res]),
      );
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _trashSelected() {
    final ids = _selected.toList();
    store.trashNotes(ids);
    setState(() => _selected.clear());
    snack(
      context,
      ids.length == 1
          ? 'Nota movida para a lixeira'
          : '${ids.length} notas movidas para a lixeira',
      action: 'Desfazer',
      onAction: () => store.restoreNotes(ids),
    );
  }

  Future<void> _moveSelected() async {
    final r = await pickFolder(context, store);
    if (r == null || !mounted) return;
    store.moveNotes(_selected.toList(), r.id);
    setState(() => _selected.clear());
  }

  void _pinSelected(bool pin) {
    store.setPinned(_selected.toList(), pin);
    setState(() => _selected.clear());
  }

  Future<void> _newFolder() async {
    final name = await promptText(context, title: 'Nova pasta');
    if (name != null && name.isNotEmpty) {
      final f = store.addFolder(name);
      store.setFolder(f.id);
    }
  }

  Future<void> _folderMenu(Folder f) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear pasta'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir pasta'),
              subtitle: const Text('As notas continuam, só ficam sem pasta'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || v == null) return;
    if (v == 'rename') {
      final name = await promptText(context, title: 'Renomear pasta', initial: f.name);
      if (name != null && name.isNotEmpty) store.renameFolder(f.id, name);
    } else if (v == 'delete') {
      final ok = await confirmDialog(
        context,
        title: 'Excluir pasta "${f.name}"?',
        message: 'As notas dela não serão apagadas.',
        action: 'Excluir',
      );
      if (ok) store.deleteFolder(f.id);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final notes = store.visible(_query);
        final pinned = notes.where((n) => n.pinned).toList();
        final others = notes.where((n) => !n.pinned).toList();
        final folderName = store.folderName(store.currentFolder);

        return PopScope(
          canPop: !_selecting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) setState(() => _selected.clear());
          },
          child: Scaffold(
            floatingActionButton: _selecting
                ? null
                : FloatingActionButton(
                    tooltip: 'Nova nota',
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _open(store.newNote(), isNew: true),
                    child: const Icon(Icons.edit),
                  ),
            bottomNavigationBar: _selecting ? _selectionBar() : null,
            body: CustomScrollView(
              slivers: [
                if (_selecting)
                  SliverAppBar(
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selected.clear()),
                    ),
                    title: Text(
                      _selected.length == 1
                          ? '1 selecionada'
                          : '${_selected.length} selecionadas',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(notes.map((n) => n.id));
                        }),
                        child: const Text('Todas'),
                      ),
                    ],
                  )
                else
                  SliverAppBar.large(
                    title: Text(folderName ?? 'Notas'),
                    actions: [
                      IconButton(
                        tooltip: store.gridView ? 'Ver em lista' : 'Ver em grade',
                        icon: Icon(store.gridView
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_outlined),
                        onPressed: () => store.setGrid(!store.gridView),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'trash':
                              Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => TrashScreen(store: store),
                              ));
                              break;
                            case 'save':
                              saveBackup(context, store);
                              break;
                            case 'restore':
                              restoreBackup(context, store);
                              break;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'trash', child: Text('Lixeira')),
                          PopupMenuItem(
                              value: 'save', child: Text('Salvar backup')),
                          PopupMenuItem(
                              value: 'restore',
                              child: Text('Restaurar backup')),
                        ],
                      ),
                    ],
                  ),
                SliverToBoxAdapter(child: _searchField()),
                SliverToBoxAdapter(child: _folderChips()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Text(
                      notes.length == 1 ? '1 nota' : '${notes.length} notas',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(140),
                      ),
                    ),
                  ),
                ),
                if (notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _empty(),
                  ),
                if (pinned.isNotEmpty) ..._section('Fixadas', pinned),
                if (others.isNotEmpty)
                  ..._section(pinned.isNotEmpty ? 'Outras' : null, others),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _empty() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 64, color: cs.onSurface.withAlpha(90)),
          const SizedBox(height: 12),
          Text(
            _query.isNotEmpty ? 'Nada encontrado' : 'Nenhuma nota ainda',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withAlpha(140),
            ),
          ),
          if (_query.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Toque no lápis para criar a primeira',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(110),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchField() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark(context)
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFEAEAEA),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: cs.onSurface.withAlpha(150)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Pesquisar notas',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() => _query = '');
                },
                child: Icon(Icons.close, color: cs.onSurface.withAlpha(150)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _folderChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Todas', store.currentFolder == null,
              () => store.setFolder(null)),
          for (final f in store.folders)
            _chip(
              f.name,
              store.currentFolder == f.id,
              () => store.setFolder(f.id),
              onLongPress: () => _folderMenu(f),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: _newFolder,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder(context)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 4),
                    Text('Pasta'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {VoidCallback? onLongPress}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? kAccent
                : (isDark(context)
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFEAEAEA)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(String? label, List<Note> items) {
    return [
      if (label != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      if (store.gridView)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (c, i) => _card(items[i], true),
              childCount: items.length,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (c, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(items[i], false),
              ),
              childCount: items.length,
            ),
          ),
        ),
    ];
  }

  Widget _card(Note n, bool grid) {
    final cs = Theme.of(context).colorScheme;
    final sel = _selected.contains(n.id);
    final bg = noteBg(context, n.colorIndex);
    final title = n.title.trim();
    final prev = n.preview;
    final showThumb = prev.isEmpty && n.hasDrawing;

    final footer = Row(
      children: [
        Text(
          fmtDate(n.updated),
          style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(130)),
        ),
        const Spacer(),
        if (n.hasDrawing)
          Icon(Icons.brush, size: 14, color: cs.onSurface.withAlpha(130)),
        if (n.hasChecklist)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.checklist,
                size: 16, color: cs.onSurface.withAlpha(130)),
          ),
        if (n.pinned)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.push_pin,
                size: 14, color: cs.onSurface.withAlpha(130)),
          ),
      ],
    );

    Widget? thumb;
    if (showThumb) {
      final b = n.blocks
          .firstWhere((b) => b.type == BlockType.draw && b.strokes.isNotEmpty);
      thumb = Center(
        child: AspectRatio(
          aspectRatio: 1 / (b.aspect <= 0 ? 1.0 : b.aspect),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: StrokesPainter(b.strokes, paper: Colors.white),
            ),
          ),
        ),
      );
    }

    final titleWidget = title.isEmpty
        ? null
        : Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          );

    final previewWidget = prev.isEmpty
        ? null
        : Text(
            prev,
            maxLines: grid ? 6 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: cs.onSurface.withAlpha(190),
            ),
          );

    final Widget content;
    if (grid) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null) titleWidget,
          if (titleWidget != null) const SizedBox(height: 6),
          Expanded(
            child: ClipRect(
              child: thumb ??
                  Align(
                    alignment: Alignment.topLeft,
                    child: previewWidget ?? const SizedBox.shrink(),
                  ),
            ),
          ),
          const SizedBox(height: 6),
          footer,
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titleWidget != null) titleWidget,
          if (titleWidget != null && (previewWidget != null || thumb != null))
            const SizedBox(height: 6),
          if (previewWidget != null) previewWidget,
          if (thumb != null) SizedBox(height: 110, child: thumb),
          const SizedBox(height: 10),
          footer,
        ],
      );
    }

    return GestureDetector(
      onTap: () => _selecting ? _toggle(n.id) : _open(n),
      onLongPress: () => _toggle(n.id),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: sel ? kAccent : cardBorder(context),
                width: sel ? 2.5 : 1,
              ),
            ),
            child: content,
          ),
          if (_selecting)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? kAccent : Colors.transparent,
                  border: Border.all(
                    color: sel ? kAccent : cs.onSurface.withAlpha(120),
                    width: 1.6,
                  ),
                ),
                child: sel
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    final cs = Theme.of(context).colorScheme;
    final sel = store.notes.where((n) => _selected.contains(n.id)).toList();
    final allPinned = sel.isNotEmpty && sel.every((n) => n.pinned);
    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _barBtn(
                allPinned ? Icons.push_pin : Icons.push_pin_outlined,
                allPinned ? 'Desafixar' : 'Fixar',
                () => _pinSelected(!allPinned),
              ),
              _barBtn(Icons.folder_outlined, 'Mover', _moveSelected),
              _barBtn(Icons.delete_outline, 'Excluir', _trashSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
