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
