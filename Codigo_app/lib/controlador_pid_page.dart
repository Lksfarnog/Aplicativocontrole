// controlador_pid_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart';

class ControladorPidPage extends StatefulWidget {
  final String pdfAssetPath;
  const ControladorPidPage({super.key, required this.pdfAssetPath});

  @override
  State<ControladorPidPage> createState() => _ControladorPidPageState();
}

class _ControladorPidPageState extends State<ControladorPidPage> {
  // --- Controladores dos campos de texto com valores sugeridos pelo PDF ---
  final _refController = TextEditingController(text: '120.0');
  final _kpController = TextEditingController(text: '10.0');
  final _kiController = TextEditingController(text: '8.0');
  final _kdController = TextEditingController(text: '0.05');
  final brokerInfo = BrokerInfo.instance;

  // --- ValueNotifiers para os dados em tempo real ---
  final ValueNotifier<String> expStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> theta = ValueNotifier<double>(0.0);
  final ValueNotifier<double> up = ValueNotifier<double>(0.0);
  final ValueNotifier<double> ui = ValueNotifier<double>(0.0);
  final ValueNotifier<double> ud = ValueNotifier<double>(0.0);
  final ValueNotifier<double> uTotal = ValueNotifier<double>(0.0);
  final ValueNotifier<double> uSat = ValueNotifier<double>(0.0);

  StreamSubscription? mqttSubscription;

  @override
  void initState() {
    super.initState();
    _setupMqttListener();
  }

  void _setupMqttListener() {
    if (brokerInfo.client?.connectionStatus?.state == MqttConnectionState.connected) {
      const topics = [
        'pid/status', 'pid/output/theta', 'pid/output/up', 'pid/output/ui',
        'pid/output/ud', 'pid/output/u_total', 'pid/output/usat'
      ];
      for (var topic in topics) {
        brokerInfo.client!.subscribe(topic, MqttQos.atLeastOnce);
      }

      mqttSubscription = brokerInfo.client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final recMess = c[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topic = c[0].topic;

          switch (topic) {
            case 'pid/status': expStatus.value = payload; break;
            case 'pid/output/theta': theta.value = double.tryParse(payload) ?? 0.0; break;
            case 'pid/output/up': up.value = double.tryParse(payload) ?? 0.0; break;
            case 'pid/output/ui': ui.value = double.tryParse(payload) ?? 0.0; break;
            case 'pid/output/ud': ud.value = double.tryParse(payload) ?? 0.0; break;
            case 'pid/output/u_total': uTotal.value = double.tryParse(payload) ?? 0.0; break;
            case 'pid/output/usat': uSat.value = double.tryParse(payload) ?? 0.0; break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    mqttSubscription?.cancel();
    const topics = [
        'pid/status', 'pid/output/theta', 'pid/output/up', 'pid/output/ui',
        'pid/output/ud', 'pid/output/u_total', 'pid/output/usat'
    ];
    for (var topic in topics) {
      brokerInfo.client?.unsubscribe(topic);
    }
    _refController.dispose();
    _kpController.dispose();
    _kiController.dispose();
    _kdController.dispose();
    super.dispose();
  }

  void _publishMessage(String topic, String message) {
    if (brokerInfo.client?.connectionStatus?.state != MqttConnectionState.connected) {
      _showFeedbackDialog('Erro', 'Não conectado ao broker MQTT.');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(message);
    brokerInfo.client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _aplicarGanhosEAtivar() {
    if (_refController.text.isNotEmpty &&
        _kpController.text.isNotEmpty &&
        _kiController.text.isNotEmpty &&
        _kdController.text.isNotEmpty) {
      
      _publishMessage('pid/setpoint/ref', _refController.text.replaceAll(',', '.'));
      _publishMessage('pid/setpoint/kp', _kpController.text.replaceAll(',', '.'));
      _publishMessage('pid/setpoint/ki', _kiController.text.replaceAll(',', '.'));
      _publishMessage('pid/setpoint/kd', _kdController.text.replaceAll(',', '.'));
      _publishMessage('pid/comando', 'ATIVAR_PID');
      _showFeedbackDialog('Enviado!', 'Parâmetros PID enviados e controlador ativado.');
    } else {
      _showFeedbackDialog('Erro', 'Por favor, preencha todos os campos de parâmetros.');
    }
  }

  void _pararSistema() {
    _publishMessage('pid/comando', 'PARAR');
    _showFeedbackDialog('Enviado!', 'Comando para PARAR o sistema foi enviado.');
  }

  void _showFeedbackDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [ TextButton(child: const Text("OK"), onPressed: () => Navigator.of(context).pop()) ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controlador PID', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfPage(pdfAssetPath: widget.pdfAssetPath))),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        child: const Icon(Icons.question_mark, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Parar Sistema'),
              onPressed: _pararSistema,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildStatusDisplay(),
            const SizedBox(height: 24),
            _buildPidControlCard(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusDisplay() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monitoramento em Tempo Real', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ValueListenableBuilder<String>(valueListenable: expStatus, builder: (c, val, w) => Text('Status: $val', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(valueListenable: theta, builder: (c, val, w) => Text('Posição (Theta): ${val.toStringAsFixed(2)} °', style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 12),
            Text('Componentes do Controle:', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: ValueListenableBuilder<double>(valueListenable: up, builder: (c, val, w) => Text(' • Proporcional (Up): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: ValueListenableBuilder<double>(valueListenable: ui, builder: (c, val, w) => Text(' • Integral (Ui): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: ValueListenableBuilder<double>(valueListenable: ud, builder: (c, val, w) => Text(' • Derivativo (Ud): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
            ),
            const Divider(height: 20),
            ValueListenableBuilder<double>(valueListenable: uTotal, builder: (c, val, w) => Text('Sinal Total (U): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ValueListenableBuilder<double>(valueListenable: uSat, builder: (c, val, w) => Text('Sinal Aplicado (u_sat): ${val.toStringAsFixed(2)} %', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildPidControlCard() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Parâmetros do Controlador PID', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Divider(height: 24),
            _buildParameterInputCard(
              controller: _refController,
              title: 'Referência (Graus)',
              description: 'A meta de posição angular que o controlador PID tentará alcançar e manter.',
              hintText: 'Ex: 120.0',
            ),
            const SizedBox(height: 16),
            _buildParameterInputCard(
              controller: _kpController,
              title: 'Ganho Proporcional (Kp)',
              description: 'Atua sobre o erro atual. Aumenta a velocidade da resposta.',
              hintText: 'Ex: 10.0',
            ),
            const SizedBox(height: 16),
            _buildParameterInputCard(
              controller: _kiController,
              title: 'Ganho Integral (Ki)',
              description: 'Atua sobre o erro acumulado para eliminar o erro em regime permanente.',
              hintText: 'Ex: 8.0',
            ),
            const SizedBox(height: 16),
            _buildParameterInputCard(
              controller: _kdController,
              title: 'Ganho Derivativo (Kd)',
              description: 'Atua na taxa de variação do erro para reduzir oscilações e overshoot.',
              hintText: 'Ex: 0.05',
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _aplicarGanhosEAtivar, child: const Text('Aplicar Ganhos e Ativar')),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterInputCard({ required TextEditingController controller, required String title, required String description, required String hintText }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
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