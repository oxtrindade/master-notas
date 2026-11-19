import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'store.dart';

const String _scope = 'https://www.googleapis.com/auth/drive.appdata email';
const String _driveFileName = 'master_notas_sync.json';
const Duration _timeout = Duration(seconds: 40);

final Uri _deviceUri = Uri.parse('https://oauth2.googleapis.com/device/code');
final Uri _tokenUri = Uri.parse('https://oauth2.googleapis.com/token');

class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => message;
}

class DeviceCode {
  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int expiresIn;
  final int interval;

  DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });
}

/// Login com a conta Google (fluxo por código) e sincronização das notas com a
/// pasta privada do app no Google Drive (drive.appdata).
class DriveSync extends ChangeNotifier {
  final NotesStore store;

  DriveSync(this.store);

  String clientId = '';
  String clientSecret = '';
  String refreshToken = '';
  String email = '';
  int lastSync = 0;
  bool auto = true;

  bool busy = false;
  String? error;
  DeviceCode? pending;

  bool _cancelLogin = false;
  bool _again = false;
  String? _accessToken;
  DateTime? _accessExpiry;
  File? _file;
  Timer? _timer;

  bool get configured => clientId.isNotEmpty && clientSecret.isNotEmpty;
  bool get signedIn => refreshToken.isNotEmpty;

  // ------------------------------------------------------------ configuração

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/master_notas_sync.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        clientId = (j['clientId'] as String?) ?? '';
        clientSecret = (j['clientSecret'] as String?) ?? '';
        refreshToken = (j['refreshToken'] as String?) ?? '';
        email = (j['email'] as String?) ?? '';
        lastSync = (j['lastSync'] as num?)?.toInt() ?? 0;
        auto = j['auto'] != false;
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
          'clientId': clientId,
          'clientSecret': clientSecret,
          'refreshToken': refreshToken,
          'email': email,
          'lastSync': lastSync,
          'auto': auto,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> setClient(String id, String secret) async {
    final newId = id.trim();
    final newSecret = secret.trim();
    if (newId != clientId || newSecret != clientSecret) {
      // credenciais novas: o login antigo não vale mais
      refreshToken = '';
      email = '';
      _accessToken = null;
    }
    clientId = newId;
    clientSecret = newSecret;
    error = null;
    await _save();
    notifyListeners();
  }

  Future<void> setAuto(bool v) async {
    auto = v;
    await _save();
    notifyListeners();
    if (v) scheduleSync(delay: const Duration(seconds: 1));
  }

  // ------------------------------------------------------------------ login

