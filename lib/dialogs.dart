import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

class FolderChoice {
  final String? id;
  const FolderChoice(this.id);
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Confirmar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return r == true;
}

Future<FolderChoice?> pickFolder(
  BuildContext context,
  NotesStore store, {
  String? current,
}) {
  return showModalBottomSheet<FolderChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Mover para',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('Sem pasta'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, const FolderChoice(null)),
          ),
          for (final Folder f in store.folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f.name),
              trailing: current == f.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, FolderChoice(f.id)),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Nova pasta'),
            onTap: () async {
              final name = await promptText(ctx, title: 'Nova pasta');
              if (name != null && name.isNotEmpty) {
                final f = store.addFolder(name);
                if (ctx.mounted) Navigator.pop(ctx, FolderChoice(f.id));
              }
            },
          ),
        ],
      ),
    ),
  );
}

Future<int?> pickNoteColor(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cor da nota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (int i = 0; i < kNoteColors.length; i++)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: noteBg(ctx, i),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == current ? kAccent : cardBorder(ctx),
                          width: i == current ? 3 : 1.5,
                        ),
                      ),
                      child: i == current
                          ? const Icon(Icons.check, size: 20, color: kAccent)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Retorna o número da capa (0 = sem capa) ou null se cancelar.
Future<int?> pickCover(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capa da nota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: current == 0 ? kAccent : cardBorder(ctx),
                        width: current == 0 ? 3 : 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Sem capa'),
                  ),
                ),
                for (int i = 1; i <= kCovers.length; i++)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, i),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: current == i
                            ? Border.all(color: kAccent, width: 3)
                            : null,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                                current == i ? 11 : 14),
                            child: coverBanner(i, height: double.infinity)!,
                          ),
                          Positioned(
                            left: 8,
                            bottom: 6,
                            child: Text(
                              kCovers[i - 1].name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
