import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'broker.dart';
import 'ip_input_formatter.dart';

class BrokerInfo {
  static final BrokerInfo instance = BrokerInfo._internal();
  factory BrokerInfo() => instance;
  BrokerInfo._internal();

  MqttServerClient? client;
  String ip = '';
  int porta = 1883;
  String usuario = '';
  String senha = '';
  bool credenciais = true;
  String status = 'Desconectado';
  ValueNotifier<String?> streamUrl = ValueNotifier<String?>(null);

  Future<bool> connect({
    required String ip,
    required int porta,
    required String usuario,
    required String senha,
    required bool credenciais,
    required String clientId,
    required VoidCallback onStateChange,
  }) async {
    this.ip = ip;
    this.porta = porta;
    this.usuario = usuario;
    this.senha = senha;
    this.credenciais = credenciais;

    final effectiveClientId = clientId.isNotEmpty
        ? clientId
        : 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient(ip, effectiveClientId);
    client!
      ..port = porta
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..onConnected = () {
        status = 'Conectado';
        onStateChange();
      }
      ..onDisconnected = () {
        status = 'Desconectado';
        onStateChange();
      };

    try {
      if (credenciais) {
        await client!.connect(usuario, senha);
      } else {
        await client!.connect();
      }

      if (client!.connectionStatus!.state == MqttConnectionState.connected) {
        status = 'Conectado';
        onStateChange();

        return true;
      }
    } catch (e) {
      status = 'Erro Desconhecido.\nDetalhes: $e';
    } finally {
      onStateChange();
    }
    return false;
  }

  Future<void> disconnect({required VoidCallback onStateChange}) async {
    client?.disconnect();
    status = 'Desconectado';
    onStateChange();
  }
}

class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  State<UnifiedScreen> createState() => _UnifiedScreenState();
}

class _UnifiedScreenState extends State<UnifiedScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();

  final TextEditingController ipController = TextEditingController();
  final TextEditingController portaController =
      TextEditingController(text: '1883');
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final BrokerInfo brokerInfo = BrokerInfo.instance;

  @override
  void initState() {
    super.initState();

    ipController.text = brokerInfo.ip;
    portaController.text = brokerInfo.porta.toString();
    usuarioController.text = brokerInfo.usuario;
    senhaController.text = brokerInfo.senha;
  }

  @override
  void dispose() {
    for (var c in [
      nameController,
      matriculaController,
      ipController,
      portaController,
      usuarioController,
      senhaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connectOrDisconnect() async {
    if (brokerInfo.client != null &&
        brokerInfo.client!.connectionStatus!.state ==
            MqttConnectionState.connected) {
      await brokerInfo.disconnect(onStateChange: () => setState(() {}));
      _clearAllFields();
      _showInfoDialog("Desconectado", "Você foi desconectado do broker.");
    } else {
      if (nameController.text.trim().isEmpty) {
        _showErrorDialog("Campo Obrigatório",
            "Por favor, preencha o nome do aluno para ser usado como Client ID.");
        return;
      }
      if (ipController.text.trim().isEmpty) {
        _showErrorDialog(
            "Campo Obrigatório", "Por favor, informe o IP do broker.");
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none && mounted) {
        _showErrorDialog(
            "Sem Internet", "Por favor, verifique sua conexão com a internet.");
        return;
      }

      final String clientId = nameController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Conectando..."),
            ],
          ),
        ),
      );

      final bool connected = await brokerInfo.connect(
        ip: ipController.text.trim(),
        porta: int.tryParse(portaController.text.trim()) ?? 1883,
        usuario: usuarioController.text.trim(),
        senha: senhaController.text.trim(),
        credenciais: brokerInfo.credenciais,
        clientId: clientId,
        onStateChange: () => setState(() {}),
      );

      if (mounted) {
        Navigator.pop(context);
        _showConnectionResultDialog(connected);
      }
    }
  }

  void _showConnectionResultDialog(bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success ? "Sucesso!" : "Falha na Conexão"),
        content: Text(success
            ? "A conexão com o broker MQTT foi estabelecida e a mensagem de sucesso publicada."
            : brokerInfo.status),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _clearAllFields() {
    setState(() {
      nameController.clear();
      matriculaController.clear();
      ipController.clear();
      portaController.text = '1883';
      usuarioController.clear();
      senhaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isConnected = brokerInfo.status == 'Conectado';

    final bool canProceedToExperiments = isConnected;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.white,
          tooltip: 'Limpar todos os dados',
          onPressed: _clearAllFields,
        ),
        title: const Text('Dados e Conexão',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionContainer(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Conexão com Broker', theme),
                const SizedBox(height: 16),
                if (isConnected)
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 150,
                          height: 120,
                          child: Lottie.asset('assets/TudoCerto.json',
                              repeat: false),
                        ),
                        const Text('Conectado!',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                _buildBrokerInputs(theme),
              ],
            )),
            const SizedBox(height: 24),
            _buildSectionContainer(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Dados do Aluno', theme),
                const SizedBox(height: 8),
                _buildStudentInputs(theme),
              ],
            )),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _connectOrDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isConnected ? 'Desconectar' : 'Conectar',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canProceedToExperiments
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EscolhaExperimento()),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canProceedToExperiments ? theme.primaryColor : Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Avançar para Experimentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokerInputs(ThemeData theme) {
    bool areCredentialsEnabled = brokerInfo.credenciais;

    return Column(
      children: [
        TextFormField(
          controller: ipController,
          decoration: _inputDecoration('IP do Broker', theme),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            IpAddressInputFormatter()
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: portaController,
          decoration: _inputDecoration('Porta', theme),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Sem Credenciais'),
              selected: !areCredentialsEnabled,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    brokerInfo.credenciais = false;
                    usuarioController.clear();
                    senhaController.clear();
                  });
                }
              },
              selectedColor: theme.primaryColor.withOpacity(0.1),
              labelStyle: TextStyle(
                  color: !areCredentialsEnabled
                      ? theme.primaryColor
                      : Colors.black87,
                  fontWeight: !areCredentialsEnabled
                      ? FontWeight.bold
                      : FontWeight.normal),
              side: BorderSide(
                color: !areCredentialsEnabled
                    ? theme.primaryColor
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('Com Credenciais'),
              selected: areCredentialsEnabled,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    brokerInfo.credenciais = true;
                  });
                }
              },
              selectedColor: theme.primaryColor.withOpacity(0.1),
              labelStyle: TextStyle(
                  color: areCredentialsEnabled
                      ? theme.primaryColor
                      : Colors.black87,
                  fontWeight: areCredentialsEnabled
                      ? FontWeight.bold
                      : FontWeight.normal),
              side: BorderSide(
                color: areCredentialsEnabled
                    ? theme.primaryColor
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          enabled: areCredentialsEnabled,
          controller: usuarioController,
          decoration: _inputDecoration('Usuário', theme),
        ),
        const SizedBox(height: 16),
        TextFormField(
          enabled: areCredentialsEnabled,
          controller: senhaController,
          decoration: _inputDecoration('Senha', theme),
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromRGBO(19, 85, 156, 1).withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStudentInputs(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: nameController,
          decoration: _inputDecoration('Nome Completo do Aluno', theme),
          inputFormatters: [],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: matriculaController,
          decoration: _inputDecoration('Matrícula do Aluno', theme),
          inputFormatters: [],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, ThemeData theme) {
    return InputDecoration(
      labelText: label,
      filled: false,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }
}
