import 'package:flutter/material.dart';

import 'util.dart';

const Color kAccent = Color(0xFF3E91FF);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: b),
    scaffoldBackgroundColor:
        dark ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
  );
}

class NoteColor {
  final Color light;
  final Color dark;
  const NoteColor(this.light, this.dark);
}

const List<NoteColor> kNoteColors = [
  NoteColor(Color(0xFFFFFFFF), Color(0xFF1C1C1E)), // padrão
  NoteColor(Color(0xFFFFF3C4), Color(0xFF4A4220)), // amarelo
  NoteColor(Color(0xFFFFDDC9), Color(0xFF4D3225)), // laranja
  NoteColor(Color(0xFFFFD6DD), Color(0xFF4F2830)), // rosa
  NoteColor(Color(0xFFE3D9FF), Color(0xFF38305C)), // roxo
  NoteColor(Color(0xFFD3E8FF), Color(0xFF243A56)), // azul
  NoteColor(Color(0xFFD2F2E4), Color(0xFF204A3A)), // verde
  NoteColor(Color(0xFFE5E5E5), Color(0xFF3A3A3C)), // cinza
];

Color noteBg(BuildContext context, int index) {
  final i = (index >= 0 && index < kNoteColors.length) ? index : 0;
  final dark = isDark(context);
  return dark ? kNoteColors[i].dark : kNoteColors[i].light;
}

Color cardBorder(BuildContext context) =>
    isDark(context) ? const Color(0x1FFFFFFF) : const Color(0x14000000);

// ------------------------------------------------------------------ capas

class CoverStyle {
  final String name;
  final Color a;
  final Color b;
  const CoverStyle(this.name, this.a, this.b);
}

/// Índice 0 do campo `cover` da nota = sem capa; 1..N = kCovers[i - 1].
const List<CoverStyle> kCovers = [
  CoverStyle('Oceano', Color(0xFF2193B0), Color(0xFF6DD5ED)),
  CoverStyle('Pôr do sol', Color(0xFFFF512F), Color(0xFFF09819)),
  CoverStyle('Floresta', Color(0xFF11998E), Color(0xFF38EF7D)),
  CoverStyle('Lavanda', Color(0xFF8E2DE2), Color(0xFF4A00E0)),
  CoverStyle('Rosa', Color(0xFFEE9CA7), Color(0xFFFFB6C1)),
  CoverStyle('Noite', Color(0xFF232526), Color(0xFF485563)),
  CoverStyle('Céu', Color(0xFF4568DC), Color(0xFFB06AB3)),
  CoverStyle('Menta', Color(0xFF00B09B), Color(0xFF96C93D)),
  CoverStyle('Vinho', Color(0xFF642B73), Color(0xFFC6426E)),
  CoverStyle('Areia', Color(0xFFD7BE82), Color(0xFFF3E7C8)),
  CoverStyle('Grafite', Color(0xFF485563), Color(0xFF29323C)),
  CoverStyle('Cereja', Color(0xFFEB3349), Color(0xFFF45C43)),
];

bool hasCover(int cover) => cover > 0 && cover <= kCovers.length;

/// Faixa colorida da capa. Retorna null se a nota não tem capa.
Widget? coverBanner(int cover, {double height = 44, BorderRadius? radius}) {
  if (!hasCover(cover)) return null;
  final c = kCovers[cover - 1];
  return Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.a, c.b],
      ),
    ),
  );
}