  Future<void> signIn() async {
    if (!configured || pending != null) return;
    error = null;
    _cancelLogin = false;
    notifyListeners();
    try {
      final r = await http
          .post(_deviceUri, body: {'client_id': clientId, 'scope': _scope})
          .timeout(_timeout);
      final j = _decode(r);
      if (r.statusCode != 200 || j['device_code'] == null) {
        throw SyncException(_googleError(r, j));
      }
      final code = DeviceCode(
        deviceCode: j['device_code'] as String,
        userCode: j['user_code'] as String,
        verificationUrl: (j['verification_url'] as String?) ??
            (j['verification_uri'] as String?) ??
            'https://www.google.com/device',
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 600,
        interval: (j['interval'] as num?)?.toInt() ?? 5,
      );
      pending = code;
      notifyListeners();

      var interval = code.interval < 5 ? 5 : code.interval;
      final deadline = DateTime.now().add(Duration(seconds: code.expiresIn));
      while (!_cancelLogin && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(Duration(seconds: interval));
        if (_cancelLogin) break;
        final t = await http.post(_tokenUri, body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        }).timeout(_timeout);
        final tj = _decode(t);
        if (t.statusCode == 200 && tj['refresh_token'] != null) {
          refreshToken = tj['refresh_token'] as String;
          _accessToken = tj['access_token'] as String?;
          final secs = (tj['expires_in'] as num?)?.toInt() ?? 3000;
          _accessExpiry = DateTime.now().add(Duration(seconds: secs));
          await _fetchEmail();
          await _save();
          pending = null;
          notifyListeners();
          unawaited(syncNow());
          return;
        }
        final err = tj['error'];
        if (err == 'authorization_pending') continue;
        if (err == 'slow_down') {
          interval += 5;
          continue;
        }
        if (err == 'access_denied') {
          throw SyncException('Você não autorizou o acesso. Tente entrar de novo.');
        }
        throw SyncException(_googleError(t, tj));
      }
      if (!_cancelLogin) {
        throw SyncException('O código expirou. Toque em Entrar e tente de novo.');
      }
    } catch (e) {
      error = _friendly(e);
    } finally {
      pending = null;
      notifyListeners();
    }
  }

  void cancelSignIn() {
    _cancelLogin = true;
    pending = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    final tok = refreshToken;
    _timer?.cancel();
    refreshToken = '';
    email = '';
    _accessToken = null;
    _accessExpiry = null;
    error = null;
    await _save();
    notifyListeners();
    if (tok.isNotEmpty) {
      try {
        await http
            .post(Uri.parse('https://oauth2.googleapis.com/revoke'),
                body: {'token': tok})
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
  }

  Future<void> _fetchEmail() async {
    try {
      final r = await http
          .get(
            Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
            headers: {'Authorization': 'Bearer $_accessToken'},
          )
          .timeout(_timeout);
      if (r.statusCode == 200) {
        email = (_decode(r)['email'] as String?) ?? '';
      }
    } catch (_) {}
  }

  Future<String> _token() async {
    final exp = _accessExpiry;
    if (_accessToken != null &&
        exp != null &&
        DateTime.now().isBefore(exp.subtract(const Duration(minutes: 1)))) {
      return _accessToken!;
    }
    final r = await http.post(_tokenUri, body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    }).timeout(_timeout);
    final j = _decode(r);
    if (r.statusCode != 200 || j['access_token'] == null) {
      if (j['error'] == 'invalid_grant') {
        refreshToken = '';
        email = '';
        _accessToken = null;
        await _save();
        throw SyncException(
            'O login do Google venceu ou foi revogado. Entre de novo.');
      }
      throw SyncException(_googleError(r, j));
    }
    _accessToken = j['access_token'] as String;
    final secs = (j['expires_in'] as num?)?.toInt() ?? 3000;
    _accessExpiry = DateTime.now().add(Duration(seconds: secs));
    return _accessToken!;
  }

  // ------------------------------------------------------------ sincronizar

  /// Agenda uma sincronização (junta várias alterações seguidas em uma).
  void scheduleSync({Duration delay = const Duration(seconds: 8)}) {
    if (!signedIn || !auto) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      syncNow();
    });
  }

  Future<bool> syncNow() async {
    if (!signedIn) return false;
    if (busy) {
      _again = true;
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    var ok = false;
    try {
      final token = await _token();
      final h = {'Authorization': 'Bearer $token'};

      var id = await _findFileId(h);
      String? remoteRaw;
      Map<String, dynamic>? remote;
      if (id != null) {
        final r = await http
            .get(
              Uri.https('www.googleapis.com', '/drive/v3/files/$id',
                  {'alt': 'media'}),
              headers: h,
            )
            .timeout(_timeout);
        _check(r);
        remoteRaw = utf8.decode(r.bodyBytes);
        try {
          final d = jsonDecode(remoteRaw);
          if (d is Map<String, dynamic>) remote = d;
        } catch (_) {}
      }

      if (remote != null) store.mergeFrom(remote);

      final local = jsonEncode(store.syncJson());
      if (remoteRaw == null || local != remoteRaw) {
        id ??= await _createFile(h);
        final up = await http
            .patch(
              Uri.https('www.googleapis.com', '/upload/drive/v3/files/$id',
                  {'uploadType': 'media'}),
              headers: {...h, 'Content-Type': 'application/json; charset=utf-8'},
              body: utf8.encode(local),
            )
            .timeout(_timeout);
        _check(up);
      }

      lastSync = DateTime.now().millisecondsSinceEpoch;
      await _save();
      ok = true;
    } catch (e) {
      error = _friendly(e);
    } finally {
      busy = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      scheduleSync(delay: const Duration(seconds: 2));
    }
    return ok;
  }

  Future<String?> _findFileId(Map<String, String> h) async {
    final r = await http
        .get(
          Uri.https('www.googleapis.com', '/drive/v3/files', {
            'spaces': 'appDataFolder',
            'fields': 'files(id,name)',
            'pageSize': '100',
          }),
          headers: h,
        )
        .timeout(_timeout);
    _check(r);
    final files = (_decode(r)['files'] as List?) ?? const [];
    for (final f in files) {
      if (f is Map && f['name'] == _driveFileName) return f['id'] as String?;
    }
    return null;
  }

  Future<String> _createFile(Map<String, String> h) async {
    final r = await http
        .post(
          Uri.https('www.googleapis.com', '/drive/v3/files'),
          headers: {...h, 'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'name': _driveFileName,
            'parents': ['appDataFolder'],
          }),
        )
        .timeout(_timeout);
    _check(r);
    final id = _decode(r)['id'] as String?;
    if (id == null) throw SyncException('O Google Drive não criou o arquivo.');
    return id;
  }

  // ---------------------------------------------------------------- utilidades

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _check(http.Response r) {
    if (r.statusCode < 400) return;
    if (r.statusCode == 401) _accessToken = null;
    throw SyncException(_googleError(r, _decode(r)));
  }

  String _googleError(http.Response r, Map<String, dynamic> j) {
    String? msg;
    final e = j['error'];
    if (e is Map) {
      msg = e['message'] as String?;
    } else if (e is String) {
      msg = (j['error_description'] as String?) ?? e;
    }
    if (msg != null && msg.contains('has not been used')) {
      return 'A API do Google Drive não está ativada no seu projeto do Google Cloud. '
          'Ative em "APIs e serviços" > "Biblioteca" > Google Drive API.';
    }
    if (e == 'invalid_client') {
      return 'ID do cliente ou chave secreta incorretos. Confira os dois e salve de novo.';
    }
    if (e == 'access_denied') {
      return 'Acesso negado pelo Google. Se o app está em "Teste", adicione seu e-mail em "Usuários de teste".';
    }
    return 'Google (${r.statusCode}): ${msg ?? 'erro desconhecido'}';
  }

  String _friendly(Object e) {
    if (e is SyncException) return e.message;
    if (e is TimeoutException) {
      return 'O Google demorou demais para responder. Tente de novo.';
    }
    if (e is SocketException || e is http.ClientException) {
      return 'Sem internet, ou o Google não respondeu.';
    }
    return 'Erro: $e';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
