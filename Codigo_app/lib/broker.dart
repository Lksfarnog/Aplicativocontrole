import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:pdfx/pdfx.dart';
import 'dadosintegrante.dart';
import 'malha_aberta_fechada_page.dart';
import 'sistemas_ordem_page.dart';
import 'sistemas_instaveis_page.dart';
import 'controlador_pid_page.dart';
import 'resposta_frequencia_page.dart';

class EscolhaExperimento extends StatelessWidget {
  const EscolhaExperimento({super.key});

  void _navigateToExperimento(BuildContext context, String title,
      Map<String, String> parametros, String pdfAssetPath) {
    if (title == 'Malha Aberta e Malha Fechada') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MalhaAbertaFechadaPage(pdfAssetPath: pdfAssetPath),
        ),
      );
    } else if (title == 'Sistemas de 1ª e 2ª ordem') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SistemasOrdemPage(pdfAssetPath: pdfAssetPath),
        ),
      );
    } else if (title == 'Sistemas Instáveis em MA') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  SistemasInstaveisPage(pdfAssetPath: pdfAssetPath)));
    } else if (title == 'Controlador PID') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ControladorPidPage(pdfAssetPath: pdfAssetPath)));
    } else if (title == 'Resposta em Frequência') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  RespostaFrequenciaPage(pdfAssetPath: pdfAssetPath)));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExperimentoInputsPage(
            title: title,
            parametros: parametros,
            pdfAssetPath: pdfAssetPath,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleção de Experimento',
            style: TextStyle(color: Colors.white)),
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
                _buildExperimentoButton(
                  context,
                  'Malha Aberta e Malha Fechada',
                  {
                    'uMA': 'U Malha aberta',
                    'refMF': 'Referência Malha Fechada',
                    'erroMF': 'Erro Malha Fechada',
                    'uMF': 'U Malha Fechada',
                  },
                  'assets/pdfs/malha_aberta.pdf',
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
                  'assets/pdfs/sistemas_ordem.pdf',
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
                  'assets/pdfs/sistemas_instaveis.pdf',
                ),
                const SizedBox(height: 40),
                _buildExperimentoButton(
                  context,
                  'Controlador PID',
                  {
                    'sc_kp': 'SC - Kp',
                    'sc_kd': 'SC - Kd',
                    'sc_ki': 'SC - Ki',
                    'sc_tetaref': 'SC - tetaref',
                    'sc_erro': 'SC - erro',
                    'sc_up': 'SC - Up',
                    'sc_ui': 'SC - Ui',
                    'sc_ud': 'SC - Ud',
                    'sc_u': 'SC - U',
                    'pid_kp': 'PID - Kp',
                    'pid_kd': 'PID - Kd',
                    'pid_ki': 'PID - Ki',
                    'pid_tetaref': 'PID - tetaref',
                    'pid_erro': 'PID - erro',
                    'pid_up': 'PID - Up',
                    'pid_ui': 'PID - Ui',
                    'pid_ud': 'PID - Ud',
                    'pid_u': 'PID - U'
                  },
                  'assets/pdfs/controlador_pid.pdf',
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
                  'assets/pdfs/resposta_frequencia.pdf',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentoButton(BuildContext context, String title,
      Map<String, String> parametros, String pdfAssetPath) {
    return ElevatedButton(
      onPressed: () =>
          _navigateToExperimento(context, title, parametros, pdfAssetPath),
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

class ExperimentoInputsPage extends StatefulWidget {
  final String title;
  final Map<String, String> parametros;
  final String pdfAssetPath;

  const ExperimentoInputsPage({
    super.key,
    required this.title,
    required this.parametros,
    required this.pdfAssetPath,
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
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _enviarDados() async {
    final broker = BrokerInfo.instance;

    if (broker.client == null ||
        broker.client!.connectionStatus!.state !=
            MqttConnectionState.connected) {
      _showError('Não Conectado',
          'Volte para a tela anterior e conecte-se ao broker primeiro.');
      return;
    }

    final Map<String, String> dataToSend = {};
    for (var entry in widget.parametros.entries) {
      final topic = entry.key;
      final label = entry.value;
      final text = _controllers[topic]!.text;

      if (text.isEmpty) {
        _showError('Campos Vazios',
            'Por favor, preencha o campo "$label" antes de enviar.');
        return;
      }

      final RegExp invalidCharPattern = RegExp(r'[^0-9\.\,\-]');
      if (invalidCharPattern.hasMatch(text)) {
        _showError('Caracteres Inválidos',
            'O campo "$label" contém letras ou símbolos não permitidos. Use apenas números.');
        return;
      }

      try {
        final doubleValue = double.parse(text.replaceAll(',', '.'));
        dataToSend[topic] = doubleValue.toString();
      } catch (e) {
        _showError('Formato Inválido',
            'O valor no campo "$label" não é um número válido (ex: "1.2.3"). Por favor, corrija o formato.');
        return;
      }
    }

    try {
      for (var entry in dataToSend.entries) {
        final topic = entry.key;
        final message = entry.value;
        final builder = MqttClientPayloadBuilder()..addString(message);
        broker.client!
            .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
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
      _showError('Erro de Envio',
          'Ocorreu um erro ao enviar os dados para o broker: $e');
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
          FilteringTextInputFormatter.allow(RegExp(r'[\d\.\,\-]')),
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

class PdfPage extends StatefulWidget {
  final String pdfAssetPath;

  const PdfPage({super.key, required this.pdfAssetPath});

  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  late PdfControllerPinch pdfControllerPinch;
  int contadorPaginas = 0, paginaAtual = 1;

  @override
  void initState() {
    super.initState();
    pdfControllerPinch = PdfControllerPinch(
        document: PdfDocument.openAsset(widget.pdfAssetPath));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Embasamento Teórico",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Páginas: $contadorPaginas"),
            IconButton(
              onPressed: () {
                pdfControllerPinch.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.linear);
              },
              icon: const Icon(Icons.arrow_back),
            ),
            Text("Página Atual: $paginaAtual"),
            IconButton(
              onPressed: () {
                pdfControllerPinch.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.linear);
              },
              icon: const Icon(Icons.arrow_forward),
            )
          ],
        ),
        _pdfView(),
      ],
    );
  }

  Widget _pdfView() {
    return Expanded(
        child: PdfViewPinch(
      scrollDirection: Axis.vertical,
      controller: pdfControllerPinch,
      onDocumentLoaded: (doc) {
        setState(() {
          contadorPaginas = doc.pagesCount;
        });
      },
      onPageChanged: (page) {
        setState(() {
          paginaAtual = page;
        });
      },
    ));
  }
}
