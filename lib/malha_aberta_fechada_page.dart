import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dadosintegrante.dart';
import 'broker.dart'; // Importa a classe PdfPage do arquivo broker.dart

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

  @override
  void dispose() {
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
    brokerInfo.client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
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
        title: const Text('Malha Aberta vs. Fechada', style: TextStyle(color: Colors.white)),
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
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            _buildStatusDisplay(),

          const SizedBox(height: 24),


            _buildControlCard(
              title: 'Controle em Malha Aberta',
              children: [
                _buildTextField(
                  controller: _uMAController,
                  label: 'Duty Cycle (%)',
                  hint: 'Ex: 50.0',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _enviarMalhaAberta,
                  child: const Text('Enviar Comando de Malha Aberta'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildControlCard(
              title: 'Controle em Malha Fechada',
              children: [
                _buildTextField(
                  controller: _refMFController,
                  label: 'Referência (RPM)',
                  hint: 'Ex: 1500.0',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _kpMFController,
                  label: 'Ganho Proporcional (Kp)',
                  hint: 'Ex: 0.15',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _enviarMalhaFechada,
                  child: const Text('Enviar Comando de Malha Fechada'),
                ),
              ],
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
            // Cada ValueListenableBuilder se reconstrói sozinho quando o valor muda
            ValueListenableBuilder<String>(
              valueListenable: brokerInfo.motorStatus,
              builder: (context, status, child) => Text('Status: $status', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: brokerInfo.velocidadeRpm,
              builder: (context, velocidade, child) => Text('Velocidade: ${velocidade.toStringAsFixed(2)} RPM', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: brokerInfo.uMF,
              builder: (context, u, child) => Text('Sinal de Controle (u): ${u.toStringAsFixed(2)} %', style: const TextStyle(fontSize: 16)),
            ),
             const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: brokerInfo.erroMF,
              builder: (context, erro, child) => Text('Erro (Ref - Vel): ${erro.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
    );
  }
}