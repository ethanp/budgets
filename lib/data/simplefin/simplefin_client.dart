import 'dart:convert';

import 'package:budgets/data/simplefin/simplefin_models.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:http/http.dart' as http;

const _logger = ELogger('SimpleFinClient');

const simpleFinCreateUrl = 'https://bridge.simplefin.org/simplefin/create';

class SimpleFinClient {
  SimpleFinClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<Uri> claimAccessUrl(String setupToken) async {
    final claimUrl = _decodeClaimUrl(setupToken);
    _logger.log('Claim POST ${_redactUri(claimUrl)}');

    final http.Response response;
    try {
      response = await _httpClient.post(
        claimUrl,
        headers: const {'Content-Length': '0'},
      );
    } catch (error, stackTrace) {
      _logger.error('Claim request failed', error, stackTrace);
      rethrow;
    }

    final accessUrlText = response.body.trim();
    final parsedAccessUrl = Uri.tryParse(accessUrlText);
    _logger.log(
      'Claim response HTTP ${response.statusCode}, '
      'body=${parsedAccessUrl != null && parsedAccessUrl.scheme == 'https' ? _redactUri(parsedAccessUrl) : _truncate(accessUrlText)}',
    );

    if (response.statusCode == 403) {
      throw SimpleFinClaimException(
        'Token invalid or already claimed — revoke in SimpleFIN and create a new one.',
        statusCode: 403,
      );
    }
    if (response.statusCode != 200) {
      throw SimpleFinClaimException(
        'Could not claim SimpleFIN token (HTTP ${response.statusCode}): '
        '${_truncate(response.body)}',
        statusCode: response.statusCode,
      );
    }

    if (parsedAccessUrl == null || parsedAccessUrl.scheme != 'https') {
      _logger.warn('Claim returned non-HTTPS Access URL');
      throw SimpleFinClaimException('SimpleFIN returned an invalid Access URL.');
    }
    _logger.log(
      'Claimed Access URL host=${parsedAccessUrl.host} '
      'path=${parsedAccessUrl.path} hasUserInfo=${parsedAccessUrl.userInfo.isNotEmpty}',
    );
    return parsedAccessUrl;
  }

