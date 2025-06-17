// dados_experimentos_page.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'broker.dart';
import 'dadosintegrante.dart';

class ExperimentoData {
  static final ExperimentoData _instance = ExperimentoData._internal();
  factory ExperimentoData() => _instance;
  ExperimentoData._internal();

  final Map<String, String> valores = {
    'observadorKe': '',
    'reguladorK': '',
    'nx': '',
    'nu': '',
    'referencia': '',
  };
}

class DadosExperimentosPage extends StatefulWidget {
  const DadosExperimentosPage({super.key});

  @override
  State<DadosExperimentosPage> createState() => _DadosExperimentosPageState();
}

class _DadosExperimentosPageState extends State<DadosExperimentosPage> {
  final observadorKeController = TextEditingController();
  final reguladorKController = TextEditingController();
  final nxController = TextEditingController();
  final nuController = TextEditingController();
  final referenciaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final dados = ExperimentoData();
    observadorKeController.text = dados.valores['observadorKe']!;
    reguladorKController.text = dados.valores['reguladorK']!;
    nxController.text = dados.valores['nx']!;
    nuController.text = dados.valores['nu']!;
    referenciaController.text = dados.valores['referencia']!;
    observadorKeController.addListener(() {
      dados.valores['observadorKe'] = observadorKeController.text;
    });
    reguladorKController.addListener(() {
      dados.valores['reguladorK'] = reguladorKController.text;
    });
    nxController.addListener(() {
      dados.valores['nx'] = nxController.text;
    });
    nuController.addListener(() {
      dados.valores['nu'] = nuController.text;
    });
    referenciaController.addListener(() {
      dados.valores['referencia'] = referenciaController.text;
    });
  }

  @override
  void dispose() {
    observadorKeController.dispose();
    reguladorKController.dispose();
    nxController.dispose();
    nuController.dispose();
    referenciaController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erro', style: TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    ); 
  }

  Future<void> _enviarDados() async {
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      _showError('Sem conexão com a Internet!');
      return;
    }
    final broker = BrokerInfo.instance;
    if (broker.credenciais && (broker.usuario.isEmpty || broker.senha.isEmpty)) {
      _showError('Usuário ou senha do Broker não configurados!');
      return;
    }
    if (observadorKeController.text.isEmpty ||
        reguladorKController.text.isEmpty ||
        nxController.text.isEmpty ||
        nuController.text.isEmpty) {
      _showError('Preencha todos os campos antes de enviar!');
      return;
    }

    final client = MqttServerClient(broker.ip, 'flutter_client');
    client.port = broker.porta;
    client.keepAlivePeriod = 20;
    client.secure = false;
    if (broker.credenciais) {
      client.setProtocolV311();
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier('flutter_client')
          .authenticateAs(broker.usuario, broker.senha)
          .startClean();
    }
    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        _showError('Não foi possível conectar ao Broker!');
        return;
      }
      final campos = {
        'observadorKe': observadorKeController,
        'reguladorK': reguladorKController,
        'nx': nxController,
        'nu': nuController,
        'referencia': referenciaController,
      };
      for (var entry in campos.entries) {
        final builder = MqttClientPayloadBuilder()..addString(entry.value.text.trim());
        client.publishMessage(entry.key, MqttQos.atMostOnce, builder.payload!);
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sucesso!'),
          content: const Text('Dados enviados com sucesso para o Broker!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                
                final homeState = context.findAncestorStateOfType<HomeScreenState>();
                homeState?.setState(() => homeState.currentIndex = 3);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Erro ao conectar ao Broker: $e');
    } finally {
      client.unsubscribe('#');
      client.disconnect();
    }
  }

  Widget _campo(String label, TextEditingController ctrl, IconData icon, String info) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color.fromRGBO(19,85,156,1)),
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.help, color: Color.fromRGBO(19,85,156,1)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(label),
                  content: SingleChildScrollView(child: Text(info)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                  ],
                ),
              );
            },
          ),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [LengthLimitingTextInputFormatter(15)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final broker = BrokerInfo.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados do Experimento'),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        backgroundColor: const Color.fromRGBO(19,85,156,1),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 80),
            ListTile(
              leading: Icon(
                broker.status == 'Conectado' ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
              ),
              title: Text('Status: ${broker.status}', style: const TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.router, color: Colors.white),
              title: Text('IP: ${broker.ip}', style: const TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.door_front_door, color: Colors.white),
              title: Text('Porta: ${broker.porta}', style: const TextStyle(color: Colors.white)),
            ),
            if (broker.credenciais)
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: Text('Usuário: ${broker.usuario}', style: const TextStyle(color: Colors.white)),
              ),
            if (broker.credenciais)
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.white),
                title: Text('Senha: ${broker.senha}', style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _campo('Observador Ke', observadorKeController, Icons.visibility,
                'Instruções para cálculo do observador...'),
            _campo('Regulador K', reguladorKController, Icons.tune,
                'Instruções para cálculo do regulador...'),
            _campo('N° de Estados (Nx)', nxController, Icons.analytics,
                'Instruções para determinar Nx...'),
            _campo('N° de Entradas (Nu)', nuController, Icons.list_alt,
                'Instruções para determinar Nu...'),
            _campo('Referência', referenciaController, Icons.flag,
                'Defina a altura de referência desejada.'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _enviarDados,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
                minimumSize: const Size.fromHeight(55),
              ),
              child: const Text(
                'Enviar dados do Experimento',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
