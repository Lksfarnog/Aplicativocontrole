import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'broker.dart';
import 'dadosexperimento.dart';
import 'experimento.dart';



final List<TextEditingController> nameControllers =
    List.generate(6, (_) => TextEditingController());
final List<TextEditingController> matriculaControllers =
    List.generate(6, (_) => TextEditingController());
final TextEditingController dayCtrl = TextEditingController();
final TextEditingController monthCtrl = TextEditingController();
final TextEditingController yearCtrl = TextEditingController();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  int currentCount = 1;
  late final List<Widget> _pages;

  

  

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildIntegrantesPage(),
      const ConectaBrokerPage(),
      const DadosExperimentosPage(),
      const ExperimentoPage(),
    ];
  }

  @override
  void dispose() {
    for (var c in [...nameControllers, ...matriculaControllers]) {
      c.dispose();
    }
    dayCtrl.dispose();
    monthCtrl.dispose();
    yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        onTap: (i) => setState(() => currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: 'Integrantes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.cloud), label: 'Broker'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Parâmetros'),
          BottomNavigationBarItem(
              icon: Icon(Icons.science), label: 'Experimento'),
        ],
      ),
    );
  }

  Widget _buildIntegrantesPage() {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Dados dos Integrantes',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              'Integrantes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            for (int i = 0; i < currentCount; i++) _buildMemberCard(i),
            if (currentCount < 6)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _onAddMember,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Integrante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
                    minimumSize: const Size.fromHeight(55),
                  ),
                ),
              ),
            const SizedBox(height: 30),
            _buildDateCard(),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _onStartExperiment,
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Inserir Dados do Broker',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 15, 220, 22),
                minimumSize: const Size.fromHeight(55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(int i) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.grey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Integrante ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _onRemoveMember(i),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameControllers[i],
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: matriculaControllers[i],
              decoration: const InputDecoration(
                labelText: 'Matrícula',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.grey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data do Experimento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: dayCtrl,
                    decoration: const InputDecoration(labelText: 'Dia'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: monthCtrl,
                    decoration: const InputDecoration(labelText: 'Mês'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: yearCtrl,
                    decoration: const InputDecoration(labelText: 'Ano'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4)
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar Dados'),
        content: const Text(
            'Tem certeza que deseja apagar os dados e desconectar do Broker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Color.fromRGBO(19, 85, 156, 1))),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (var c in [...nameControllers, ...matriculaControllers]) {
                  c.clear();
                }
                dayCtrl.clear();
                monthCtrl.clear();
                yearCtrl.clear();
                currentCount = 1;
              });
              BrokerInfo.instance.disconnect();
              Navigator.pop(context);
            },
            child: const Text('Confirmar',
                style: TextStyle(color: Color.fromRGBO(19, 85, 156, 1))),
          ),
        ],
      ),
    );
  }

  void _onAddMember() {
    if (currentCount < 6) setState(() => currentCount++);
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

  void _onStartExperiment() {
    final allNamesFilled =
        nameControllers.take(currentCount).every((c) => c.text.trim().isNotEmpty);
    final allMatriculasFilled = matriculaControllers
        .take(currentCount)
        .every((c) => c.text.trim().isNotEmpty);
    final dateFilled = dayCtrl.text.trim().isNotEmpty &&
        monthCtrl.text.trim().isNotEmpty &&
        yearCtrl.text.trim().isNotEmpty;

    if (allNamesFilled && allMatriculasFilled && dateFilled) {
      setState(() => currentIndex = 1);
      return;
    }

    String alert;
    if (!dateFilled && (!allNamesFilled || !allMatriculasFilled)) {
      alert =
          'Você não preencheu nem os dados dos integrantes nem a data.\nO relatório será gerado sem essas informações.';
    } else if (!dateFilled) {
      alert =
          'Você não informou a data do experimento.\nO relatório será gerado sem data.';
    } else {
      alert =
          'Você não preencheu os dados dos integrantes.\nO relatório será gerado sem identificação dos membros.';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Campos não preenchidos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child:
                  LottieBuilder.asset('assets/Alerta.json', fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Text(alert, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => currentIndex = 1),
            child: const Text('Ir para Broker'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Preencher dados'),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('currentIndex', currentIndex));
  }
}
