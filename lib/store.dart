import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

const int kTrashDays = 30;

class NotesStore extends ChangeNotifier {
  static const MethodChannel _widgetChannel = MethodChannel('master_notas/widget');

  List<Note> notes = [];
  List<Folder> folders = [];
  bool gridView = true;
  String? currentFolder; // null = todas as notas

  File? _file;
  Timer? _debounce;

  // ---------------------------------------------------------------- carregar

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/master_notas.json');
      var ok = false;
      if (await _file!.exists()) {
        ok = await _tryRead(_file!);
      }
      if (!ok) {
        final bak = File('${_file!.path}.bak');
        if (await bak.exists()) await _tryRead(bak);
      }
    } catch (_) {
      // começa vazio se algo der errado
    }
    _purgeTrash();
    notifyListeners();
    _pokeWidget();
  }

  /// Relê o arquivo (ex.: o widget marcou um item enquanto o app estava fechado).
  Future<void> reload() async {
    final f = _file;
    if (f == null) return;
    if (_debounce?.isActive ?? false) return; // há alteração ainda não gravada
    try {
      if (await f.exists() && await _tryRead(f)) {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Avisa a parte nativa para redesenhar os widgets da tela inicial.
  Future<void> _pokeWidget() async {
    final f = _file;
    if (f == null) return;
    try {
      await _widgetChannel.invokeMethod<void>('refresh', {'path': f.path});
    } catch (_) {}
  }

  Future<bool> _tryRead(File f) async {
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _apply(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _apply(Map<String, dynamic> data) {
    folders = ((data['folders'] as List?) ?? const [])
        .map<Folder>((e) => Folder.fromJson(e as Map<String, dynamic>))
        .toList();
    notes = ((data['notes'] as List?) ?? const [])
        .map<Note>((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
    gridView = data['grid'] != false;
  }

  void _purgeTrash() {
    final limit = DateTime.now()
        .subtract(const Duration(days: kTrashDays))
        .millisecondsSinceEpoch;
    final before = notes.length;
    notes.removeWhere((n) => n.deletedAt != null && n.deletedAt! < limit);
    if (notes.length != before) _scheduleWrite();
  }

  // ----------------------------------------------------------------- salvar

  Map<String, dynamic> toJson() => {
        'v': 1,
        'grid': gridView,
        'folders': folders.map((f) => f.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  void _scheduleWrite() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _write);
  }

  Future<void> _write() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      if (await f.exists()) {
        try {
          await f.copy('${f.path}.bak');
        } catch (_) {}
      }
      await tmp.rename(f.path);
      _pokeWidget();
    } catch (_) {}
  }

  void _notify(bool defer) {
    if (defer) {
      scheduleMicrotask(notifyListeners);
    } else {
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ notas

  List<Note> get trash {
    final l = notes.where((n) => n.deletedAt != null).toList();
    l.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return l;
  }

  List<Note> visible(String query) {
    final q = query.trim().toLowerCase();
    final l = notes.where((n) {
      if (n.deletedAt != null) return false;
      if (currentFolder != null && n.folderId != currentFolder) return false;
      if (q.isNotEmpty && !n.searchText.contains(q)) return false;
      return true;
    }).toList();
    l.sort((a, b) => b.updated.compareTo(a.updated));
    return l;
  }

  Note newNote() => Note(folderId: currentFolder);

  /// Salva (ou adiciona) uma nota. Nota vazia é descartada.
  void saveNote(Note n, {bool touch = true, bool defer = false}) {
    if (n.isEmpty) {
      final removed = notes.any((x) => x.id == n.id);
      notes.removeWhere((x) => x.id == n.id);
      if (removed) {
        _scheduleWrite();
        _notify(defer);
      }
      return;
    }
    if (touch) n.updated = DateTime.now().millisecondsSinceEpoch;
    final i = notes.indexWhere((x) => x.id == n.id);
    if (i >= 0) {
      notes[i] = n;
    } else {
      notes.add(n);
    }
    _scheduleWrite();
    _notify(defer);
  }

  void trashNotes(Iterable<String> ids) {
    final set = ids.toSet();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final n in notes) {
      if (set.contains(n.id)) n.deletedAt = now;
    }
    _scheduleWrite();
    notifyListeners();
  }

  void restoreNotes(Iterable<String> ids) {
    final set = ids.toSet();
    for (final n in notes) {
      if (set.contains(n.id)) n.deletedAt = null;
    }
    _scheduleWrite();
    notifyListeners();
  }

  void deleteForever(String id) {
    notes.removeWhere((n) => n.id == id);
    _scheduleWrite();
    notifyListeners();
  }

  void emptyTrash() {
    notes.removeWhere((n) => n.deletedAt != null);
    _scheduleWrite();
    notifyListeners();
  }

  void setPinned(Iterable<String> ids, bool pinned) {
    final set = ids.toSet();
    for (final n in notes) {
      if (set.contains(n.id)) n.pinned = pinned;
    }
    _scheduleWrite();
    notifyListeners();
  }

  void moveNotes(Iterable<String> ids, String? folderId) {
    final set = ids.toSet();
    for (final n in notes) {
      if (set.contains(n.id)) n.folderId = folderId;
    }
    _scheduleWrite();
    notifyListeners();
  }

  // ----------------------------------------------------------------- pastas

  String? folderName(String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f.name;
    }
    return null;
  }

  Folder addFolder(String name) {
    final f = Folder(name: name);
    folders.add(f);
    _scheduleWrite();
    notifyListeners();
    return f;
  }

  void renameFolder(String id, String name) {
    for (final f in folders) {
      if (f.id == id) f.name = name;
    }
    _scheduleWrite();
    notifyListeners();
  }

  void deleteFolder(String id) {
    folders.removeWhere((f) => f.id == id);
    for (final n in notes) {
      if (n.folderId == id) n.folderId = null;
    }
    if (currentFolder == id) currentFolder = null;
    _scheduleWrite();
    notifyListeners();
  }

  void setFolder(String? id) {
    currentFolder = id;
    notifyListeners();
  }

  void setGrid(bool v) {
    gridView = v;
    _scheduleWrite();
    notifyListeners();
  }

  // ----------------------------------------------------------------- backup

  String exportJson() => jsonEncode(toJson());

  /// Substitui tudo pelo conteúdo do backup. Retorna false se inválido.
  bool importJson(String text) {
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['notes'] is! List) return false;
      _apply(data);
      currentFolder = null;
      _scheduleWrite();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
