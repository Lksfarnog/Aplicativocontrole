import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart';

class RespostaFrequenciaPage extends StatefulWidget {
  final String pdfAssetPath;
  const RespostaFrequenciaPage({super.key, required this.pdfAssetPath});

  @override
  State<RespostaFrequenciaPage> createState() => _RespostaFrequenciaPageState();
}

class _RespostaFrequenciaPageState extends State<RespostaFrequenciaPage>
    with SingleTickerProviderStateMixin {
  final _ampSenoideController = TextEditingController(text: '80.0');
  final _omegaSenoideController = TextEditingController(text: '0.1');
  final _refMfController = TextEditingController(text: '200.0');
  final _a1CompensadorController = TextEditingController();
  final _a2CompensadorController = TextEditingController();
  final _bCompensadorController = TextEditingController();
  final brokerInfo = BrokerInfo.instance;

  final ValueNotifier<String> expStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> inputU = ValueNotifier<double>(0.0);
  final ValueNotifier<double> outputY = ValueNotifier<double>(0.0);
  final ValueNotifier<double> erro = ValueNotifier<double>(0.0);

  StreamSubscription? mqttSubscription;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupMqttListener();
  }

  void _setupMqttListener() {
    if (brokerInfo.client?.connectionStatus?.state ==
        MqttConnectionState.connected) {
      const topics = [
        'freq/status',
        'freq/data/input_u',
        'freq/data/output_y',
        'freq/data/erro'
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
            case 'freq/status':
              expStatus.value = payload;
              break;
            case 'freq/data/input_u':
              inputU.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'freq/data/output_y':
              outputY.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'freq/data/erro':
              erro.value = double.tryParse(payload) ?? 0.0;
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
      'freq/status',
      'freq/data/input_u',
      'freq/data/output_y',
      'freq/data/erro'
    ];
    for (var topic in topics) {
      brokerInfo.client?.unsubscribe(topic);
    }
    _tabController?.dispose();
    _ampSenoideController.dispose();
    _omegaSenoideController.dispose();
    _refMfController.dispose();
    _a1CompensadorController.dispose();
    _a2CompensadorController.dispose();
    _bCompensadorController.dispose();
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

  void _aplicarSenoide() {
    if (_ampSenoideController.text.isNotEmpty &&
        _omegaSenoideController.text.isNotEmpty) {
      _publishMessage(
          'freq/senoide/amp', _ampSenoideController.text.replaceAll(',', '.'));
      _publishMessage('freq/senoide/omega',
          _omegaSenoideController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_SENOIDE');
      _showFeedbackDialog('Enviado!', 'Sinal senoidal aplicado.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha Amplitude e Frequência.');
    }
  }

  void _aplicarMfUnitario() {
    if (_refMfController.text.isNotEmpty) {
      _publishMessage(
          'freq/mf/ref', _refMfController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_MF_UNITARIO');
      _showFeedbackDialog(
          'Enviado!', 'Controle em Malha Fechada (Kp=1) ativado.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha a Referência.');
    }
  }

  void _aplicarCompensador() {
    if (_a1CompensadorController.text.isNotEmpty &&
        _a2CompensadorController.text.isNotEmpty &&
        _bCompensadorController.text.isNotEmpty &&
        _refMfController.text.isNotEmpty) {
      _publishMessage(
          'freq/mf/ref', _refMfController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/a1',
          _a1CompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/a2',
          _a2CompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/b',
          _bCompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_COMPENSADOR');
      _showFeedbackDialog('Enviado!', 'Compensador digital ativado.');
    } else {
      _showFeedbackDialog('Erro', 'Preencha todos os campos do compensador.');
    }
  }

  void _pararSistema() {
    _publishMessage('freq/comando', 'PARAR');
    _showFeedbackDialog(
        'Enviado!', 'Comando para PARAR o sistema foi enviado.');
  }

  void _showFeedbackDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(title: Text(title), content: Text(content), actions: [
              TextButton(
                  child: const Text("OK"),
                  onPressed: () => Navigator.of(context).pop())
            ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resposta em Frequência',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Senoide (MA)'),
            Tab(text: 'MF (Kp=1)'),
            Tab(text: 'Compensador'),
          ],
        ),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Parar Sistema'),
                onPressed: _pararSistema,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            _buildStatusDisplay(),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSenoideTab(),
                  _buildMfUnitarioTab(),
                  _buildCompensadorTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenoideTab() {
    return SingleChildScrollView(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Entrada Senoidal (Malha Aberta)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const Divider(height: 24),
                  _buildTextField(
                      controller: _ampSenoideController,
                      label: 'Amplitude A (%)',
                      hint: 'Ex: 80.0'),
                  const SizedBox(height: 16),
                  _buildTextField(
                      controller: _omegaSenoideController,
                      label: 'Frequência ω (rad/s)',
                      hint: 'Ex: 0.1'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _aplicarSenoide,
                      child: const Text('Aplicar Sinal Senoidal')),
                ])),
      ),
    );
  }

  Widget _buildMfUnitarioTab() {
    return SingleChildScrollView(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Malha Fechada (Ganho Unitário)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const Divider(height: 24),
                  _buildTextField(
                      controller: _refMfController,
                      label: 'Referência ω_ref (rad/s)',
                      hint: 'Ex: 200.0'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _aplicarMfUnitario,
                      child: const Text('Aplicar Degrau na Referência')),
                ])),
      ),
    );
  }

  Widget _buildCompensadorTab() {
    return SingleChildScrollView(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Compensador Digital',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const Divider(height: 24),
                  _buildTextField(
                      controller: _refMfController,
                      label: 'Referência ω_ref (rad/s)',
                      hint: 'Ex: 200.0'),
                  const SizedBox(height: 16),
                  _buildTextField(
                      controller: _a1CompensadorController,
                      label: 'Parâmetro a1_barra',
                      hint: 'Valor do projeto'),
                  const SizedBox(height: 16),
                  _buildTextField(
                      controller: _a2CompensadorController,
                      label: 'Parâmetro a2_barra',
                      hint: 'Valor do projeto'),
                  const SizedBox(height: 16),
                  _buildTextField(
                      controller: _bCompensadorController,
                      label: 'Parâmetro b_barra',
                      hint: 'Valor do projeto'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _aplicarCompensador,
                      child: const Text('Ativar Compensador')),
                ])),
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
                builder: (c, val, w) => Text('Modo Atual: $val',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: inputU,
                builder: (c, val, w) => Text(
                    'Sinal de Entrada (u): ${val.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: outputY,
                builder: (c, val, w) => Text(
                    'Sinal de Saída (y): ${val.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
                valueListenable: erro,
                builder: (c, val, w) => Text(
                    'Erro (MF): ${val.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16))),
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
