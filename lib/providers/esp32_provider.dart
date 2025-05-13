import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/esp32_service.dart';
import '../models/metal_classification.dart';

class ESP32Provider with ChangeNotifier {
  final ESP32Service _esp32Service = ESP32Service();
  final List<MetalClassification> _classifications = [];
  static const String _ipAddressKey = 'esp32_ip_address';
  
  String _ipAddress = '';
  bool _isConnected = false;
  bool _isDetectorOn = false;
  String _errorMessage = '';
  Function(List<double>)? onSignalUpdate;

  ESP32Provider() {
    _loadSavedIpAddress();
    _setupListeners();
  }

  List<MetalClassification> get classifications => List.unmodifiable(_classifications);
  bool get isConnected => _isConnected;
  bool get isDetectorOn => _isDetectorOn;
  String get ipAddress => _ipAddress;
  String get errorMessage => _errorMessage;

  Future<void> _loadSavedIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    _ipAddress = prefs.getString(_ipAddressKey) ?? '';
    notifyListeners();
  }

  Future<void> saveIpAddress(String ip) async {
    _ipAddress = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipAddressKey, ip);
    notifyListeners();
  }

  void _setupListeners() {
    _esp32Service.statusStream.listen((status) {
      _isConnected = status == ConnectionStatus.connected;
      _errorMessage = status == ConnectionStatus.error ? _esp32Service.lastError : '';
      if (!_isConnected) {
        _isDetectorOn = false;
        onSignalUpdate?.call([]);
        _classifications.clear();
      }
      notifyListeners();
    });

    _esp32Service.dataStream.listen((data) {
      try {
        final json = jsonDecode(data);
        
        // Durum güncellemesi
        if (json.containsKey('status')) {
          final status = json['status'] as String;
          _isDetectorOn = status == 'ON';
          
          if (!_isDetectorOn) {
            onSignalUpdate?.call([]);
            _classifications.clear();
          }
          
          notifyListeners();
          return;
        }

        // Sinyal verisi
        if (_isDetectorOn) {
          List<double> signalHistory = [];
          
          if (json.containsKey('signal_history')) {
            signalHistory = (json['signal_history'] as List).map((e) => (e as num).toDouble()).toList();
          } else if (json.containsKey('raw_signal')) {
            final rawSignal = (json['raw_signal'] as num).toDouble();
            signalHistory = [rawSignal];
          }

          if (signalHistory.isNotEmpty) {
            onSignalUpdate?.call(signalHistory);
          }

          // Metal tespiti
          if (json.containsKey('metal_type')) {
            final classification = MetalClassification.fromJson(json);
            _classifications.insert(0, classification);
            if (_classifications.length > 50) {
              _classifications.removeLast();
            }
            notifyListeners();
          }
        }
      } catch (e) {
        _errorMessage = 'Error parsing data: $e';
        notifyListeners();
      }
    });
  }

  Future<void> connect() async {
    if (_ipAddress.isEmpty) {
      _errorMessage = 'IP address is not set';
      notifyListeners();
      return;
    }

    try {
      await _esp32Service.connect(_ipAddress);
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_isDetectorOn) {
      toggleDetector(false);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _esp32Service.disconnect();
    _isDetectorOn = false;
    onSignalUpdate?.call([]);
    _classifications.clear();
    notifyListeners();
  }

  void toggleDetector(bool value) {
    if (_isConnected) {
      _esp32Service.sendCommand(value ? 'POWER_ON' : 'POWER_OFF');
      if (!value) {
        onSignalUpdate?.call([]);
        _classifications.clear();
      }
      notifyListeners();
    }
  }

  void calibrate() {
    if (_isConnected && _isDetectorOn) {
      _esp32Service.sendCommand('CALIBRATE');
      _classifications.clear();
      notifyListeners();
    }
  }

  void resetGraph() {
    onSignalUpdate?.call([]);
    notifyListeners();
  }

  @override
  void dispose() {
    _esp32Service.dispose();
    super.dispose();
  }
} 