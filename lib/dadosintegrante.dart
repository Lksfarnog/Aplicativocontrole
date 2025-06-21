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
        
      }
    } on NoConnectionException catch (_) {
      status = 'Erro de conexão';
    } on SocketException catch (_) {
      status = 'Erro de conexão';
    } on Exception catch (_) {
      status = 'Erro de conexão';
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

  void _clearAllFields() {
    setState(() {
      for (var c in [
        ...nameControllers,
        ...matriculaControllers,
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
  }

  Future<void> _connect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none && mounted) {
      return;
    }

    await brokerInfo.connect(
      ip: ipController.text.trim(),
      porta: int.tryParse(portaController.text.trim()) ?? 1883,
      usuario: usuarioController.text.trim(),
      senha: senhaController.text.trim(),
      credenciais: brokerInfo.credenciais,
      onStateChange: () => setState(() {}),
    );
  }

  Future<void> _advanceToBroker() async {
    await _connect();
    if (mounted) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EscolhaExperimento()),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isConnected = brokerInfo.status == 'Conectado';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.white,
          tooltip: 'Limpar todos os dados',
          onPressed: _clearAllFields,
        ),
        title: const Text(
          'Dados e Conexão',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: const [],
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
                ],
              )
            ),
            const SizedBox(height: 24),
            _buildSectionContainer(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Integrantes do Grupo', theme),
                  const SizedBox(height: 8),
                  ...List.generate(currentCount, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: _buildMemberInputs(i, theme),
                    );
                  }),
                ],
              )
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _advanceToBroker,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Avançar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
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
        const SizedBox(height: 8),
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
    bool areCredentialsEnabled = brokerInfo.credenciais;

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
                color: !areCredentialsEnabled ? theme.primaryColor : Colors.black87,
                fontWeight: !areCredentialsEnabled ? FontWeight.bold : FontWeight.normal
              ),
               side: BorderSide(
                color: !areCredentialsEnabled ? theme.primaryColor : Colors.grey.shade400,
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
                color: areCredentialsEnabled ? theme.primaryColor : Colors.black87,
                fontWeight: areCredentialsEnabled ? FontWeight.bold : FontWeight.normal
              ),
              side: BorderSide(
                color: areCredentialsEnabled ? theme.primaryColor : Colors.grey.shade400,
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
