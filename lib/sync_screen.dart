import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sync.dart';
import 'theme.dart';
import 'util.dart';

class SyncScreen extends StatefulWidget {
  final DriveSync sync;

  const SyncScreen({super.key, required this.sync});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final TextEditingController _id;
  late final TextEditingController _secret;

  DriveSync get sync => widget.sync;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: sync.clientId);
    _secret = TextEditingController(text: sync.clientSecret);
  }

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await sync.setClient(_id.text, _secret.text);
    if (mounted) snack(context, 'Salvo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: ListenableBuilder(
        listenable: sync,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _intro(context),
              const SizedBox(height: 16),
              if (sync.signedIn) ..._signedIn(context) else ..._signedOut(context),
              if (sync.error != null) ...[
                const SizedBox(height: 16),
                _errorBox(context, sync.error!),
              ],
              const SizedBox(height: 16),
              _help(context),
            ],
          );
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark(context) ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_sync_outlined, color: cs.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'As notas são guardadas numa pasta privada do app no seu Google '
              'Drive. Só este app enxerga essa pasta (ela não aparece nos seus '
              'arquivos). Em vários aparelhos, entre com a mesma conta e as '
              'notas ficam iguais.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- sem login

  List<Widget> _signedOut(BuildContext context) {
    final p = sync.pending;
    return [
      const Text('1. Dados do seu projeto Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _id,
        enabled: p == null,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'ID do cliente',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _secret,
        enabled: p == null,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Chave secreta do cliente',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: p == null ? _saveClient : null,
          child: const Text('Salvar'),
        ),
      ),
      const SizedBox(height: 20),
      const Text('2. Entrar com o Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (p == null)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: sync.configured
                ? () async {
                    await sync.setClient(_id.text, _secret.text);
                    sync.signIn();
                  }
                : null,
            icon: const Icon(Icons.login),
            label: const Text('Entrar'),
          ),
        )
      else
        _codeBox(context, p),
    ];
  }

  Widget _codeBox(BuildContext context, DeviceCode p) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Abra este endereço no navegador do celular:'),
          const SizedBox(height: 4),
          SelectableText(
            p.verificationUrl,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Text('e digite este código:'),
          const SizedBox(height: 4),
          SelectableText(
            p.userCode,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.userCode));
                  snack(context, 'Código copiado');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar código'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: sync.cancelSignIn,
                child: const Text('Cancelar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aguardando você autorizar. Esta tela continua sozinha '
                  'depois.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- com login

  List<Widget> _signedIn(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = sync.lastSync == 0
        ? 'ainda não sincronizou'
        : fmtDate(sync.lastSync);
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark(context) ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sync.email.isEmpty ? 'Conectado' : 'Conectado: ${sync.email}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Última sincronização: $last',
              style: TextStyle(color: cs.onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sincronizar automaticamente'),
        subtitle: const Text('Ao abrir o app e depois de cada alteração'),
        value: sync.auto,
        onChanged: (v) => sync.setAuto(v),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          FilledButton.icon(
            onPressed: sync.busy ? null : () => sync.syncNow(),
            icon: sync.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(sync.busy ? 'Sincronizando...' : 'Sincronizar agora'),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: sync.busy ? null : () => _confirmSignOut(context),
            child: const Text('Sair'),
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do Google Drive?'),
        content: const Text(
            'As notas continuam neste aparelho e na nuvem. Só para de sincronizar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await sync.signOut();
  }

  Widget _errorBox(BuildContext context, String msg) {
    return Container(
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
          Expanded(child: SelectableText(msg)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ ajuda

  Widget _help(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder(context)),
      ),
      child: const ExpansionTile(
        shape: Border(),
        collapsedShape: Border(),
        title: Text('Como conseguir o ID e a chave (uma vez só)'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Você faz isso no computador ou no navegador do celular, em '
            'console.cloud.google.com, com a sua conta Google:\n\n'
            '1. Crie um projeto (ex.: "Master Notas").\n\n'
            '2. Em "APIs e serviços" > "Biblioteca", procure Google Drive API '
            'e toque em Ativar.\n\n'
            '3. Abra "Google Auth Platform" (antiga "Tela de permissão OAuth") '
            'e configure: nome do app "Master Notas", seu e-mail, público '
            '"Externo".\n\n'
            '4. Em "Acesso a dados", adicione o escopo '
            'https://www.googleapis.com/auth/drive.appdata\n\n'
            '5. Em "Público", publique o app (status "Em produção"). Se '
            'deixar em "Teste", o login vence a cada 7 dias e seu e-mail '
            'precisa estar em "Usuários de teste".\n\n'
            '6. Em "Clientes", toque em Criar cliente, tipo "TVs e '
            'dispositivos de entrada limitada". Copie o ID do cliente e a '
            'chave secreta para os campos acima.\n\n'
            'Os nomes dos menus podem variar um pouco. O passo a passo '
            'completo está no arquivo docs/google-drive.md do projeto.',
            style: TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }
}
