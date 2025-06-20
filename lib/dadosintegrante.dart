// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'broker.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color.fromRGBO(19, 85, 156, 1);

    return MaterialApp(
      title: 'Gerenciador de Experimento',
      theme: ThemeData(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white, 
          titleTextStyle: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: const UnifiedScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- SINGLETON PARA INFORMAÇÕES DO BROKER ---
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
    required VoidCallback onStateChange,
    required Function(String, String) showError,
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
        ..onConnected = () {
            status = 'Conectado';
            onStateChange();
          }
        ..onDisconnected = () {
            status = 'Desconectado';
            onStateChange();
          };

      if (credenciais) {
        await client!.connect(usuario, senha);
      } else {
        await client!.connect();
      }

      if (client!.connectionStatus!.state == MqttConnectionState.connected) {
        status = 'Conectado';
        _subscribeToTopics();
      }
    } on NoConnectionException catch (_) {
      status = 'Erro de conexão';
      showError('Falha na Conexão', 'Não foi possível se conectar ao broker. Verifique o IP e a Porta e tente novamente.');
    } on SocketException catch (_) {
      status = 'Erro de conexão';
      showError('Falha na Rede', 'Erro de comunicação. Verifique o IP do broker e sua conexão de rede.');
    } on Exception catch (e) {
      status = 'Erro de conexão';
      if (e.toString().toLowerCase().contains('bad user name or password')) {
        showError('Falha na Autenticação', 'Usuário ou senha incorretos.');
      } else {
        showError('Erro Desconhecido', 'Ocorreu um erro inesperado durante a tentativa de conexão.');
      }
    } finally {
      onStateChange();
    }
  }

  Future<void> disconnect({required VoidCallback onStateChange}) async {
    client?.disconnect();
    status = 'Desconectado';
    streamUrl.value = null;
    onStateChange();
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
        final message =
            MqttPublishPayload.bytesToStringAsString(payload.payload.message);

        if (topic == 'streamExperimento') {
          streamUrl.value = message;
        }
      }
    });
  }
}


class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  State<UnifiedScreen> createState() => _UnifiedScreenState();
}

class _UnifiedScreenState extends State<UnifiedScreen> {

  final List<TextEditingController> nameControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> matriculaControllers =
      List.generate(6, (_) => TextEditingController());
  final TextEditingController dayCtrl = TextEditingController();
  final TextEditingController monthCtrl = TextEditingController();
  final TextEditingController yearCtrl = TextEditingController();


  final TextEditingController ipController = TextEditingController();
  final TextEditingController portaController =
      TextEditingController(text: '1883');
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final BrokerInfo brokerInfo = BrokerInfo.instance;

  int currentCount = 1;

