import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'pagina_pdf.dart';
import 'dadosintegrante.dart';

// Tela 1: Escolha do tipo de experimento
class EscolhaExperimento extends StatelessWidget {
  const EscolhaExperimento({super.key});

  // CORREÇÃO: A função de navegação foi simplificada para não passar mais o caminho do PDF.
  void _navigateToExperimento(BuildContext context, String title, Map<String, String> parametros) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExperimentoInputsPage(
          title: title,
          parametros: parametros,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleção de Experimento', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CORREÇÃO: O caminho do PDF foi removido da chamada do botão.
                _buildExperimentoButton(
                  context,
                  'Malha Aberta e Malha Fechada',
                  {
                    'observadorKe': 'Observador Ke',
                    'reguladorK': 'Regulador K',
                    'nx': 'nx',
                    'nu': 'nu',
                  },
                ),
                const SizedBox(height: 40),
                _buildExperimentoButton(
                  context,
                  'Sistemas de 1ª e 2ª ordem',
                  {
                    'u_primeiraOrdem': 'u - 1ª ordem',
                    'kp_segundaOrdem': 'Kp - 2ª ordem',
                    'tetaref_segundaOrdem': 'Tetaref - 2ª ordem',
                    'erro_segundaOrdem': 'Erro - 2ª ordem',
                    'u_segundaOrdem': 'u - 2ª ordem',
                  },
                ),
                const SizedBox(height: 40),
                _buildExperimentoButton(
                  context,
                  'Sistemas Instáveis em MA',
                  {
                    'teta_proporcional': 'Teta proporcional',
                    'kp_proporcional': 'Kp proporcional',
                    'teta_leadLag': 'Teta lead-lag',
                    'k_leadLag': 'K lead-lag',
                    'a_leadLag': 'a lead-lag',
                    'b_leadLag': 'b lead-lag',
                    'td_leadLag': 'td lead-lag',
                  },
                ),
                const SizedBox(height: 40),
                _buildExperimentoButton(
                  context,
                  'Controlador PID',
                  {
                    'sc_kp': 'SC - Kp', 'sc_kd': 'SC - Kd', 'sc_ki': 'SC - Ki', 'sc_tetaref': 'SC - tetaref', 'sc_erro': 'SC - erro', 'sc_up': 'SC - Up', 'sc_ui': 'SC - Ui', 'sc_ud': 'SC - Ud', 'sc_u': 'SC - U',
                    'pid_kp': 'PID - Kp', 'pid_kd': 'PID - Kd', 'pid_ki': 'PID - Ki', 'pid_tetaref': 'PID - tetaref', 'pid_erro': 'PID - erro', 'pid_up': 'PID - Up', 'pid_ui': 'PID - Ui', 'pid_ud': 'PID - Ud', 'pid_u': 'PID - U'
                  },
                ),
                const SizedBox(height: 40),
                _buildExperimentoButton(
                  context,
                  'Resposta em Frequência',
                  {
                    'u_malhaAberta': 'u - malha aberta',
                    'omegaRef_malhaFechada': 'Omegaref - malha fechada',
                    'erro_malhaFechada': 'erro - malha fechada',
                    'u_malhaFechada': 'u - malha fechada',
                    'erroK_compensador': 'erroK - compensador',
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentoButton(BuildContext context, String title, Map<String, String> parametros) {
    return ElevatedButton(
      onPressed: () => _navigateToExperimento(context, title, parametros),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(title, textAlign: TextAlign.center),
    );
  }
}


// Tela 2: Entrada dos dados do experimento
class ExperimentoInputsPage extends StatefulWidget {
  final String title;
  final Map<String, String> parametros;
  
  // CORREÇÃO: A propriedade pdfAssetPath foi removida.
  const ExperimentoInputsPage({
    super.key,
    required this.title,
    required this.parametros,
  });

  @override
  State<ExperimentoInputsPage> createState() => _ExperimentoInputsPageState();
}

class _ExperimentoInputsPageState extends State<ExperimentoInputsPage> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var topic in widget.parametros.keys) {
      _controllers[topic] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _enviarDados() async {
    final broker = BrokerInfo.instance;

    if (broker.client == null || broker.client!.connectionStatus!.state != MqttConnectionState.connected) {
      _showError('Não Conectado', 'Volte para a tela anterior e conecte-se ao broker primeiro.');
      return;
    }

    final Map<String, String> dataToSend = {};
    for (var entry in widget.parametros.entries) {
      final topic = entry.key;
      final label = entry.value;
      final text = _controllers[topic]!.text;

      if (text.isEmpty) {
        _showError('Campos Vazios', 'Por favor, preencha o campo "$label" antes de enviar.');
        return;
      }
      
      final RegExp invalidCharPattern = RegExp(r'[^0-9\.\,\-]');
      if (invalidCharPattern.hasMatch(text)) {
        _showError('Caracteres Inválidos', 'O campo "$label" contém letras ou símbolos não permitidos. Use apenas números.');
        return;
      }
      
      try {
        final doubleValue = double.parse(text.replaceAll(',', '.'));
        dataToSend[topic] = doubleValue.toString();
      } catch (e) {
        _showError('Formato Inválido', 'O valor no campo "$label" não é um número válido (ex: "1.2.3"). Por favor, corrija o formato.');
        return;
      }
    }

    try {
      
      for (var entry in dataToSend.entries) {
        final topic = entry.key;
        final message = entry.value;
        final builder = MqttClientPayloadBuilder()..addString(message);
        
        broker.client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sucesso!'),
          content: const Text('Dados enviados com sucesso para o Broker!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      
      _showError('Erro de Envio', 'Ocorreu um erro ao enviar os dados para o broker: $e');
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          icon: Icon(Icons.tune, color: Theme.of(context).primaryColor),
          labelText: label,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d\.\,\-]*')), // Permite números, ponto, vírgula e sinal de menos
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
              onPressed: () {
                // CORREÇÃO: Navega para a nova página de ajuda em branco.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PdfPage(),
                  ),
                );
              },
              backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
              foregroundColor: Colors.white,
              tooltip: 'Ajuda',
              child: const Icon(Icons.question_mark),
            ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  ...widget.parametros.entries.map((entry) {
                    final topic = entry.key;
                    final label = entry.value;
                    return _buildTextField(label, _controllers[topic]!);
                  }),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _enviarDados,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Enviar dados do Experimento',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}



