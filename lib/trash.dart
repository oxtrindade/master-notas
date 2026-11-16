import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';

class TrashScreen extends StatelessWidget {
  final NotesStore store;

  const TrashScreen({super.key, required this.store});

  int _daysLeft(Note n) {
    final deleted = DateTime.fromMillisecondsSinceEpoch(n.deletedAt!);
    final used = DateTime.now().difference(deleted).inDays;
    final left = kTrashDays - used;
    return left < 0 ? 0 : left;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.trash;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lixeira'),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Esvaziar lixeira?',
                      message:
                          'As ${items.length} notas serão apagadas para sempre.',
                      action: 'Esvaziar',
                    );
                    if (ok) store.emptyTrash();
                  },
                  child: const Text('Esvaziar'),
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('A lixeira está vazia'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    final title = n.title.trim().isNotEmpty
                        ? n.title.trim()
                        : (n.preview.isNotEmpty
                            ? n.preview.split('\n').first
                            : (n.hasDrawing ? 'Desenho' : 'Nota vazia'));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: noteBg(context, n.colorIndex),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder(context)),
                      ),
                      child: ListTile(
                        title: Text(title, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'Apagada ${fmtDate(n.deletedAt!)} • some em ${_daysLeft(n)} dias',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restaurar',
                              icon: const Icon(Icons.restore),
                              onPressed: () {
                                store.restoreNotes([n.id]);
                                snack(context, 'Nota restaurada');
                              },
                            ),
                            IconButton(
                              tooltip: 'Apagar para sempre',
                              icon: const Icon(Icons.delete_forever_outlined),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Apagar para sempre?',
                                  message: 'Isso não pode ser desfeito.',
                                  action: 'Apagar',
                                );
                                if (ok) store.deleteForever(n.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