  Future<SimpleFinAccountSet> fetchAccounts({
    required Uri accessUrl,
    DateTime? start,
    DateTime? end,
    bool pending = true,
  }) async {
    if (accessUrl.scheme != 'https') {
      throw SimpleFinFetchException('Access URL must use HTTPS.');
    }

    // beta-bridge: "exceeds recommended range of 45 days" for spans >= 45d.
    const maxSpanSeconds = 44 * 24 * 60 * 60;
    var startUnix = start == null ? null : start.millisecondsSinceEpoch ~/ 1000;
    final endUnix = end == null ? null : end.millisecondsSinceEpoch ~/ 1000;
    if (startUnix != null && endUnix != null && endUnix - startUnix > maxSpanSeconds) {
      final clampedStartUnix = endUnix - maxSpanSeconds;
      _logger.warn(
        'Clamping start-date from $startUnix to $clampedStartUnix '
        '(max span ${maxSpanSeconds}s)',
      );
      startUnix = clampedStartUnix;
    }

    final queryParameters = <String, String>{
      'version': '2',
      if (pending) 'pending': '1',
      if (startUnix != null) 'start-date': '$startUnix',
      if (endUnix != null) 'end-date': '$endUnix',
    };

    if (startUnix != null && endUnix != null) {
      final spanSeconds = endUnix - startUnix;
      _logger.log(
        'Fetch window startUnix=$startUnix endUnix=$endUnix '
        'spanSeconds=$spanSeconds spanDays≈${spanSeconds / 86400}',
      );
    }

    final accountsPath = _joinPath(accessUrl.path, 'accounts');
    final requestUrl = Uri(
      scheme: accessUrl.scheme,
      host: accessUrl.host,
      port: accessUrl.hasPort ? accessUrl.port : null,
      path: accountsPath,
      queryParameters: queryParameters,
    );

    final headers = <String, String>{};
    final basicAuth = _basicAuthHeader(accessUrl);
    if (basicAuth != null) {
      headers['Authorization'] = basicAuth;
    } else {
      _logger.warn('Access URL has no userInfo; request may be unauthorized');
    }

    _logger.log('GET ${_redactUri(requestUrl)} auth=${basicAuth != null}');

    final http.Response response;
    try {
      response = await _httpClient.get(requestUrl, headers: headers);
    } catch (error, stackTrace) {
      _logger.error('Fetch request failed', error, stackTrace);
      rethrow;
    }

    _logger.log(
      'Fetch response HTTP ${response.statusCode}, '
      'bytes=${response.bodyBytes.length}, body=${_truncate(response.body)}',
    );

    if (response.statusCode == 403) {
      throw SimpleFinFetchException(
        'SimpleFIN access revoked or invalid. Re-link your bank. '
        '${_truncate(response.body)}',
        statusCode: 403,
      );
    }
    if (response.statusCode == 402) {
      throw SimpleFinFetchException(
        'SimpleFIN subscription required. ${_truncate(response.body)}',
        statusCode: 402,
      );
    }

    final decoded = _tryDecodeJsonMap(response.body);
    if (decoded == null) {
      throw SimpleFinFetchException(
        'SimpleFIN fetch failed (HTTP ${response.statusCode}): '
        '${_truncate(response.body)}',
        statusCode: response.statusCode,
      );
    }

    // beta-bridge may return HTTP 400 with a normal Account Set + errlist
    // (e.g. date-range warning, no connections). Prefer surfacing errlist.
    if (response.statusCode != 200) {
      _logger.warn(
        'Non-200 Account Set HTTP ${response.statusCode}; parsing body anyway',
      );
    }

    final accountSet = parseAccountSet(decoded);
    _logger.log(
      'Parsed accounts=${accountSet.accounts.length} '
      'transactions=${accountSet.accounts.fold<int>(0, (sum, account) => sum + account.transactions.length)} '
      'errors=${accountSet.errors.length}',
    );
    for (final error in accountSet.errors) {
      _logger.warn('errlist ${error.code}: ${error.message}');
    }
    return accountSet;
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Visible for tests.
  static SimpleFinAccountSet parseAccountSet(Map<String, dynamic> json) {
    final errlist = (json['errlist'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SimpleFinError.fromJson)
        .toList();

    final accounts = (json['accounts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_parseAccount)
        .toList();

    return SimpleFinAccountSet(errors: errlist, accounts: accounts);
  }

  static SimpleFinAccount _parseAccount(Map<String, dynamic> json) {
    final transactions = (json['transactions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_parseTransaction)
        .toList();

    return SimpleFinAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Account',
      currency: json['currency'] as String? ?? 'USD',
      balance: json['balance']?.toString() ?? '0',
      availableBalance: json['available-balance']?.toString(),
      balanceDate: _asInt(json['balance-date']),
      connId: json['conn_id'] as String?,
      connName: json['conn_name'] as String?,
      transactions: transactions,
    );
  }

  static SimpleFinTransaction _parseTransaction(Map<String, dynamic> json) {
    return SimpleFinTransaction(
      id: json['id'] as String? ?? '',
      posted: _asInt(json['posted']),
      amount: json['amount']?.toString() ?? '0',
      description: json['description'] as String? ?? '',
      pending: json['pending'] == true,
    );
  }

  Uri _decodeClaimUrl(String setupToken) {
    final cleaned = _cleanPastedToken(setupToken);
    _logger.log(
      'Decode Setup Token chars=${cleaned.length} '
      'prefix=${cleaned.length > 8 ? cleaned.substring(0, 8) : cleaned}',
    );
    if (cleaned.isEmpty) {
      throw SimpleFinClaimException('Paste a SimpleFIN Setup Token.');
    }

    if (cleaned.startsWith('https://')) {
      final claimUrl = Uri.tryParse(cleaned);
      if (claimUrl == null || claimUrl.scheme != 'https') {
        throw SimpleFinClaimException('Claim URL must use HTTPS.');
      }
      _logger.log('Setup Token was already an HTTPS URL');
      return claimUrl;
    }

    try {
      final decoded = utf8.decode(_decodeBase64Flexible(cleaned));
      final claimUrl = Uri.parse(decoded.trim());
      if (claimUrl.scheme != 'https') {
        throw SimpleFinClaimException(
          'Decoded token is not an HTTPS claim URL (got ${claimUrl.scheme}).',
        );
      }
      _logger.log('Decoded claim URL ${_redactUri(claimUrl)}');
      return claimUrl;
    } on SimpleFinClaimException {
      rethrow;
    } catch (error) {
      _logger.warn('Failed to decode Setup Token: $error');
      throw SimpleFinClaimException(
        'Could not decode Setup Token. Copy the full token from SimpleFIN '
        '(base64, often starts with aHR0). Error: $error',
      );
    }
  }

  static List<int> _decodeBase64Flexible(String value) {
    final normalized = _normalizeBase64(value);
    try {
      return base64.decode(normalized);
    } on FormatException {
      return base64Url.decode(normalized);
    }
  }

  static String _cleanPastedToken(String value) {
    var cleaned = value.trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'^(setup\s*token|token|simplefin)\s*[:=]?\s*', caseSensitive: false),
      '',
    );
    return cleaned
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\u2060]'), '')
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  static String _normalizeBase64(String value) {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized = normalized.padRight(normalized.length + (4 - remainder), '=');
    }
    return normalized;
  }

  static String _joinPath(String basePath, String segment) {
    if (basePath.endsWith('/')) return '$basePath$segment';
    if (basePath.isEmpty) return '/$segment';
    return '$basePath/$segment';
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Explicit Basic Auth — do not rely on URI userInfo (http package / redirects).
  static String? _basicAuthHeader(Uri accessUrl) {
    final userInfo = accessUrl.userInfo;
    if (userInfo.isEmpty) return null;
    final separator = userInfo.indexOf(':');
    if (separator < 0) return null;
    final username = Uri.decodeComponent(userInfo.substring(0, separator));
    final password = Uri.decodeComponent(userInfo.substring(separator + 1));
    final token = base64.encode(utf8.encode('$username:$password'));
    return 'Basic $token';
  }

  static String _redactUri(Uri uri) {
    if (uri.userInfo.isEmpty) return uri.toString();
    return uri.replace(userInfo: '***:***').toString();
  }

  static String _truncate(String value, [int maxChars = 400]) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars)}…';
  }

  void close() => _httpClient.close();
}
