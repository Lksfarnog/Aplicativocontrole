import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart';

class SistemasOrdemPage extends StatefulWidget {
  final String pdfAssetPath;
  const SistemasOrdemPage({super.key, required this.pdfAssetPath});

  @override
  State<SistemasOrdemPage> createState() => _SistemasOrdemPageState();
}

class _SistemasOrdemPageState extends State<SistemasOrdemPage> {
  final _u1OrdemController = TextEditingController();
  final _ref2OrdemController = TextEditingController();
  final _kp2OrdemController = TextEditingController();
  final brokerInfo = BrokerInfo.instance;

  final ValueNotifier<String> expStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> velocidade1Ordem = ValueNotifier<double>(0.0);
  final ValueNotifier<double> posicao2Ordem = ValueNotifier<double>(0.0);
  final ValueNotifier<double> erro2Ordem = ValueNotifier<double>(0.0);
  final ValueNotifier<double> u2Ordem = ValueNotifier<double>(0.0);

  StreamSubscription? mqttSubscription;

  @override
  void initState() {
    super.initState();
    _setupMqttListener();
  }

  void _setupMqttListener() {
    if (brokerInfo.client != null &&
        brokerInfo.client!.connectionStatus!.state ==
            MqttConnectionState.connected) {
      const topics = [
        'sistemas/status',
        'sistemas/1ordem/velocidade',
        'sistemas/2ordem/posicao',
        'sistemas/2ordem/erro',
        'sistemas/2ordem/u',
      ];
      for (var topic in topics) {
        brokerInfo.client!.subscribe(topic, MqttQos.atLeastOnce);
      }

      mqttSubscription = brokerInfo.client!.updates!
          .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final recMess = c[0].payload as MqttPublishMessage;
          final payload =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topic = c[0].topic;

          switch (topic) {
            case 'sistemas/status':
              expStatus.value = payload;
              break;
            case 'sistemas/1ordem/velocidade':
              velocidade1Ordem.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'sistemas/2ordem/posicao':
              posicao2Ordem.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'sistemas/2ordem/erro':
              erro2Ordem.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'sistemas/2ordem/u':
              u2Ordem.value = double.tryParse(payload) ?? 0.0;
              break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    mqttSubscription?.cancel();
    const topics = [
      'sistemas/status',
      'sistemas/1ordem/velocidade',
      'sistemas/2ordem/posicao',
      'sistemas/2ordem/erro',
      'sistemas/2ordem/u',
    ];
    for (var topic in topics) {
      brokerInfo.client?.unsubscribe(topic);
    }
    _u1OrdemController.dispose();
    _ref2OrdemController.dispose();
    _kp2OrdemController.dispose();
    super.dispose();
  }

  void _publishMessage(String topic, String message) {
    if (brokerInfo.client == null ||
        brokerInfo.client!.connectionStatus!.state !=
            MqttConnectionState.connected) {
      _showFeedbackDialog('Erro', 'Não conectado ao broker MQTT.');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(message);
    brokerInfo.client!
        .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _enviar1Ordem() {
    if (_u1OrdemController.text.isNotEmpty) {
      _publishMessage(
          'sistemas/1ordem/u', _u1OrdemController.text.replaceAll(',', '.'));
      _showFeedbackDialog('Enviado!', 'Comando de 1ª Ordem enviado.');
    } else {
      _showFeedbackDialog('Erro', 'Insira o valor do Duty Cycle.');
    }
  }

  void _enviar2Ordem() {
    if (_ref2OrdemController.text.isNotEmpty &&
        _kp2OrdemController.text.isNotEmpty) {
      _publishMessage('sistemas/2ordem/tetaref',
          _ref2OrdemController.text.replaceAll(',', '.'));
      _publishMessage(
          'sistemas/2ordem/kp', _kp2OrdemController.text.replaceAll(',', '.'));
      _showFeedbackDialog('Enviado!', 'Comandos de 2ª Ordem enviados.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha a Referência e o Ganho Kp.');
    }
  }

  void _pararMotor() {
    _publishMessage('sistemas/comando', 'PARAR');
    _showFeedbackDialog('Enviado!', 'Comando para PARAR o motor foi enviado.');
  }

  void _showFeedbackDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistemas de 1ª e 2ª Ordem',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfPage(pdfAssetPath: widget.pdfAssetPath),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        foregroundColor: Colors.white,
        tooltip: 'Ajuda',
        child: const Icon(Icons.question_mark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Parar Motor'),
              onPressed: _pararMotor,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            _buildStatusDisplay(),
            const SizedBox(height: 24),
            _build1OrdemCard(),
            const SizedBox(height: 24),
            _build2OrdemCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplay() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monitoramento em Tempo Real',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ValueListenableBuilder<String>(
              valueListenable: expStatus,
              builder: (context, status, child) => Text('Modo Atual: $status',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: velocidade1Ordem,
              builder: (context, val, child) => Text(
                  'Velocidade (1ª Ordem): ${val.toStringAsFixed(2)} rad/s',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: posicao2Ordem,
              builder: (context, val, child) => Text(
                  'Posição (2ª Ordem): ${val.toStringAsFixed(2)} °',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: erro2Ordem,
              builder: (context, val, child) => Text(
                  'Erro (2ª Ordem): ${val.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build1OrdemCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sistema de 1ª Ordem (Velocidade)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Divider(height: 24),
            _buildTextField(
                controller: _u1OrdemController,
                label: 'Duty Cycle (%)',
                hint: 'Ex: 80.0'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _enviar1Ordem,
                child: const Text('Aplicar Degrau de Velocidade')),
          ],
        ),
      ),
    );
  }

  Widget _build2OrdemCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sistema de 2ª Ordem (Posição)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Divider(height: 24),
            _buildTextField(
                controller: _ref2OrdemController,
                label: 'Referência (Graus)',
                hint: 'Ex: 120.0'),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _kp2OrdemController,
                label: 'Ganho Proporcional (Kp)',
                hint: 'Ex: 15.0'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _enviar2Ordem,
                child: const Text('Aplicar Degrau de Posição')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String hint}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
          labelText: label, hintText: hint, border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
    );
  }
}
