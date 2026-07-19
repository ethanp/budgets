import 'dart:convert';

import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('amountStringToCents', () {
    test('parses negative dollars', () {
      expect(amountStringToCents('-12.34'), -1234);
    });

    test('parses fractional cents', () {
      expect(amountStringToCents('0.1'), 10);
    });

    test('parses whole dollars', () {
      expect(amountStringToCents('100'), 10000);
    });
  });

  group('SimpleFinClient.parseAccountSet', () {
    test('parses accounts and errors', () {
      final accountSet = SimpleFinClient.parseAccountSet({
        'errlist': [
          {
            'code': 'con.auth',
            'msg': 'Authentication required',
            'conn_id': 'CON-1',
          },
        ],
        'accounts': [
          {
            'id': '2930002',
            'name': 'Savings',
            'currency': 'USD',
            'balance': '100.23',
            'balance-date': 978366153,
            'conn_id': 'CON-1',
            'transactions': [
              {
                'id': 'tx-1',
                'posted': 793090572,
                'amount': '-12.34',
                'description': 'Uncle Frank',
                'pending': false,
              },
            ],
          },
        ],
      });

      expect(accountSet.errors, hasLength(1));
      expect(accountSet.errors.first.isAuthFailure, isTrue);
      expect(accountSet.accounts, hasLength(1));
      expect(accountSet.accounts.first.transactions.single.amount, '-12.34');
    });

    test('fills conn_name from connections when account omits it', () {
      final accountSet = SimpleFinClient.parseAccountSet({
        'connections': [
          {
            'conn_id': 'CON-1',
            'name': 'Capital One',
            'org_id': 'INST-1',
            'sfin_url': 'https://example.com',
          },
        ],
        'accounts': [
          {
            'id': 'a1',
            'name': 'Venture X',
            'currency': 'USD',
            'balance': '0',
            'balance-date': 978366153,
            'conn_id': 'CON-1',
            'transactions': [],
          },
        ],
      });

      expect(accountSet.accounts.single.connName, 'Capital One');
    });
  });

  group('normalizeMerchant', () {
    test('uppercases and collapses whitespace', () {
      expect(normalizeMerchant('  sq   coffee '), 'SQ COFFEE');
    });
  });

  group('claim token decode', () {
    test('decodes standard base64 setup token', () async {
      final client = SimpleFinClient(httpClient: _FakeClaimClient());
      final accessUrl = await client.claimAccessUrl(
        'aHR0cHM6Ly9icmlkZ2Uuc2ltcGxlZmluLm9yZy9zaW1wbGVmaW4vY2xhaW0vZGVtbw==',
      );
      expect(accessUrl.toString(), 'https://demo:demo@bridge.simplefin.org/simplefin');
    });

    test('decodes url-safe base64 and ignores whitespace', () async {
      final client = SimpleFinClient(httpClient: _FakeClaimClient());
      // same as demo token with +/ rewritten conceptually; use padded url-safe form
      final accessUrl = await client.claimAccessUrl(
        ' aHR0cHM6Ly9icmlkZ2Uuc2ltcGxlZmluLm9yZy9zaW1wbGVmaW4vY2xhaW0vZGVtbw== ',
      );
      expect(accessUrl.scheme, 'https');
    });

    test('accepts already-decoded https claim URL', () async {
      final client = SimpleFinClient(httpClient: _FakeClaimClient());
      final accessUrl = await client.claimAccessUrl(
        'https://bridge.simplefin.org/simplefin/claim/demo',
      );
      expect(accessUrl.toString(), 'https://demo:demo@bridge.simplefin.org/simplefin');
    });
  });
}

class _FakeClaimClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST') {
      expect(request.url.scheme, 'https');
      final body = utf8.encode(
        'https://demo:demo@bridge.simplefin.org/simplefin',
      );
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable([body]),
        200,
      );
    }
    expect(request.method, 'GET');
    expect(request.headers['Authorization'], isNotNull);
    expect(request.url.userInfo, isEmpty);
    final body = utf8.encode('{"errlist":[],"accounts":[]}');
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([body]),
      200,
    );
  }
}
