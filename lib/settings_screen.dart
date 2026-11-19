import 'package:flutter/material.dart';

import 'backup.dart';
import 'folder_backup.dart';
import 'folder_backup_screen.dart';
import 'store.dart';
import 'sync.dart';
import 'sync_screen.dart';
import 'trash.dart';
import 'util.dart';

const String kAppVersion = '1.5.0';

/// Tela de configurações no estilo do Samsung Notes (One UI):
/// fundo cinza, grupos brancos de cantos bem arredondados.
class SettingsScreen extends StatelessWidget {
  final NotesStore store;
  final DriveSync sync;
  final FolderBackup folder;

  const SettingsScreen({
    super.key,
    required this.store,
    required this.sync,
    required this.folder,
  });

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final bg = dark ? Colors.black : const Color(0xFFF2F2F4);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Configurações'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, sync, folder]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _group(context, [
                _Row(
                  icon: Icons.folder_special_outlined,
                  title: 'Backup em pasta',
                  subtitle: folder.hasFolder
                      ? '${folder.folderName} · ${folder.auto ? 'automático' : 'manual'}'
                      : 'Escolher uma pasta (Drive, por exemplo)',
                  onTap: () => _go(
                      context, FolderBackupScreen(store: store, folder: folder)),
                ),
                _Row(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Sincronizar com o Google Drive',
                  subtitle: sync.signedIn
                      ? (sync.email.isEmpty ? 'Conectado' : sync.email)
                      : 'Desconectado',
                  onTap: () => _go(context, SyncScreen(sync: sync)),
                ),
              ]),
              _group(context, [
                _Row(
                  icon: Icons.ios_share,
                  title: 'Salvar backup',
                  subtitle: 'Enviar um arquivo pelo compartilhar do Android',
                  onTap: () => saveBackup(context, store),
                ),
                _Row(
                  icon: Icons.settings_backup_restore,
                  title: 'Restaurar backup',
                  subtitle: 'Escolher um arquivo .json',
                  onTap: () => restoreBackup(context, store),
                ),
              ]),
              _group(context, [
                _Row(
                  icon: Icons.grid_view_outlined,
                  title: 'Exibir notas em grade',
                  switchValue: store.gridView,
                  onSwitch: (v) => store.setGrid(v),
                ),
                _Row(
                  icon: Icons.delete_outline,
                  title: 'Lixeira',
                  subtitle: 'Notas apagadas ficam 30 dias',
                  onTap: () => _go(context, TrashScreen(store: store)),
                ),
              ]),
              _group(context, [
                const _Row(
                  icon: Icons.info_outline,
                  title: 'Sobre o Master Notas',
                  subtitle: 'Versão $kAppVersion',
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _group(BuildContext context, List<_Row> rows) {
    final dark = isDark(context);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(Divider(
          height: 1,
          indent: 64,
          endIndent: 16,
          color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEAEAEC),
        ));
      }
      children.add(rows[i]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.switchValue,
    this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSwitch = switchValue != null;
    return InkWell(
      onTap: isSwitch ? () => onSwitch?.call(!switchValue!) : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: cs.onSurface.withAlpha(190)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16.5)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurface.withAlpha(140)),
                      ),
                    ),
                ],
              ),
            ),
            if (isSwitch) Switch(value: switchValue!, onChanged: onSwitch),
          ],
        ),
      ),
    );
  }
}
