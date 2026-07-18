import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/copilot_simplefin_deduper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('merchantFingerprint', () {
    test('strips amazon order suffixes', () {
      expect(
        merchantFingerprint('Amazon.com*nz8kv'),
        merchantFingerprint('Amazon.com*nz8964s40'),
      );
    });

    test('normalizes case and punctuation', () {
      expect(
        merchantFingerprint("Senior Pepe's Cocina"),
        merchantFingerprint('SENIOR PEPE\'S COCINA'),
      );
    });
  });

  group('accountMask', () {
    test('reads Copilot external id mask', () {
      expect(
        CopilotSimplefinDeduper.accountMask(
          const Account(
            id: '1',
            externalId: 'copilot:Venture X:1298',
            name: 'Venture X ·1298',
            currency: 'USD',
            balanceCents: 0,
            status: AccountStatus.ok,
          ),
        ),
        '1298',
      );
    });

    test('reads trailing digits from SimpleFIN name', () {
      expect(
        CopilotSimplefinDeduper.accountMask(
          const Account(
            id: '2',
            externalId: 'ACT-abc',
            name: 'Venture X (1298)',
            currency: 'USD',
            balanceCents: 0,
            status: AccountStatus.ok,
          ),
        ),
        '1298',
      );
    });
  });
}
