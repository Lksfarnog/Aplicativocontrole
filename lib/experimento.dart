// experimento_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'broker.dart';
import 'dadosexperimento.dart';

class ExperimentoPage extends StatefulWidget {
  const ExperimentoPage({super.key});

  @override
  State<ExperimentoPage> createState() => _ExperimentoPageState();
}

class _ExperimentoPageState extends State<ExperimentoPage> {
  final referenciaController = TextEditingController();
  String wifiStatus = '';
  String brokerStatus = '';
  String experimentoStatus = '';
  late MqttServerClient client;
  final brokerInfo = BrokerInfo.instance;
  List<Map<String, String>> tableData = [];
  late Timer _reconnectTimer;

  @override
  void initState() {
    super.initState();
    referenciaController.text = ExperimentoData().valores['referencia']!;
    referenciaController.addListener(() {
      ExperimentoData().valores['referencia'] = referenciaController.text;
    });
    _connectToMqtt();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        _connectToMqtt();
      }
    });
  }

  @override
  void dispose() {
    _reconnectTimer.cancel();
    referenciaController.dispose();
    client.disconnect();
    super.dispose();
  }

  Future<void> _connectToMqtt() async {
    client = MqttServerClient(brokerInfo.ip, 'flutter_experimento');
    client.port = brokerInfo.porta;
    client.keepAlivePeriod = 20;
    if (brokerInfo.credenciais) {
      client.setProtocolV311();
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier('flutter_experimento')
          .authenticateAs(brokerInfo.usuario, brokerInfo.senha)
          .startClean();
    }
    try {
      await client.connect();
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        client.subscribe('estadoESPWifi', MqttQos.atMostOnce);
        client.subscribe('estadoESPBroker', MqttQos.atMostOnce);
        client.subscribe('estadoExperimento', MqttQos.atMostOnce);
        client.subscribe('tempo', MqttQos.atMostOnce);
        client.subscribe('nivel', MqttQos.atMostOnce);
        client.subscribe('tensao', MqttQos.atMostOnce);
        client.updates?.listen(_onMessage);
        _showDialog('Info', 'Conectado ao Broker!');
      }
    } catch (_) { /* silent retry */ }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      final topic = msg.topic;
      final message = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
      setState(() {
        if (topic == 'estadoESPWifi') {
          wifiStatus = message;
        // ignore: curly_braces_in_flow_control_structures
        } else if (topic == 'estadoESPBroker') brokerStatus = message;
        // ignore: curly_braces_in_flow_control_structures
        else if (topic == 'estadoExperimento') experimentoStatus = message;
        else _handleDataUpdate(topic, message);
      });
    }
  }

  void _handleDataUpdate(String type, String message) {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final Map<String, String> entry = {
      'timestamp': now,
      'tempo': '',
      'nivel': '',
      'tensao': '',
      'estimado': ''
    };
    final idx = tableData.indexWhere((e) => e['timestamp'] == now);
    final value = double.tryParse(message)?.toStringAsFixed(1) ?? '';
    if (idx == -1) {
      entry[type] = value;
      tableData.add(entry);
    } else {
      tableData[idx][type] = value;
    }
  }

  void _publishReference() {
    final v = double.tryParse(referenciaController.text);
    if (v == null) return;
    final builder = MqttClientPayloadBuilder()..addDouble(v);
    client.publishMessage('referencia_app', MqttQos.atLeastOnce, builder.payload!);
  }

  void _endExperiment() {
    final builder = MqttClientPayloadBuilder()..addString('ENCERRAR');
    client.publishMessage('encerraExperimento', MqttQos.exactlyOnce, builder.payload!);
  }

  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle do Experimento'),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statusCard(),
            const SizedBox(height: 16),
            _referenceField(),
            const SizedBox(height: 16),
            _actionButtons(),
            const SizedBox(height: 16),
            _dataTable(),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _statusRow('WiFi ESP:', wifiStatus),
            _statusRow('Broker ESP:', brokerStatus),
            _statusRow('Experimento:', experimentoStatus),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Text(value)],
    );
  }

  Widget _referenceField() {
    return TextFormField(
      controller: referenciaController,
      decoration: const InputDecoration(
        labelText: 'Referência (cm)',
        prefixIcon: Icon(Icons.tune, color: Color.fromRGBO(19, 85, 156, 1)),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onFieldSubmitted: (_) => _publishReference(),
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _publishReference,
          style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(19, 85, 156, 1)),
          child: const Text('Publicar Referência'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _endExperiment,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Encerrar Experimento'),
        ),
      ],
    );
  }

  Widget _dataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Tempo (s)')),
          DataColumn(label: Text('Nível (cm)')),
          DataColumn(label: Text('Tensão (V)')),
          DataColumn(label: Text('Estimado')),
        ],
        rows: tableData.map((row) {
          return DataRow(cells: [
            DataCell(Text(row['tempo'] ?? '')),
            DataCell(Text(row['nivel'] ?? '')),
            DataCell(Text(row['tensao'] ?? '')),
            DataCell(Text(row['estimado'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }
}