  @override
  void dispose() {
    for (var c in [
      ...nameControllers,
      ...matriculaControllers,
      dayCtrl,
      monthCtrl,
      yearCtrl,
      ipController,
      portaController,
      usuarioController,
      senhaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }


  void _onAddMember() {
    if (currentCount < 6) {
      setState(() {
        currentCount++;
      });
    }
  }

  void _onRemoveMember(int index) {
    setState(() {
      for (int i = index; i < currentCount - 1; i++) {
        nameControllers[i].text = nameControllers[i + 1].text;
        matriculaControllers[i].text = matriculaControllers[i + 1].text;
      }
      nameControllers[currentCount - 1].clear();
      matriculaControllers[currentCount - 1].clear();
      currentCount--;
    });
  }
  
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar Tudo'),
        content: const Text(
            'Tem certeza que deseja apagar todos os dados preenchidos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (var c in [
                  ...nameControllers,
                  ...matriculaControllers,
                  dayCtrl,
                  monthCtrl,
                  yearCtrl,
                  ipController,
                  portaController,
                  usuarioController,
                  senhaController,
                ]) {
                  c.clear();
                }
                portaController.text = '1883';
                currentCount = 1;
              });
              Navigator.pop(context);
            },
            child: Text('Confirmar',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }


  Future<void> _connect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none && mounted) {
      _showDialog('Sem Internet', 'Por favor, verifique sua conexão com a internet e tente novamente.');
      return;
    }

    await brokerInfo.connect(
      ip: ipController.text.trim(),
      porta: int.tryParse(portaController.text.trim()) ?? 1883,
      usuario: usuarioController.text.trim(),
      senha: senhaController.text.trim(),
      credenciais: brokerInfo.credenciais,
      onStateChange: () => setState(() {}),

      showError: _showDialog,
    );
  }

  Future<void> _disconnect() async {
    await brokerInfo.disconnect(onStateChange: () => setState(() {}));
    _showDialog('Desconectado', 'Você foi desconectado do broker.');
  }

  void _showDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isConnected = brokerInfo.status == 'Conectado';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.white,
          tooltip: 'Limpar todos os dados',
          onPressed: _confirmClearAll,
        ),
        title: const Text(
          'Dados e Conexão',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            color: Colors.white,
            tooltip: 'Avançar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EscolhaExperimento()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Seção Broker ---
            _buildSectionHeader('Conexão com Broker', theme),
            const SizedBox(height: 16),
            if (isConnected)
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 120,
                      child: Lottie.asset('assets/TudoCerto.json', repeat: false),
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
            const SizedBox(height: 24),

            const Divider(height: 32, thickness: 1),


            _buildSectionHeader('Integrantes do Grupo', theme),
            const SizedBox(height: 8),
            ...List.generate(currentCount, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _buildMemberInputs(i, theme),
              );
            }),
            const SizedBox(height: 24),


            _buildSectionHeader('Data do Experimento', theme),
            const SizedBox(height: 8),
            _buildDateInputs(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isConnected ? _disconnect : _connect,
        tooltip: isConnected ? 'Desconectar' : 'Conectar ao Broker',
        backgroundColor: isConnected ? Colors.redAccent : theme.primaryColor,
        foregroundColor: Colors.white,
        child: Icon(isConnected ? Icons.cloud_off : Icons.cloud_upload_outlined),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMemberInputs(int i, ThemeData theme) {
    final bool isLastItem = i == currentCount - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Integrante ${i + 1}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentCount > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent),
                    tooltip: 'Remover Integrante',
                    onPressed: () => _onRemoveMember(i),
                  ),
                if (currentCount > 1 && currentCount < 6 && isLastItem)
                  const SizedBox(width: 4),
                if (currentCount < 6 && isLastItem)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        color: theme.primaryColor),
                    tooltip: 'Adicionar Integrante',
                    onPressed: _onAddMember,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameControllers[i],
          decoration: _inputDecoration('Nome Completo', theme),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: matriculaControllers[i],
          decoration: _inputDecoration('Matrícula', theme),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildBrokerInputs(ThemeData theme) {
    return Column(
      children: [
        TextFormField(
          controller: ipController,
          decoration: _inputDecoration('IP do Broker', theme),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: portaController,
          decoration: _inputDecoration('Porta', theme),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("Usar credenciais?"),
          value: brokerInfo.credenciais,
          onChanged: (value) => setState(() => brokerInfo.credenciais = value),
          activeColor: theme.primaryColor,
          contentPadding: EdgeInsets.zero,
        ),
        if (brokerInfo.credenciais) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: usuarioController,
            decoration: _inputDecoration('Usuário', theme),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: senhaController,
            decoration: _inputDecoration('Senha', theme),
            obscureText: true,
          ),
        ]
      ],
    );
  }

  Widget _buildDateInputs(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: dayCtrl,
            decoration: _inputDecoration('Dia', theme),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2)
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: monthCtrl,
            decoration: _inputDecoration('Mês', theme),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2)
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: yearCtrl,
            decoration: _inputDecoration('Ano', theme),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4)
            ],
          ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }
}



