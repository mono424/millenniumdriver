import 'dart:async';
import 'package:millenniumdriver/MillenniumCommunicationClient.dart';
import 'package:millenniumdriver/MillenniumMessage.dart';
import 'package:millenniumdriver/protocol/commands/ExtinguishAllLeds.dart';
import 'package:millenniumdriver/protocol/commands/GetStatus.dart';
import 'package:millenniumdriver/protocol/commands/GetVersion.dart';
import 'package:millenniumdriver/protocol/commands/Reset.dart';
import 'package:millenniumdriver/protocol/commands/SetAutomaticReports.dart';
import 'package:millenniumdriver/protocol/commands/SetAutomaticReportsTime.dart';
import 'package:millenniumdriver/protocol/commands/SetLedBrightness.dart';
import 'package:millenniumdriver/protocol/commands/SetLeds.dart';
import 'package:millenniumdriver/protocol/commands/SetScanTime.dart';
import 'package:millenniumdriver/protocol/model/LEDPattern.dart';
import 'package:millenniumdriver/protocol/model/RequestConfig.dart';
import 'package:millenniumdriver/protocol/model/StatusReportSendInterval.dart';

class MillenniumBoard {
  
  MillenniumCommunicationClient _client;

  StreamController _inputStreamController;
  Stream<MillenniumMessage> _inputStream;
  List<int> _buffer;
  String _version;

  static List<String> RANKS = ["a", "b", "c", "d", "e", "f", "g", "h"];
  static List<String> ROWS = ["1", "2", "3", "4", "5", "6", "7", "8"];
  static get SQUARES {
    List<String> squares = [];
    for (var row in ROWS) {
      for (var rank in RANKS.reversed.toList()) {
        squares.add(rank + row);
      }
    }
    return squares;
  }

  get version => _version;

  MillenniumBoard();

  Future<void> init(MillenniumCommunicationClient client, { Duration initialDelay = const Duration(milliseconds: 300) }) async {
    _client = client;

    _client.receiveStream.listen(_handleInputStream);
    _inputStreamController = new StreamController<MillenniumMessage>();
    _inputStream = _inputStreamController.stream.asBroadcastStream();

    await Future.delayed(initialDelay);

    _version = await getVersion();
  }

  void _handleInputStream(List<int> chunk) {
    //print("> " + chunk.map((n) => String.fromCharCode(n & 127)).toString());
    if (_buffer == null)
      _buffer = chunk.toList();
    else
      _buffer.addAll(chunk);

    if (_buffer.length > 1000) {
      _buffer.removeRange(0, _buffer.length - 1000);
    }

    do {
      try {
        MillenniumMessage message = MillenniumMessage.parse(_buffer);
        _inputStreamController.add(message);
        _buffer.removeRange(0, message.getLength());
        //print("[IMessage] valid (" + message.getCode() + ")");
      } on MillenniumInvalidMessageException catch (e) {
        skipBadBytes(e.skipBytes, _buffer);
        //print("[IMessage] invalid");
      } on MillenniumUncompleteMessage {
        // wait longer
        break;
      } catch (err) {
        //print("Unknown parse-error: " + err.toString());
        break;
      }
    } while (_buffer.length > 0);
  }

  Stream<MillenniumMessage> getInputStream() {
    return _inputStream;
  }

  void skipBadBytes(int start, List<int> buffer) {
    buffer.removeRange(0, start);
  }

  Stream<Map<String, String>> getBoardUpdateStream() {
    return getInputStream()
        .where(
            (MillenniumMessage msg) => msg.getCode() == GetStatusAnswer().code)
        .map((MillenniumMessage msg) => GetStatusAnswer().process(msg.getMessage()));
  }

  Future<void> extinguishAllLeds({ RequestConfig config = const RequestConfig() }) {
    return ExtinguishAllLeds().request(_client, _inputStream, config);
  }

  Future<void> turnOnSingleLed(String square, {Duration slotTime = const Duration(milliseconds: 500), RequestConfig config = const RequestConfig()}) {
    return SetLeds(slotTime, LEDPattern.singleSquare(square)).request(_client, _inputStream, config);
  }

  Future<void> turnOnAllLeds({Duration slotTime = const Duration(milliseconds: 500), String pattern = "ff", RequestConfig config = const RequestConfig()}) {
    return SetLeds(slotTime, LEDPattern.allLeds(hex: pattern)).request(_client, _inputStream, config);
  }

  Future<void> turnOnLeds(List<String> squares, {Duration slotTime = const Duration(milliseconds: 500), RequestConfig config = const RequestConfig()}) {
    return SetLeds(slotTime, LEDPattern.manySquares(squares)).request(_client, _inputStream, config);
  }

  Future<void> setLeds(LEDPattern ledPattern, {Duration slotTime = const Duration(milliseconds: 500), RequestConfig config = const RequestConfig()}) {
    return SetLeds(slotTime, ledPattern).request(_client, _inputStream, config);
  }

  Future<void> setAutomaticReports(StatusReportSendInterval interval, {RequestConfig config = const RequestConfig()}) {
    return SetAutomaticReports(interval).request(_client, _inputStream, config);
  }

  Future<void> setAutomaticReportsTime(Duration time, {RequestConfig config = const RequestConfig()}) {
    return SetAutomaticReportsTime(time).request(_client, _inputStream, config);
  }

  Future<Map<String, String>> getStatus({ RequestConfig config = const RequestConfig() }) {
    return GetStatus().request(_client, _inputStream);
  }

  Future<void> setScanTime(Duration time, { RequestConfig config = const RequestConfig() }) {
    return SetScanTime(time).request(_client, _inputStream);
  }

  Future<String> getVersion({ RequestConfig config = const RequestConfig() }) {
    return GetVersion().request(_client, _inputStream, config);
  }

  Future<void> reset() {
    return Reset().send(_client);
  }

  Future<void> setLedBrightness(double level, { RequestConfig config = const RequestConfig() }) {
    return SetLedBrightness(level).request(_client, _inputStream, config);
  }

}
