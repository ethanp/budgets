import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/remove_copilot_duplicates.dart';
import 'package:spend_trends/domain/transaction.dart';
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

    test('collapses Amazon order-id variants used in same-account dupes', () {
      expect(
        merchantFingerprint('Amazon.com*hy1oo'),
        merchantFingerprint('AMAZON.COM*HY1OO'),
      );
    });
  });

  group('accountMask', () {
    test('reads Copilot external id mask', () {
      expect(
        RemoveCopilotDuplicates.accountMask(
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
        RemoveCopilotDuplicates.accountMask(
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
      expect(RemoveCopilotDuplicates.accountMask(parent), isNull);

      final linkKeys = RemoveCopilotDuplicates.copilotLinkKeysForTest([
        parent,
        child,
      ]);
      expect(linkKeys['child'], 'id:parent');
    });
  });

  group('bestMerchantMatch', () {
    test(
      'accepts unique same-day amount candidate without merchant overlap',
      () {
        final twin = bestMerchantMatch(
          normalizedMerchant: 'COMPLETELY DIFFERENT',
          candidates: [
            BankTransaction(
              id: 'sf1',
              accountId: 'a',
              externalId: 'e',
              postedAt: DateTime(2026, 6, 30),
              amountCents: -5000,
              rawDescription: 'OTHER',
              normalizedMerchant: 'OTHER',
              pending: false,
            ),
          ],
        );
        expect(twin?.id, 'sf1');
      },
    );

    test(
      'requires merchant overlap when multiple candidates share day+amount',
      () {
        final twin = bestMerchantMatch(
          normalizedMerchant: 'UBER TRIP',
          candidates: [
            BankTransaction(
              id: 'lyft',
              accountId: 'a',
              externalId: 'e1',
              postedAt: DateTime(2026, 6, 30),
              amountCents: -5000,
              rawDescription: 'LYFT',
              normalizedMerchant: 'LYFT',
              pending: false,
            ),
            BankTransaction(
              id: 'uber',
              accountId: 'a',
              externalId: 'e2',
              postedAt: DateTime(2026, 6, 30),
              amountCents: -5000,
              rawDescription: 'UBER',
              normalizedMerchant: 'UBER TRIP HELP',
              pending: false,
            ),
          ],
        );
        expect(twin?.id, 'uber');
      },
    );
  });
}
