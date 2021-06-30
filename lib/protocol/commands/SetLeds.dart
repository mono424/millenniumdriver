import 'package:millenniumdriver/MillenniumBoard.dart';
import 'package:millenniumdriver/MillenniumMessage.dart';
import 'package:millenniumdriver/protocol/Answer.dart';
import 'package:millenniumdriver/protocol/Command.dart';

class SetLeds extends Command<void> {
  final String code = "L";
  final Answer<void> answer = SetLedsAck();
  
  final Duration slotTime;
  final LEDPattern pattern;

  // two-hex chart slot-time in 4.096ms steps, two-char hex per led in pattern
  SetLeds(this.slotTime, this.pattern);

  String slotTimeHex() {
    int mul = slotTime.inMilliseconds ~/ 4.096;
    return MillenniumMessage.numToHex(mul);
  }

  Future<String> messageBuilder() async {
    return code + slotTimeHex() + pattern.toString();
  }
}

class SetLedsAck extends Answer<void> {
  final String code = "l";

  @override
  void process(String msg) {}
}

class LEDPattern {

  String pattern;

  LEDPattern.singleSquare(String square, { String hex = "FF" }) {
    pattern = initializeNewPattern();

    for (int ledIndex in getSquareIndices(square)) {
      ledIndex = ledIndex * 2;
      pattern = pattern.replaceRange(ledIndex, ledIndex+2, hex.toUpperCase());
    }
  }

  LEDPattern.manySquares(List<String> squares, { String hex = "FF" }) {
    pattern = initializeNewPattern();

    for (String square in squares) {
      for (int ledIndex in getSquareIndices(square)) {
        ledIndex = ledIndex * 2;
        pattern = pattern.replaceRange(ledIndex, ledIndex+2, hex.toUpperCase());
      }
    }
  }

  LEDPattern.allLeds({ String hex = "FF" }) {
    pattern = initializeNewPattern(hex: hex);
  }

  @override
  String toString() {
    return pattern;
  }

  static String initializeNewPattern({ String hex = "00" }) {
    String res = "";

    for (var i = 0; i < 81; i++) {
      res += hex;
    }

    return res;
  }

  // Example: LED1 LED2 LED10 LED11 = A8
  static List<int> getSquareIndices(String square) {
    int rank = MillenniumBoard.RANKS.reversed.toList().indexOf(square.substring(0, 1).toLowerCase());
    int row = MillenniumBoard.ROWS.indexOf(square.substring(1, 2));

    return [
      rank * 9 + row,
      rank * 9 + row + 1,
      (rank + 1) * 9 + row,
      (rank + 1) * 9 + row + 1
    ];
  }
}