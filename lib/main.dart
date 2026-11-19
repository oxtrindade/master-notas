import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'folder_backup.dart';
import 'home.dart';
import 'store.dart';
import 'sync.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NotesStore();
  await store.load();
  final sync = DriveSync(store);
  await sync.load();
  final folder = FolderBackup(store);
  await folder.load();
  store.onLocalChange = () {
    sync.scheduleSync();
    folder.scheduleSave();
  };
  sync.scheduleSync(delay: const Duration(seconds: 3));
  runApp(NotesApp(store: store, sync: sync, folder: folder));
}

class NotesApp extends StatefulWidget {
  final NotesStore store;
  final DriveSync sync;
  final FolderBackup folder;

  const NotesApp({
    super.key,
    required this.store,
    required this.sync,
    required this.folder,
  });

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
      widget.sync.scheduleSync(delay: const Duration(seconds: 1));
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
      home: HomeScreen(
        store: widget.store,
        sync: widget.sync,
        folder: widget.folder,
      ),
    );
  }
}
