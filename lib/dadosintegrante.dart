import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'broker.dart'; // Importa a classe BrokerInfo e EscolhaExperimento
import 'ip_input_formatter.dart';
import 'package:flutter/foundation.dart'; // Importa o formatador de IP

// =================================================================
// CLASSE SINGLETON PARA GERENCIAR O BROKER
// =================================================================
// Esta classe é um singleton para manter o estado da conexão MQTT
// e os dados do broker persistentes em todo o aplicativo.
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
  // Variável para controlar se a mensagem de sucesso da conexão foi publicada
  bool _publishedSuccessMessage = false;

  final ValueNotifier<String> motorStatus = ValueNotifier<String>('Parado');
  final ValueNotifier<double> velocidadeRpm = ValueNotifier<double>(0.0);
  final ValueNotifier<double> erroMF = ValueNotifier<double>(0.0);
  final ValueNotifier<double> uMF = ValueNotifier<double>(0.0);

  // Getter para verificar se a mensagem de sucesso foi publicada
  bool get publishedSuccessMessage => _publishedSuccessMessage;

  // Método para resetar o estado da mensagem de sucesso (usado ao desconectar)
  void resetPublishedSuccessMessage() {
    _publishedSuccessMessage = false;
  }

  // Método para conectar ao broker MQTT
  // Aceita um `clientId` e retorna um `bool` indicando o sucesso da conexão.
  Future<bool> connect({
    required String ip,
    required int porta,
    required String usuario,
    required String senha,
    required bool credenciais,
    required String clientId, // O ID do cliente agora é um parâmetro
    required VoidCallback onStateChange,
  }) async {
    // Armazena os dados de conexão para persistência
    this.ip = ip;
    this.porta = porta;
    this.usuario = usuario;
    this.senha = senha;
    this.credenciais = credenciais;

    // Garante que o ID do cliente seja único se estiver vazio
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
        onStateChange(); // Notifica a UI sobre a mudança de estado
      }
      ..onDisconnected = () {
        status = 'Desconectado';
        onStateChange(); // Notifica a UI sobre a mudança de estado
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

        // Publica a mensagem de sucesso
        final builder = MqttClientPayloadBuilder()..addString('Conexão bem-sucedida!');
        client!.publishMessage('conexao/status', MqttQos.atLeastOnce, builder.payload!);
        _publishedSuccessMessage = true;

        // ADICIONADO: Se inscreve nos tópicos de dados do ESP32
        print('Inscrevendo-se nos tópicos de dados do motor...');
        client!.subscribe('motor/status', MqttQos.atLeastOnce);
        client!.subscribe('motor/velocidade', MqttQos.atLeastOnce);
        client!.subscribe('uMF', MqttQos.atLeastOnce);
        client!.subscribe('erroMF', MqttQos.atLeastOnce);

        // ADICIONADO: Listener para processar as mensagens recebidas
        client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          // ignore: unnecessary_null_comparison
          if (c != null && c.isNotEmpty) {
            // ** INÍCIO DA CORREÇÃO **
            // 1. Fazemos o "cast" para o tipo de mensagem correto (MqttPublishMessage)
            final recMess = c[0].payload as MqttPublishMessage;
            // 2. Extraímos o payload (conteúdo) da mensagem já convertida
            final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
            // ** FIM DA CORREÇÃO **

            final String topic = c[0].topic;

          print('DADO RECEBIDO -> Tópico: $topic, Valor: $payload');

          // Atualiza os ValueNotifiers com base no tópico
          switch (topic) {
            case 'motor/status':
              motorStatus.value = payload;
              break;
            case 'motor/velocidade':
              velocidadeRpm.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'uMF':
              uMF.value = double.tryParse(payload) ?? 0.0;
              break;
            case 'erroMF':
              erroMF.value = double.tryParse(payload) ?? 0.0;
              break;
          }
      }});

        return true;
      }
    } on NoConnectionException catch (e) {
      status = 'Erro de Conexão: Verifique o IP e a rede.\nDetalhes: $e';
    } on SocketException catch (e) {
      status = 'Erro de Socket: Verifique o IP, porta e firewall.\nDetalhes: $e';
    } on Exception catch (e) {
      status = 'Erro Desconhecido.\nDetalhes: $e';
    } finally {
      onStateChange(); // Garante que a UI seja atualizada no final
    }
    return false; // Falha na conexão
  }

  // Método para resetar os valores ao desconectar
  void _resetDataNotifiers() {
    motorStatus.value = 'Parado';
    velocidadeRpm.value = 0.0;
    erroMF.value = 0.0;
    uMF.value = 0.0;
  }

  // Método para desconectar do broker MQTT
   // ALTERADO: Método disconnect para resetar os dados
  Future<void> disconnect({required VoidCallback onStateChange}) async {
    client?.disconnect();
    status = 'Desconectado';
    streamUrl.value = null;
    _publishedSuccessMessage = false;
    _resetDataNotifiers(); // Reseta os valores dos notifiers
    onStateChange();
  }
}

