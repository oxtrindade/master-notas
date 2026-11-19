import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// Backup automático numa pasta escolhida pelo usuário no seletor do Android.
/// O Android guarda a permissão da pasta, então só escolhe uma vez.
class FolderBackup extends ChangeNotifier {
  static const MethodChannel _ch = MethodChannel('master_notas/files');
  static const String fileName = 'MasterNotas-backup.json';

  final NotesStore store;

  FolderBackup(this.store);

  String treeUri = '';
  String folderName = '';
  bool auto = true;
  int last = 0;

  bool busy = false;
  String? error;

  File? _file;
  Timer? _timer;

  bool get hasFolder => treeUri.isNotEmpty;

  // ------------------------------------------------------------ configuração

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/master_notas_folder.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        treeUri = (j['uri'] as String?) ?? '';
        folderName = (j['name'] as String?) ?? '';
        auto = j['auto'] != false;
        last = (j['last'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString(
        jsonEncode({
          'uri': treeUri,
          'name': folderName,
          'auto': auto,
          'last': last,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> setAuto(bool v) async {
    auto = v;
    await _save();
    notifyListeners();
    if (v) scheduleSave(delay: const Duration(seconds: 1));
  }

  // ------------------------------------------------------------------ pasta

  /// Abre o seletor de pastas do Android. Se escolheu, já grava uma cópia.
  Future<void> pickFolder() async {
    error = null;
    notifyListeners();
    try {
      final r = await _ch.invokeMapMethod<String, String>('pickFolder');
      if (r == null) return; // cancelou
      final oldUri = treeUri;
      treeUri = r['uri'] ?? '';
      folderName = r['name'] ?? '';
      await _save();
      notifyListeners();
      if (oldUri.isNotEmpty && oldUri != treeUri) {
        try {
          await _ch.invokeMethod<void>('releaseFolder', {'uri': oldUri});
        } catch (_) {}
      }
      await saveNow();
    } on PlatformException catch (e) {
      error = e.message ?? 'Não consegui abrir o seletor de pastas.';
      notifyListeners();
    } catch (e) {
      error = 'Erro: $e';
      notifyListeners();
    }
  }

  Future<void> forgetFolder() async {
    final old = treeUri;
    _timer?.cancel();
    treeUri = '';
    folderName = '';
    last = 0;
    error = null;
    await _save();
    notifyListeners();
    if (old.isNotEmpty) {
      try {
        await _ch.invokeMethod<void>('releaseFolder', {'uri': old});
      } catch (_) {}
    }
  }

  // ----------------------------------------------------------------- gravar

  void scheduleSave({Duration delay = const Duration(seconds: 5)}) {
    if (!hasFolder || !auto) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      saveNow();
    });
  }

  Future<bool> saveNow() async {
    if (!hasFolder || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    var ok = false;
    try {
      await _ch.invokeMethod<bool>('saveToFolder', {
        'uri': treeUri,
        'name': fileName,
        'text': store.exportJson(),
      });
      last = DateTime.now().millisecondsSinceEpoch;
      await _save();
      ok = true;
    } on PlatformException catch (e) {
      error = e.message ?? 'Não consegui gravar na pasta.';
    } catch (e) {
      error = 'Erro: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
    return ok;
  }

  /// Lê o arquivo de backup da pasta. Retorna null se ele não existe ainda.
  Future<String?> readBackup() async {
    if (!hasFolder) return null;
    try {
      return await _ch.invokeMethod<String>('readFromFolder', {
        'uri': treeUri,
        'name': fileName,
      });
    } on PlatformException catch (e) {
      error = e.message ?? 'Não consegui ler a pasta.';
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
