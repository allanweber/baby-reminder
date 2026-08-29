import 'package:flutter_test/flutter_test.dart';

import 'package:baby_feed_tracker/widgets/log_feed_sheet.dart';

void main() {
  group('feed duration', () {
    test('the stepper moves in 5-minute increments', () {
      expect(kFeedDurationStepMin, 5);
      // A long feed (e.g. 40 min) is a handful of +5 taps, not forty +1 taps.
      var minutes = 0;
      for (var taps = 0; taps < 8; taps++) {
        minutes = clampFeedDuration(minutes + kFeedDurationStepMin);
      }
      expect(minutes, 40);
    });

    test('a typed or stepped value is clamped to a sensible 0..240 range', () {
      expect(clampFeedDuration(40), 40); // an ordinary value passes through
      expect(clampFeedDuration(-5), 0); // never negative
      expect(clampFeedDuration(999), kMaxFeedDurationMin); // capped at the max
      expect(clampFeedDuration(kMaxFeedDurationMin), kMaxFeedDurationMin);
      expect(kMaxFeedDurationMin, 240);
    });

    test('stepping down never goes below zero', () {
      expect(clampFeedDuration(0 - kFeedDurationStepMin), 0);
    });
  });
}