// =================================================================
// TELA PRINCIPAL (DADOS E CONEXÃO)
// =================================================================
// Esta tela gerencia a entrada de dados do aluno e a conexão com o broker MQTT.
class UnifiedScreen extends StatefulWidget {
  const UnifiedScreen({super.key});

  @override
  State<UnifiedScreen> createState() => _UnifiedScreenState();
}

class _UnifiedScreenState extends State<UnifiedScreen> {
  // Controladores para os campos de nome e matrícula do aluno
  final TextEditingController nameController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();

  // Controladores para os campos de conexão do broker
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portaController = TextEditingController(text: '1883');
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final BrokerInfo brokerInfo = BrokerInfo.instance;

  @override
  void initState() {
    super.initState();
    // Carrega os dados persistidos do broker ao iniciar a tela
    ipController.text = brokerInfo.ip;
    portaController.text = brokerInfo.porta.toString();
    usuarioController.text = brokerInfo.usuario;
    senhaController.text = brokerInfo.senha;
  }

  @override
  void dispose() {
    // Descarta os controladores para liberar recursos
    for (var c in [
      nameController, matriculaController,
      ipController, portaController, usuarioController, senhaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Lógica para conectar ou desconectar do broker
  Future<void> _connectOrDisconnect() async {
    if (brokerInfo.client != null && brokerInfo.client!.connectionStatus!.state == MqttConnectionState.connected) {
      // Se já conectado, desconecta
      await brokerInfo.disconnect(onStateChange: () => setState(() {}));
      _clearAllFields(); // Limpa os campos ao desconectar
      _showInfoDialog("Desconectado", "Você foi desconectado do broker.");
    } else {
      // Se não conectado, tenta conectar
      // Validação de campos obrigatórios
      if (nameController.text.trim().isEmpty) {
        _showErrorDialog("Campo Obrigatório", "Por favor, preencha o nome do aluno para ser usado como Client ID.");
        return;
      }
      if (ipController.text.trim().isEmpty) {
        _showErrorDialog("Campo Obrigatório", "Por favor, informe o IP do broker.");
        return;
      }

      // Verifica a conectividade da internet
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none && mounted) {
        _showErrorDialog("Sem Internet", "Por favor, verifique sua conexão com a internet.");
        return;
      }

      // Gera o Client ID a partir do nome do aluno (removendo caracteres não alfanuméricos)
      final String clientId = nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      // Exibe pop-up de "Conectando..."
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

      // Tenta conectar ao broker
      final bool connected = await brokerInfo.connect(
        ip: ipController.text.trim(),
        porta: int.tryParse(portaController.text.trim()) ?? 1883,
        usuario: usuarioController.text.trim(),
        senha: senhaController.text.trim(),
        credenciais: brokerInfo.credenciais,
        clientId: clientId, // Passa o Client ID gerado
        onStateChange: () => setState(() {}), // Atualiza a UI após a mudança de estado
      );

      if (mounted) {
        Navigator.pop(context); // Fecha o pop-up de "Conectando..."
        _showConnectionResultDialog(connected); // Exibe o resultado da conexão
      }
    }
  }

  // Exibe um diálogo com o resultado da conexão
  void _showConnectionResultDialog(bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success ? "Sucesso!" : "Falha na Conexão"),
        content: Text(success
            ? "A conexão com o broker MQTT foi estabelecida e a mensagem de sucesso publicada."
            : brokerInfo.status), // Mostra a mensagem de erro detalhada!
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

  // Exibe um diálogo de erro
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

  // Exibe um diálogo de informação
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

  // Limpa todos os campos de entrada e reseta o estado do broker
  void _clearAllFields() {
    setState(() {
      nameController.clear();
      matriculaController.clear();
      ipController.clear();
      portaController.text = '1883';
      usuarioController.clear();
      senhaController.clear();
      brokerInfo.resetPublishedSuccessMessage(); // Reseta o estado da mensagem de sucesso
    });
  }

  // =================================================================
  // BUILD METHOD E WIDGETS DE UI
  // =================================================================
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isConnected = brokerInfo.status == 'Conectado';
    // O botão "Avançar para Experimentos" só é habilitado se conectado E a mensagem de sucesso foi publicada
    final bool canProceedToExperiments = isConnected && brokerInfo.publishedSuccessMessage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.white,
          tooltip: 'Limpar todos os dados',
          onPressed: _clearAllFields,
        ),
        title: const Text('Dados e Conexão', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção de Conexão com Broker
            _buildSectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Conexão com Broker', theme),
                    const SizedBox(height: 16),
                    // Exibe animação de sucesso se conectado
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
                )),
            const SizedBox(height: 24),
            // Seção de Dados do Aluno (agora apenas um aluno)
            _buildSectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Dados do Aluno', theme),
                    const SizedBox(height: 8),
                    _buildStudentInputs(theme), // Widget para os campos do aluno
                  ],
                )),
            const SizedBox(height: 24),
            // Botão para conectar/desconectar
            ElevatedButton(
              onPressed: _connectOrDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isConnected ? 'Desconectar' : 'Conectar',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            // Botão para avançar para a tela de experimentos
            ElevatedButton(
              onPressed: canProceedToExperiments
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EscolhaExperimento()),
                );
              }
                  : null, // Desabilita o botão se não puder avançar
              style: ElevatedButton.styleFrom(
                backgroundColor: canProceedToExperiments ? theme.primaryColor : Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Avançar para Experimentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Constrói os campos de entrada para o broker
  Widget _buildBrokerInputs(ThemeData theme) {
    bool areCredentialsEnabled = brokerInfo.credenciais;

    return Column(
      children: [
        TextFormField(
          controller: ipController,
          decoration: _inputDecoration('IP do Broker', theme),
          keyboardType: TextInputType.number,
          // Usando o formatador de IP para garantir o formato correto
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, IpAddressInputFormatter()],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: portaController,
          decoration: _inputDecoration('Porta', theme),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        // Opções de credenciais (com/sem)
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
                  fontWeight: !areCredentialsEnabled ? FontWeight.bold : FontWeight.normal),
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
                  fontWeight: areCredentialsEnabled ? FontWeight.bold : FontWeight.normal),
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

  // Constrói o container para as seções da UI
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

  // Constrói o cabeçalho das seções
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

  // Constrói os campos de entrada para os dados do aluno
  Widget _buildStudentInputs(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: nameController,
          decoration: _inputDecoration('Nome Completo do Aluno', theme),
          // Permite qualquer caractere (incluindo especiais)
          inputFormatters: [],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: matriculaController,
          decoration: _inputDecoration('Matrícula do Aluno', theme),
          // Permite qualquer caractere (incluindo texto)
          inputFormatters: [],
        ),
      ],
    );
  }

  // Constrói a decoração padrão para os campos de entrada de texto
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
