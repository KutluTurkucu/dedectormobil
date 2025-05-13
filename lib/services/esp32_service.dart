import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error
}

class ESP32Service {
  static final ESP32Service _instance = ESP32Service._internal();
  factory ESP32Service() => _instance;
  ESP32Service._internal();

  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  final StreamController<String> _dataController = StreamController<String>.broadcast();
  final StreamController<ConnectionStatus> _statusController = StreamController<ConnectionStatus>.broadcast();
  
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _lastError = '';
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  Stream<String> get dataStream => _dataController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _status;
  String get lastError => _lastError;

  Future<void> connect(String ipAddress) async {
    if (_status == ConnectionStatus.connected || _isReconnecting) {
      return;
    }

    try {
      _updateStatus(ConnectionStatus.connecting);
      _logger.i('Connecting to ESP32...');
      
      final wsUrl = 'ws://localhost:8083';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) {
          _handleData(data);
        },
        onError: (error) {
          _handleError('WebSocket error: $error');
          _startReconnectTimer();
        },
        onDone: () {
          _handleDisconnection();
          _startReconnectTimer();
        },
        cancelOnError: false,
      );

      _updateStatus(ConnectionStatus.connected);
      _logger.i('Connected to ESP32 at $wsUrl');
      
      // Bağlantı başarılı olduğunda POWER_OFF komutu gönder
      sendCommand('POWER_OFF');
      
    } catch (e) {
      _handleError('Connection error: $e');
      _startReconnectTimer();
    }
  }

  void sendCommand(String command) {
    if (_status == ConnectionStatus.connected && _channel != null) {
      try {
        _channel!.sink.add(command);
        _logger.i('Sent command: $command');
      } catch (e) {
        _logger.e('Error sending command: $e');
        _handleError('Command error: $e');
      }
    } else {
      _logger.w('Cannot send command: not connected');
    }
  }

  void _handleData(dynamic data) {
    try {
      _dataController.add(data.toString());
      _logger.d('Received data: $data');
    } catch (e) {
      _logger.e('Error parsing data: $e');
    }
  }

  void _handleError(String error) {
    _lastError = error;
    _logger.e(error);
    _updateStatus(ConnectionStatus.error);
  }

  void _handleDisconnection() {
    _updateStatus(ConnectionStatus.disconnected);
    _logger.w('Disconnected from ESP32');
    _channel?.sink.close();
    _channel = null;
  }

  void _startReconnectTimer() {
    if (!_isReconnecting) {
      _isReconnecting = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        _isReconnecting = false;
        if (_status != ConnectionStatus.connected) {
          connect('localhost:8083');
        }
      });
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _isReconnecting = false;
    await _channel?.sink.close();
    _handleDisconnection();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _dataController.close();
    _statusController.close();
    disconnect();
  }
} 