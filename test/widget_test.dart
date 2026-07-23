import 'package:flutter_test/flutter_test.dart';

import 'package:listen_bro/config/customer_seat_layout.dart';
import 'package:listen_bro/config/audio_paths.dart';

void main() {
  test('seat anchors are fixed', () {
    expect(CustomerSeatLayout.leftAnchorXFrac, 0.18);
    expect(CustomerSeatLayout.centerAnchorXFrac, 0.50);
    expect(CustomerSeatLayout.rightAnchorXFrac, 0.82);
  });

  test('audio paths', () {
    expect(AudioPaths.bgmMain, 'audio/MusMus-BGM-059.mp3');
    expect(AudioPaths.doorRing, 'audio/door_ring.mp3');
  });
}
