import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/esp32_provider.dart';
import '../models/metal_classification.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ipController = TextEditingController();
  final List<FlSpot> _signalData = [];
  final int _maxDataPoints = 100;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _updateSignalData(List<double> values) {
    setState(() {
      _signalData.clear();
      for (int i = 0; i < values.length; i++) {
        _signalData.add(FlSpot(i.toDouble(), values[i]));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metal Dedektör'),
        actions: [
          Consumer<ESP32Provider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.isConnected ? Icons.link : Icons.link_off,
                  color: provider.isConnected ? Colors.green : Colors.red,
                ),
                onPressed: provider.isConnected ? provider.disconnect : null,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<ESP32Provider>(
          builder: (context, provider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildConnectionBar(provider),
                          if (provider.isConnected) ...[
                            _buildControlPanel(provider),
                            SizedBox(
                              height: 250,
                              child: _buildSignalGraph(),
                            ),
                            if (provider.classifications.isNotEmpty)
                              _buildCurrentReadings(provider),
                            Expanded(
                              child: SizedBox(
                                height: 200,
                                child: provider.classifications.isEmpty
                                    ? const Center(
                                        child: Text('Henüz tespit edilen metal yok'),
                                      )
                                    : _buildDetectionList(provider),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionBar(ESP32Provider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'ESP32 IP Adresi',
                hintText: 'örn: 192.168.1.100',
                errorText: provider.errorMessage.isNotEmpty ? provider.errorMessage : null,
                prefixIcon: const Icon(Icons.wifi),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: provider.isConnected
                ? null
                : () {
                    if (_ipController.text.isNotEmpty) {
                      provider.saveIpAddress(_ipController.text);
                      provider.connect();
                    }
                  },
            icon: const Icon(Icons.connect_without_contact),
            label: Text(provider.isConnected ? 'Bağlı' : 'Bağlan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isConnected ? Colors.green : null,
              foregroundColor: provider.isConnected ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(ESP32Provider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text('Dedektör Durumu'),
              Switch(
                value: provider.isDetectorOn,
                onChanged: (value) {
                  provider.toggleDetector(value);
                },
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: provider.isDetectorOn
                ? () => provider.calibrate()
                : null,
            icon: const Icon(Icons.tune),
            label: const Text('Kalibre Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isDetectorOn ? Colors.blue : Colors.grey,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.isDetectorOn
                ? () => provider.resetGraph()
                : null,
            color: provider.isDetectorOn ? Colors.blue : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSignalGraph() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 500,
            verticalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 500,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                reservedSize: 30,
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          minX: 0,
          maxX: _maxDataPoints.toDouble(),
          minY: 0,
          maxY: 4095,
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _signalData,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentReadings(ESP32Provider provider) {
    final latestReading = provider.classifications.isNotEmpty ? provider.classifications.first : null;
    
    if (latestReading == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metal Türü: ${latestReading.metalType}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildProgressBar(
            'Güven Oranı',
            latestReading.confidence,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildProgressBar(
            'Sinyal Gücü',
            latestReading.signalStrength,
            latestReading.getSignalColor(),
          ),
          const SizedBox(height: 8),
          Text(
            'Mesafe: ${latestReading.distance.toStringAsFixed(2)} cm',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${(value * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 10,
        ),
      ],
    );
  }

  Widget _buildDetectionList(ESP32Provider provider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.classifications.length,
      itemBuilder: (context, index) {
        final detection = provider.classifications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: detection.getSignalColor(),
              child: const Icon(Icons.radar, color: Colors.white),
            ),
            title: Text(detection.metalType),
            subtitle: Text(
              'Güven: ${(detection.confidence * 100).toStringAsFixed(1)}% • '
              'Sinyal: ${detection.getSignalStrengthLevel()}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mesafe: ${detection.distance.toStringAsFixed(2)} cm'),
                    const SizedBox(height: 8),
                    Text('Zaman: ${detection.timestamp.toLocal()}'),
                    const SizedBox(height: 8),
                    const Text('Sensör Verileri:'),
                    ...detection.sensorData.entries.map(
                      (e) => Text('${e.key}: ${e.value.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 