import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dadosintegrante.dart';

class ConectaBrokerPage extends StatefulWidget {
  const ConectaBrokerPage({super.key});

  @override
  State<ConectaBrokerPage> createState() => _ConectaBrokerPageState();
}

class BrokerInfo {
  static final BrokerInfo instance = BrokerInfo._internal();
  factory BrokerInfo() => instance;
  BrokerInfo._internal();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  MqttServerClient? client;
  String ip = '';
  int porta = 1883;
  String usuario = '';
  String senha = '';
  bool credenciais = true;
  String status = 'Desconectado';
  ValueNotifier<String?> streamUrl = ValueNotifier<String?>(null);

  Future<void> connect({
    required String ip,
    required int porta,
    required String usuario,
    required String senha,
    required bool credenciais,
  }) async {
    try {
      this.ip = ip;
      this.porta = porta;
      this.usuario = usuario;
      this.senha = senha;
      this.credenciais = credenciais;

      client = MqttServerClient(ip, 'flutter_client');
      client!
        ..port = porta
        ..logging(on: false)
        ..keepAlivePeriod = 30
        ..autoReconnect = true
        ..resubscribeOnAutoReconnect = true
        ..onConnected = _onConnected
        ..onDisconnected = _onDisconnected;

      if (credenciais) {
        await client!.connect(usuario, senha);
      } else {
        await client!.connect(null, null);
      }

      if (client!.connectionStatus!.state == MqttConnectionState.connected) {
        status = 'Conectado';
        
        _subscribeToTopics();
      }
    } catch (e) {
      status = 'Erro de conexão';
      _showErrorDialog('Erro: ${e.toString()}');
    }
  }

  Future<void> disconnect() async {
    client?.disconnect();
    status = 'Desconectado';
    streamUrl.value = null;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _onConnected() {
    status = 'Conectado';
  }

  void _onDisconnected() {
    status = 'Desconectado';
  }

  void _subscribeToTopics() {
    client?.subscribe('observadorKe', MqttQos.atLeastOnce);
    client?.subscribe('reguladorK', MqttQos.atLeastOnce);
    client?.subscribe('nx', MqttQos.atLeastOnce);
    client?.subscribe('nu', MqttQos.atLeastOnce);
    client?.subscribe('streamExperimento', MqttQos.atLeastOnce);

    client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var msg in messages) {
        final topic = msg.topic;
        final payload = msg.payload as MqttPublishMessage;
        final message = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

        if (topic == 'streamExperimento') {
          streamUrl.value = message;
        }
      }
    });
  }



  void publish(String topic, String message) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      _publishMessage(topic, message);
    }
  }

  void _publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _showErrorDialog(String message) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlertDialog(
          title: const Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConectaBrokerPageState extends State<ConectaBrokerPage> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portaController = TextEditingController(text: '1883');
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final BrokerInfo brokerInfo = BrokerInfo.instance;

  @override
  void dispose() {
    ipController.dispose();
    portaController.dispose();
    usuarioController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _showDialog('Erro!', 'Sem conexão com a internet');
      return;
    }

    try {
      await brokerInfo.connect(
        ip: ipController.text.trim(),
        porta: int.tryParse(portaController.text.trim()) ?? 1883,
        usuario: usuarioController.text.trim(),
        senha: senhaController.text.trim(),
        credenciais: brokerInfo.credenciais,
      );

      if (brokerInfo.status == 'Conectado') {
        _showDialog('Sucesso!', 'Conectado ao broker com sucesso', onOk: () {
          final homeState = context.findAncestorStateOfType<HomeScreenState>();
          homeState?.setState(() => homeState.currentIndex = 2);
        });
      }
    } catch (e) {
      _showDialog('Erro', 'Falha na conexão: $e');
    }
    setState(() {});
  }

  Future<void> _disconnect() async {
    await brokerInfo.disconnect();
    _showDialog('Desconectado', 'Você foi desconectado do broker.');
    setState(() {});
  }

  void _showDialog(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar Dados'),
        content: const Text('Tem certeza que deseja limpar e voltar ao início?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ipController.clear();
              portaController.clear();
              usuarioController.clear();
              senhaController.clear();
              brokerInfo.disconnect();
              Navigator.pop(context);
              final homeState = context.findAncestorStateOfType<HomeScreenState>();
              homeState?.setState(() => homeState.currentIndex = 0);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações do Broker'),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: _confirmClearAll),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (brokerInfo.status == 'Conectado') ...[
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 140,
                      child: Lottie.asset('assets/TudoCerto.json'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Conectado ao broker!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
            TextFormField(
              controller: ipController,
              decoration: const InputDecoration(
                icon: Icon(Icons.router),
                labelText: 'IP do Broker',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: portaController,
              decoration: const InputDecoration(
                icon: Icon(Icons.door_front_door),
                labelText: 'Porta',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Usa credenciais?'),
                Switch(
                  value: brokerInfo.credenciais,
                  onChanged: (v) => setState(() => brokerInfo.credenciais = v),
                  activeColor: const Color.fromRGBO(19, 85, 156, 1),
                ),
              ],
            ),
            if (brokerInfo.credenciais) ...[
              TextFormField(
                controller: usuarioController,
                decoration: const InputDecoration(
                  icon: Icon(Icons.badge),
                  labelText: 'Usuário',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: senhaController,
                decoration: const InputDecoration(
                  icon: Icon(Icons.lock),
                  labelText: 'Senha',
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: brokerInfo.status == 'Conectado' ? _disconnect : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: brokerInfo.status == 'Conectado'
                    ? Colors.red
                    : const Color.fromRGBO(19, 85, 156, 1),
                minimumSize: const Size.fromHeight(55),
              ),
              child: Text(
                brokerInfo.status == 'Conectado' ? 'Desconectar' : 'Conectar',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 80),
          _buildStatusRow(),
          _buildInfoRow(Icons.router, 'IP', brokerInfo.ip),
          _buildInfoRow(Icons.door_front_door, 'Porta', '${brokerInfo.porta}'),
          if (brokerInfo.credenciais) _buildInfoRow(Icons.person, 'Usuário', brokerInfo.usuario),
          if (brokerInfo.credenciais) _buildInfoRow(Icons.lock, 'Senha', brokerInfo.senha),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return ListTile(
      leading: Icon(brokerInfo.status == 'Conectado' ? Icons.cloud_done : Icons.cloud_off,
          color: Colors.white),
      title: Text('Status: ${brokerInfo.status}', style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text('$label: $value', style: const TextStyle(color: Colors.white)),
    );
  }
}
