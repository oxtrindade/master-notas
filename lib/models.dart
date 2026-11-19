import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

/// Traço de desenho. Coordenadas e espessura são normalizadas pela largura
/// da área de desenho, assim o desenho escala em qualquer tamanho de tela.
class Stroke {
  int color;
  double width;
  bool highlighter;
  List<double> pts; // x0, y0, x1, y1, ...

  Stroke({
    required this.color,
    required this.width,
    this.highlighter = false,
    List<double>? pts,
  }) : pts = pts ?? <double>[];

  Map<String, dynamic> toJson() => {
        'c': color,
        'w': double.parse(width.toStringAsFixed(5)),
        'h': highlighter,
        'p': pts.map((v) => double.parse(v.toStringAsFixed(4))).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        color: j['c'] as int,
        width: (j['w'] as num).toDouble(),
        highlighter: j['h'] == true,
        pts: ((j['p'] as List?) ?? const [])
            .map<double>((v) => (v as num).toDouble())
            .toList(),
      );
}

enum BlockType { text, check, draw }

class Block {
  String id;
  BlockType type;
  String text;
  bool checked;
  List<Stroke> strokes;
  double aspect; // altura / largura do desenho

  Block({
    String? id,
    required this.type,
    this.text = '',
    this.checked = false,
    List<Stroke>? strokes,
    this.aspect = 1.0,
  })  : id = id ?? newId(),
        strokes = strokes ?? <Stroke>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        't': type.name,
        'x': text,
        'k': checked,
        's': strokes.map((s) => s.toJson()).toList(),
        'a': aspect,
      };

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        id: j['id'] as String?,
        type: BlockType.values.firstWhere(
          (e) => e.name == j['t'],
          orElse: () => BlockType.text,
        ),
        text: (j['x'] as String?) ?? '',
        checked: j['k'] == true,
        strokes: ((j['s'] as List?) ?? const [])
            .map<Stroke>((e) => Stroke.fromJson(e as Map<String, dynamic>))
            .toList(),
        aspect: ((j['a'] as num?) ?? 1.0).toDouble(),
      );
}

class Folder {
  String id;
  String name;

  Folder({String? id, required this.name}) : id = id ?? newId();

  Map<String, dynamic> toJson() => {'id': id, 'n': name};

  factory Folder.fromJson(Map<String, dynamic> j) =>
      Folder(id: j['id'] as String?, name: (j['n'] as String?) ?? 'Pasta');
}

class Note {
  String id;
  String title;
  List<Block> blocks;
  int colorIndex;
  int cover; // 0 = sem capa
  bool pinned;
  String? folderId;
  int created;
  int updated;
  int? deletedAt;

  Note({
    String? id,
    this.title = '',
    List<Block>? blocks,
    this.colorIndex = 0,
    this.cover = 0,
    this.pinned = false,
    this.folderId,
    int? created,
    int? updated,
    this.deletedAt,
  })  : id = id ?? newId(),
        blocks = blocks ?? <Block>[Block(type: BlockType.text)],
        created = created ?? DateTime.now().millisecondsSinceEpoch,
        updated = updated ?? DateTime.now().millisecondsSinceEpoch;

  bool get isEmpty =>
      title.trim().isEmpty &&
      blocks.every((b) => b.type == BlockType.draw
          ? b.strokes.isEmpty
          : b.text.trim().isEmpty);

  bool get hasChecklist => blocks.any((b) => b.type == BlockType.check);

  bool get hasDrawing =>
      blocks.any((b) => b.type == BlockType.draw && b.strokes.isNotEmpty);

  /// Texto simples para prévia e para copiar.
  String get plainText {
    final lines = <String>[];
    for (final b in blocks) {
      if (b.type == BlockType.draw) continue;
      if (b.type == BlockType.check) {
        if (b.text.trim().isEmpty) continue;
        lines.add('${b.checked ? "☑" : "☐"} ${b.text.trim()}');
      } else {
        if (b.text.trim().isEmpty) continue;
        lines.add(b.text.trim());
      }
    }
    return lines.join('\n');
  }

  String get preview {
    final t = plainText;
    return t.length > 400 ? t.substring(0, 400) : t;
  }

  String get searchText {
    final parts = <String>[title];
    for (final b in blocks) {
      if (b.type != BlockType.draw) parts.add(b.text);
    }
    return parts.join('\n').toLowerCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'color': colorIndex,
        'cv': cover,
        'pin': pinned,
        'folder': folderId,
        'created': created,
        'updated': updated,
        'deleted': deletedAt,
      };

  factory Note.fromJson(Map<String, dynamic> j) {
    final bl = ((j['blocks'] as List?) ?? const [])
        .map<Block>((e) => Block.fromJson(e as Map<String, dynamic>))
        .toList();
    return Note(
      id: j['id'] as String?,
      title: (j['title'] as String?) ?? '',
      blocks: bl.isEmpty ? <Block>[Block(type: BlockType.text)] : bl,
      colorIndex: (j['color'] as int?) ?? 0,
      cover: (j['cv'] as int?) ?? 0,
      pinned: j['pin'] == true,
      folderId: j['folder'] as String?,
      created: j['created'] as int?,
      updated: j['updated'] as int?,
      deletedAt: j['deleted'] as int?,
    );
  }
}
