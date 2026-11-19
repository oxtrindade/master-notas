import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'folder_backup.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';

class FolderBackupScreen extends StatelessWidget {
  final NotesStore store;
  final FolderBackup folder;

  const FolderBackupScreen({super.key, required this.store, required this.folder});

  Future<void> _restore(BuildContext context) async {
    final text = await folder.readBackup();
    if (!context.mounted) return;
    if (text == null) {
      snack(context, folder.error ?? 'Ainda não existe backup nesta pasta');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Restaurar desta pasta?',
      message: 'Isso substitui todas as notas atuais pelas do arquivo '
          '"${FolderBackup.fileName}".',
      action: 'Restaurar',
    );
    if (!ok || !context.mounted) return;
    final done = store.importJson(text);
    snack(context, done ? 'Backup restaurado' : 'O arquivo da pasta não é um backup válido');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup em pasta')),
      body: ListenableBuilder(
        listenable: folder,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _card(
                context,
                child: const Text(
                  'Escolha uma pasta no seletor do Android, uma vez só. O app '
                  'passa a gravar nela, sozinho, o arquivo '
                  '${FolderBackup.fileName} a cada alteração. Se a pasta '
                  'estiver dentro do Google Drive, o próprio Drive envia o '
                  'arquivo para a nuvem.',
                  style: TextStyle(height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              _card(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pasta',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurface.withAlpha(150))),
                    const SizedBox(height: 4),
                    Text(
                      folder.hasFolder ? folder.folderName : 'Nenhuma pasta escolhida',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: folder.busy ? null : folder.pickFolder,
                          icon: const Icon(Icons.folder_open),
                          label: Text(folder.hasFolder ? 'Trocar pasta' : 'Escolher pasta'),
                        ),
                        if (folder.hasFolder)
                          TextButton(
                            onPressed: folder.busy ? null : folder.forgetFolder,
                            child: const Text('Esquecer pasta'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (folder.hasFolder) ...[
                const SizedBox(height: 14),
                _card(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Salvar automaticamente'),
                        subtitle: const Text('Alguns segundos depois de cada alteração'),
                        value: folder.auto,
                        onChanged: (v) => folder.setAuto(v),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        folder.last == 0
                            ? 'Ainda não gravou'
                            : 'Última gravação: ${fmtDate(folder.last)}',
                        style: TextStyle(color: cs.onSurface.withAlpha(150)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: folder.busy ? null : () => folder.saveNow(),
                            icon: folder.busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_alt),
                            label: Text(folder.busy ? 'Gravando...' : 'Salvar agora'),
                          ),
                          OutlinedButton.icon(
                            onPressed: folder.busy ? null : () => _restore(context),
                            icon: const Icon(Icons.restore),
                            label: const Text('Restaurar desta pasta'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (folder.error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x1AE53935),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE53935)),
                      const SizedBox(width: 10),
                      Expanded(child: SelectableText(folder.error!)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _card(
                context,
                child: const Text(
                  'Como testar: escolha a pasta, toque em "Salvar agora" e '
                  'abra o app do Drive (ou o gerenciador de arquivos) para '
                  'ver se o arquivo apareceu. O envio para a nuvem pode levar '
                  'alguns instantes. Se o Android esquecer a permissão (por '
                  'exemplo ao apagar os dados do app), o app avisa e você '
                  'escolhe a pasta de novo.',
                  style: TextStyle(height: 1.4, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder(context)),
      ),
      child: child,
    );
  }
}
