import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart';

class MalhaAbertaFechadaPage extends StatefulWidget {
  final String pdfAssetPath;

  const MalhaAbertaFechadaPage({super.key, required this.pdfAssetPath});

  @override
  State<MalhaAbertaFechadaPage> createState() => _MalhaAbertaFechadaPageState();
}

class _MalhaAbertaFechadaPageState extends State<MalhaAbertaFechadaPage> {
  final _uMAController = TextEditingController();
  final _refMFController = TextEditingController();
  final _kpMFController = TextEditingController();
  final brokerInfo = BrokerInfo.instance;

  final ValueNotifier<String> motorStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> velocidadeRpm = ValueNotifier<double>(0.0);
  final ValueNotifier<double> erroMF = ValueNotifier<double>(0.0);
  final ValueNotifier<double> uMF = ValueNotifier<double>(0.0);

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
      const topics = ['motor/status', 'motor/velocidade', 'uMF', 'erroMF'];
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
            case 'motor/status':
              motorStatus.value = payload;
              break;
            case 'motor/velocidade':
              velocidadeRpm.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'uMF':
              uMF.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'erroMF':
              erroMF.value = double.tryParse(payload) ?? 0.0;
              break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    mqttSubscription?.cancel();
    const topics = ['motor/status', 'motor/velocidade', 'uMF', 'erroMF'];
    for (var topic in topics) {
      brokerInfo.client?.unsubscribe(topic);
    }
    _uMAController.dispose();
    _refMFController.dispose();
    _kpMFController.dispose();
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

  void _enviarMalhaAberta() {
    if (_uMAController.text.isNotEmpty) {
      _publishMessage('uMA', _uMAController.text.replaceAll(',', '.'));
      _showFeedbackDialog('Enviado!', 'Comando de Malha Aberta enviado.');
    } else {
      _showFeedbackDialog('Erro', 'Por favor, insira o valor do Duty Cycle.');
    }
  }

  void _enviarMalhaFechada() {
    if (_refMFController.text.isNotEmpty && _kpMFController.text.isNotEmpty) {
      _publishMessage('refMF', _refMFController.text.replaceAll(',', '.'));
      _publishMessage('KpMF', _kpMFController.text.replaceAll(',', '.'));
      _showFeedbackDialog('Enviado!', 'Comandos de Malha Fechada enviados.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha a Referência e o Ganho Kp.');
    }
  }

  void _pararMotor() {
    _publishMessage('controle/comando', 'PARAR');
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
        title: const Text('Malha Aberta vs. Fechada',
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
            _buildParameterInputCard(
    controller: _uMAController,
    title: 'Duty Cycle (%) - Malha Aberta',
    description: 'Define a porcentagem da tensão máxima que será aplicada diretamente ao motor, sem realimentação.',
    hintText: 'Ex: 50.0',
  ),
  const SizedBox(height: 8),
  ElevatedButton(
    onPressed: _enviarMalhaAberta,
    child: const Text('Enviar Comando de Malha Aberta'),
  ),
  const Divider(height: 40),

  // --- SEÇÃO DE MALHA FECHADA (AGORA USANDO O NOVO WIDGET) ---
  _buildParameterInputCard(
    controller: _refMFController,
    title: 'Referência (RPM) - Malha Fechada',
    description: 'A meta de velocidade (em RPM) que o controlador tentará alcançar e manter.',
    hintText: 'Ex: 1500.0',
  ),
  const SizedBox(height: 16),
  _buildParameterInputCard(
    controller: _kpMFController,
    title: 'Ganho Proporcional (Kp)',
    description: 'Define a "agressividade" da resposta do controlador. Valores maiores tentam corrigir o erro mais rapidamente.',
    hintText: 'Ex: 0.25',
  ),
  const SizedBox(height: 8),
  ElevatedButton(
    onPressed: _enviarMalhaFechada,
    child: const Text('Enviar Comando de Malha Fechada'),
  ),
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
            Text(
              'Monitoramento em Tempo Real',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 20),
            ValueListenableBuilder<String>(
              valueListenable: motorStatus,
              builder: (context, status, child) =>
                  Text('Status: $status', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: velocidadeRpm,
              builder: (context, velocidade, child) => Text(
                  'Velocidade: ${velocidade.toStringAsFixed(2)} RPM',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: uMF,
              builder: (context, u, child) => Text(
                  'Sinal de Controle (u): ${u.toStringAsFixed(2)} %',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: erroMF,
              builder: (context, erro, child) => Text(
                  'Erro (Ref - Vel): ${erro.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // Widget reutilizável para criar um card de input de parâmetro
Widget _buildParameterInputCard({
  required TextEditingController controller,
  required String title,
  required String description,
  required String hintText,
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), // Bordas arredondadas
      side: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título do parâmetro
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          
          // Campo de Input (TextFormField)
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]'))],
          ),
          const SizedBox(height: 12),

          // Texto explicativo
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    ),
  );
}
}
