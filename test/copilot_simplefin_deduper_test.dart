import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/copilot_simplefin_deduper.dart';
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

  group('explicit belongs-to linking', () {
    test('Account.isCopilot detects Copilot external ids', () {
      expect(
        const Account(
          id: '1',
          externalId: 'copilot:Venture X:9999',
          name: 'Venture X ·9999',
          currency: 'USD',
          balanceCents: 0,
          status: AccountStatus.ok,
        ).isCopilot,
        isTrue,
      );
      expect(
        const Account(
          id: '2',
          externalId: 'ACT-abc',
          name: 'Venture X',
          currency: 'USD',
          balanceCents: 0,
          status: AccountStatus.ok,
        ).isCopilot,
        isFalse,
      );
    });

    test('belongsToAccountId links without a shared mask', () {
      const parent = Account(
        id: 'parent',
        externalId: 'ACT-parent',
        name: 'Sapphire Reserve',
        currency: 'USD',
        balanceCents: -1000,
        status: AccountStatus.ok,
      );
      const child = Account(
        id: 'child',
        externalId: 'copilot:Old Card:4242',
        name: 'Old Card ·4242',
        currency: 'USD',
        balanceCents: 0,
        status: AccountStatus.ok,
        belongsToAccountId: 'parent',
      );
      expect(child.hasParent, isTrue);
      expect(CopilotSimplefinDeduper.accountMask(parent), isNull);

      final linkKeys = CopilotSimplefinDeduper.copilotLinkKeysForTest([
        parent,
        child,
      ]);
      expect(linkKeys['child'], 'id:parent');
    });
  });
}
