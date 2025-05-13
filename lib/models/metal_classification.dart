import 'package:flutter/material.dart';

class MetalClassification {
  final String metalType;
  final double confidence;
  final DateTime timestamp;
  final double signalStrength;
  final double distance;
  final Map<String, double> sensorData;

  MetalClassification({
    required this.metalType,
    required this.confidence,
    required this.timestamp,
    required this.signalStrength,
    required this.distance,
    required this.sensorData,
  });

  factory MetalClassification.fromJson(Map<String, dynamic> json) {
    return MetalClassification(
      metalType: json['metal_type'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      signalStrength: (json['signal_strength'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      sensorData: Map<String, double>.from(json['sensor_data'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metal_type': metalType,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'signal_strength': signalStrength,
      'distance': distance,
      'sensor_data': sensorData,
    };
  }

  String getSignalStrengthLevel() {
    if (signalStrength >= 0.8) return 'Çok Güçlü';
    if (signalStrength >= 0.6) return 'Güçlü';
    if (signalStrength >= 0.4) return 'Orta';
    if (signalStrength >= 0.2) return 'Zayıf';
    return 'Çok Zayıf';
  }

  Color getSignalColor() {
    if (signalStrength >= 0.8) return Colors.green;
    if (signalStrength >= 0.6) return Colors.lightGreen;
    if (signalStrength >= 0.4) return Colors.yellow;
    if (signalStrength >= 0.2) return Colors.orange;
    return Colors.red;
  }

  @override
  String toString() {
    return 'MetalClassification{metalType: $metalType, confidence: ${(confidence * 100).toStringAsFixed(2)}%, timestamp: $timestamp}';
  }
} 