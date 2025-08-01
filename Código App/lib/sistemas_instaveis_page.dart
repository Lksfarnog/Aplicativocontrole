import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart';

class SistemasInstaveisPage extends StatefulWidget {
  final String pdfAssetPath;
  const SistemasInstaveisPage({super.key, required this.pdfAssetPath});

  @override
  State<SistemasInstaveisPage> createState() => _SistemasInstaveisPageState();
}

class _SistemasInstaveisPageState extends State<SistemasInstaveisPage> {
  final _refController = TextEditingController(text: '0.0');
  final _kpController = TextEditingController();
  final _kLeadLagController = TextEditingController();
  final _aLeadLagController = TextEditingController();
  final _bLeadLagController = TextEditingController();
  final brokerInfo = BrokerInfo.instance;

  final ValueNotifier<String> expStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> theta = ValueNotifier<double>(0.0);
  final ValueNotifier<double> torque = ValueNotifier<double>(0.0);
  final ValueNotifier<double> pwm = ValueNotifier<double>(0.0);

  StreamSubscription? mqttSubscription;

  @override
  void initState() {
    super.initState();
    _setupMqttListener();
  }

  void _setupMqttListener() {
    if (brokerInfo.client?.connectionStatus?.state ==
        MqttConnectionState.connected) {
      const topics = [
        'instaveis/status',
        'instaveis/theta',
        'instaveis/torque',
        'instaveis/pwm'
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
            case 'instaveis/status':
              expStatus.value = payload;
              break;
            case 'instaveis/theta':
              theta.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'instaveis/torque':
              torque.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'instaveis/pwm':
              pwm.value = double.tryParse(payload) ?? 0.0;
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
      'instaveis/status',
      'instaveis/theta',
      'instaveis/torque',
      'instaveis/pwm'
    ];
    for (var topic in topics) {
      brokerInfo.client?.unsubscribe(topic);
    }
    _refController.dispose();
    _kpController.dispose();
    _kLeadLagController.dispose();
    _aLeadLagController.dispose();
    _bLeadLagController.dispose();
    super.dispose();
  }

  void _publishMessage(String topic, String message) {
    if (brokerInfo.client?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      _showFeedbackDialog('Erro', 'Não conectado ao broker MQTT.');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(message);
    brokerInfo.client!
        .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _enviarControladorP() {
    if (_kpController.text.isNotEmpty && _refController.text.isNotEmpty) {
      _publishMessage(
          'instaveis/proporcional/kp', _kpController.text.replaceAll(',', '.'));
      _publishMessage(
          'instaveis/set_reference', _refController.text.replaceAll(',', '.'));
      _publishMessage('instaveis/comando', 'ATIVAR_P');
      _showFeedbackDialog('Enviado!', 'Controlador Proporcional ativado.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha a Referência e o Ganho Kp.');
    }
  }

  void _enviarControladorLeadLag() {
    if (_kLeadLagController.text.isNotEmpty &&
        _aLeadLagController.text.isNotEmpty &&
        _bLeadLagController.text.isNotEmpty &&
        _refController.text.isNotEmpty) {
      _publishMessage('instaveis/leadlag/k_barra',
          _kLeadLagController.text.replaceAll(',', '.'));
      _publishMessage('instaveis/leadlag/a_barra',
          _aLeadLagController.text.replaceAll(',', '.'));
      _publishMessage('instaveis/leadlag/b_barra',
          _bLeadLagController.text.replaceAll(',', '.'));
      _publishMessage(
          'instaveis/set_reference', _refController.text.replaceAll(',', '.'));
      _publishMessage('instaveis/comando', 'ATIVAR_LEADLAG');
      _showFeedbackDialog('Enviado!', 'Controlador Lead-Lag ativado.');
    } else {
      _showFeedbackDialog(
          'Erro', 'Preencha todos os campos do controlador Lead-Lag.');
    }
  }

  void _pararSistema() {
    _publishMessage('instaveis/comando', 'PARAR');
    _showFeedbackDialog(
        'Enviado!', 'Comando para PARAR o sistema foi enviado.');
  }

  void _showFeedbackDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop())
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistemas Instáveis',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    PdfPage(pdfAssetPath: widget.pdfAssetPath))),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _refController,
                label: 'Referência Global (Graus)',
                hint: 'Ex: 0.0 ou 20.0'),
            const SizedBox(height: 16),
            _buildStatusDisplay(),
            const SizedBox(height: 24),
            _buildProporcionalCard(),
            const SizedBox(height: 24),
            _buildLeadLagCard(),
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
                builder: (c, val, w) => Text('Controlador Ativo: $val',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: theta,
                builder: (c, val, w) => Text(
                    'Ângulo (Theta): ${val.toStringAsFixed(2)} °',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: torque,
                builder: (c, val, w) => Text(
                    'Torque (T): ${val.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: pwm,
                builder: (c, val, w) => Text(
                    'Sinal PWM (u): ${val.toStringAsFixed(2)} %',
                    style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildProporcionalCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Controlador Proporcional',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Divider(height: 24),
            _buildTextField(
                controller: _kpController,
                label: 'Ganho Proporcional (Kp)',
                hint: 'Ex: 0.5'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _enviarControladorP,
                child: const Text('Ativar Controlador P')),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadLagCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Controlador Lead-Lag (Avançado)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Divider(height: 24),
            _buildTextField(
                controller: _kLeadLagController,
                label: 'Ganho (K_barra)',
                hint: 'Valor do projeto'),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _aLeadLagController,
                label: 'Parâmetro (a_barra)',
                hint: 'Valor do projeto'),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _bLeadLagController,
                label: 'Parâmetro (b_barra)',
                hint: 'Valor do projeto'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _enviarControladorLeadLag,
                child: const Text('Ativar Controlador Lead-Lag')),
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
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]'))],
    );
  }
}
