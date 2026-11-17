import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NotesStore();
  await store.load();
  runApp(NotesApp(store: store));
}

class NotesApp extends StatefulWidget {
  final NotesStore store;

  const NotesApp({super.key, required this.store});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O widget pode ter marcado itens com o app fechado: relê o arquivo.
    if (state == AppLifecycleState.resumed) {
      widget.store.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Master Notas',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeScreen(store: widget.store),
    );
  }
}
