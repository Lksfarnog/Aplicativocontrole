import 'package:flutter/material.dart';

class PdfPage extends StatefulWidget {
  const PdfPage({super.key});

  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        title: const Text("Embasamento Teórico",
        style: TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color.fromRGBO(19, 85, 156, 1),
      ),

    );
  }
}