// resposta_frequencia_page.dart

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

class _RespostaFrequenciaPageState extends State<RespostaFrequenciaPage> with SingleTickerProviderStateMixin {
  // --- Controladores dos campos de texto ---
  final _ampSenoideController = TextEditingController(text: '80.0');
  final _omegaSenoideController = TextEditingController(text: '0.1');
  final _refMfController = TextEditingController(text: '200.0');
  final _a1CompensadorController = TextEditingController();
  final _a2CompensadorController = TextEditingController();
  final _bCompensadorController = TextEditingController();
  final brokerInfo = BrokerInfo.instance;

  // --- ValueNotifiers para os dados em tempo real ---
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
    if (brokerInfo.client?.connectionStatus?.state == MqttConnectionState.connected) {
      const topics = ['freq/status', 'freq/data/input_u', 'freq/data/output_y', 'freq/data/erro'];
      for (var topic in topics) {
        brokerInfo.client!.subscribe(topic, MqttQos.atLeastOnce);
      }
      mqttSubscription = brokerInfo.client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final recMess = c[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topic = c[0].topic;
          switch (topic) {
            case 'freq/status': expStatus.value = payload; break;
            case 'freq/data/input_u': inputU.value = double.tryParse(payload) ?? 0.0; break;
            case 'freq/data/output_y': outputY.value = double.tryParse(payload) ?? 0.0; break;
            case 'freq/data/erro': erro.value = double.tryParse(payload) ?? 0.0; break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    mqttSubscription?.cancel();
    const topics = ['freq/status', 'freq/data/input_u', 'freq/data/output_y', 'freq/data/erro'];
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
  
  // --- Funções de Publicação MQTT ---
  void _publishMessage(String topic, String message) {
     if (brokerInfo.client?.connectionStatus?.state != MqttConnectionState.connected) {
      _showFeedbackDialog('Erro', 'Não conectado ao broker MQTT.');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(message);
    brokerInfo.client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _aplicarSenoide() {
    if (_ampSenoideController.text.isNotEmpty && _omegaSenoideController.text.isNotEmpty) {
      _publishMessage('freq/senoide/amp', _ampSenoideController.text.replaceAll(',', '.'));
      _publishMessage('freq/senoide/omega', _omegaSenoideController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_SENOIDE');
      _showFeedbackDialog('Enviado!', 'Sinal senoidal aplicado.');
    } else { _showFeedbackDialog('Erro', 'Preencha Amplitude e Frequência.');}
  }

  void _aplicarMfUnitario() {
     if (_refMfController.text.isNotEmpty) {
      _publishMessage('freq/mf/ref', _refMfController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_MF_UNITARIO');
      _showFeedbackDialog('Enviado!', 'Controle em Malha Fechada (Kp=1) ativado.');
    } else { _showFeedbackDialog('Erro', 'Preencha a Referência.');}
  }

  void _aplicarCompensador() {
    if (_a1CompensadorController.text.isNotEmpty && _a2CompensadorController.text.isNotEmpty && _bCompensadorController.text.isNotEmpty && _refMfController.text.isNotEmpty) {
      _publishMessage('freq/mf/ref', _refMfController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/a1', _a1CompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/a2', _a2CompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/compensador/b', _bCompensadorController.text.replaceAll(',', '.'));
      _publishMessage('freq/comando', 'ATIVAR_COMPENSADOR');
      _showFeedbackDialog('Enviado!', 'Compensador digital ativado.');
    } else { _showFeedbackDialog('Erro', 'Preencha todos os campos do compensador.');}
  }

  void _pararSistema() {
    _publishMessage('freq/comando', 'PARAR');
    _showFeedbackDialog('Enviado!', 'Comando para PARAR o sistema foi enviado.');
  }

  void _showFeedbackDialog(String title, String content) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(child: const Text("OK"), onPressed: () => Navigator.of(context).pop())]));
  }

  // --- Construção da Interface Gráfica ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resposta em Frequência', style: TextStyle(color: Colors.white)),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfPage(pdfAssetPath: widget.pdfAssetPath))),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        child: const Icon(Icons.question_mark, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(icon: const Icon(Icons.stop_circle_outlined), label: const Text('Parar Sistema'), onPressed: _pararSistema, style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
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

  // --- Widgets das Abas e Auxiliares ---
  Widget _buildSenoideTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildParameterInputCard(
            controller: _ampSenoideController,
            title: 'Amplitude A (%)',
            description: 'Define a amplitude (em % do duty cycle) do sinal senoidal de entrada para o teste em malha aberta.',
            hintText: 'Ex: 80.0',
          ),
          const SizedBox(height: 16),
          _buildParameterInputCard(
            controller: _omegaSenoideController,
            title: 'Frequência ω (rad/s)',
            description: 'A frequência angular do sinal senoidal de entrada, usada para levantar o diagrama de Bode do sistema.',
            hintText: 'Ex: 0.1',
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _aplicarSenoide, child: const Text('Aplicar Sinal Senoidal')),
        ],
      ),
    );
  }

  Widget _buildMfUnitarioTab() {
     return SingleChildScrollView(
      child: Column(
        children: [
          _buildParameterInputCard(
            controller: _refMfController,
            title: 'Referência ω_ref (rad/s)',
            description: 'A meta de velocidade angular para o teste em malha fechada com ganho unitário (C(s) = 1).',
            hintText: 'Ex: 200.0',
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _aplicarMfUnitario, child: const Text('Aplicar Degrau na Referência')),
        ],
      ),
    );
  }

  Widget _buildCompensadorTab() {
     return SingleChildScrollView(
      child: Column(
        children: [
          _buildParameterInputCard(
            controller: _refMfController,
            title: 'Referência ω_ref (rad/s)',
            description: 'A meta de velocidade angular para o teste com o compensador digital.',
            hintText: 'Ex: 200.0',
          ),
          const SizedBox(height: 16),
           _buildParameterInputCard(
            controller: _a1CompensadorController,
            title: 'Parâmetro a1_barra',
            description: 'Coeficiente do erro e(k) no compensador digital.',
            hintText: 'Valor do projeto',
          ),
          const SizedBox(height: 16),
           _buildParameterInputCard(
            controller: _a2CompensadorController,
            title: 'Parâmetro a2_barra',
            description: 'Coeficiente do erro e(k-1) no compensador digital.',
            hintText: 'Valor do projeto',
          ),
          const SizedBox(height: 16),
           _buildParameterInputCard(
            controller: _bCompensadorController,
            title: 'Parâmetro b_barra',
            description: 'Coeficiente de u(k-1) no compensador digital.',
            hintText: 'Valor do projeto',
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _aplicarCompensador, child: const Text('Ativar Compensador')),
        ],
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
            ValueListenableBuilder<String>(valueListenable: expStatus, builder: (c, val, w) => Text('Modo Atual: $val', style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(valueListenable: inputU, builder: (c, val, w) => Text('Sinal de Entrada (u): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(valueListenable: outputY, builder: (c, val, w) => Text('Sinal de Saída (y): ${val.toStringAsFixed(2)} rad/s', style: const TextStyle(fontSize: 16))),
             const SizedBox(height: 8),
            ValueListenableBuilder<double>(valueListenable: erro, builder: (c, val, w) => Text('Erro (MF): ${val.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterInputCard({required TextEditingController controller, required String title, required String description, required String hintText}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(hintText: hintText, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12.0)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]'))],
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}