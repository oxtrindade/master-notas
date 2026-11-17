import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dialogs.dart';
import 'store.dart';
import 'util.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// Grava um arquivo .json com todas as notas e abre o menu de compartilhar
/// do Android (Google Drive, OneDrive, WhatsApp, e-mail...).
Future<void> saveBackup(BuildContext context, NotesStore store) async {
  try {
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name =
        'MasterNotas-backup-${d.year}-${_two(d.month)}-${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(store.exportJson(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: name)],
      subject: 'Backup Master Notas',
    );
  } catch (e) {
    if (context.mounted) snack(context, 'Não consegui gerar o backup: $e');
  }
}

/// Escolhe um arquivo de backup (do celular, Drive, OneDrive...) e restaura.
Future<void> restoreBackup(BuildContext context, NotesStore store) async {
  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;

    String text;
    if (f.bytes != null) {
      text = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      text = await File(f.path!).readAsString();
    } else {
      if (context.mounted) snack(context, 'Não consegui ler o arquivo');
      return;
    }

    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Restaurar backup?',
      message:
          'Isso substitui todas as notas atuais pelas do arquivo "${f.name}".',
      action: 'Restaurar',
    );
    if (!ok || !context.mounted) return;

    final done = store.importJson(text);
    snack(
      context,
      done ? 'Backup restaurado' : 'Esse arquivo não é um backup válido',
    );
  } catch (e) {
    if (context.mounted) snack(context, 'Não consegui restaurar: $e');
  }
}
