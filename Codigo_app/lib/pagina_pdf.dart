import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfPage extends StatefulWidget {
  const PdfPage({super.key});

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
        document: PdfDocument.openAsset('assets/pdfs/controlador_pid.pdf'));
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
                    duration: Duration(milliseconds: 500),
                    curve: Curves.linear);
              },
              icon: Icon(Icons.arrow_back),
            ),
            Text("Página Atual: $paginaAtual"),
            IconButton(
              onPressed: () {
                pdfControllerPinch.nextPage(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.linear);
              },
              icon: Icon(Icons.arrow_forward),
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
