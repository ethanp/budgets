import 'package:budgets/domain/stay_chain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StayChain', () {
    test('empty chain has no current', () {
      final chain = StayChain(const []);
      expect(chain.isEmpty, isTrue);
      expect(chain.current, isNull);
      expect(chain.segments, isEmpty);
    });

    test('sorts by startedOn and marks last as current', () {
      final chain = StayChain([
        ChainStay(
          id: '2',
          label: 'Later',
          startedOn: DateTime(2022, 1, 1),
        ),
        ChainStay(
          id: '1',
          label: 'Earlier',
          startedOn: DateTime(2020, 6, 1),
        ),
      ]);

      expect(chain.segments.length, 2);
      expect(chain.segments.first.stay.label, 'Earlier');
      expect(chain.segments.first.isCurrent, isFalse);
      expect(chain.segments.first.rangeEnd, DateTime(2021, 12, 31));
      expect(chain.current!.stay.label, 'Later');
      expect(chain.current!.isCurrent, isTrue);
      expect(chain.current!.rangeEnd, isNull);
    });

    test('single stay is open-ended current', () {
      final chain = StayChain([
        ChainStay(
          id: '1',
          label: 'Only',
          startedOn: DateTime(2023, 3, 15),
        ),
      ]);
      expect(chain.current!.dateCaption, contains('present'));
      expect(chain.current!.rangeEnd, isNull);
    });

    test('intersectsChart for overlapping open-ended stay', () {
      final chain = StayChain([
        ChainStay(
          id: '1',
          label: 'Home',
          startedOn: DateTime(2020, 1, 1),
        ),
      ]);
      expect(
        chain.current!.intersectsChart(
          chartMinDate: DateTime(2023, 1, 1),
          chartMaxDate: DateTime(2024, 12, 31),
        ),
        isTrue,
      );
    });
  });

  group('LifeChainKind.trendEraAccent', () {
    test('keeps even eras near base lightness; odd eras slightly darker', () {
      final baseLightness =
          HSLColor.fromColor(LifeChainKind.housing.trendBandColor).lightness;
      for (var eraIndex = 0; eraIndex < 5; eraIndex++) {
        final accentLightness = HSLColor.fromColor(
          LifeChainKind.housing.trendEraAccent(eraIndex),
        ).lightness;
        if (eraIndex.isEven) {
          expect((accentLightness - baseLightness).abs(), lessThan(0.02));
        } else {
          expect(accentLightness, lessThan(baseLightness));
          expect(baseLightness - accentLightness, closeTo(0.04, 0.015));
        }
      }
    });

    test('accent cycle repeats every ten eras (hue×5 and zebra×2)', () {
      expect(
        LifeChainKind.job.trendEraAccent(0),
        LifeChainKind.job.trendEraAccent(10),
      );
      expect(
        LifeChainKind.job.trendEraAccent(1),
        LifeChainKind.job.trendEraAccent(11),
      );
    });
  });
}
