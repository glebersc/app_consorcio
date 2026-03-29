import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart'; // 🌟 Importante: Traz o kIsWeb

class WebViewEmbutido extends StatefulWidget {
  final String url;
  
  const WebViewEmbutido({super.key, required this.url});

  @override
  State<WebViewEmbutido> createState() => _WebViewEmbutidoState();
}

class _WebViewEmbutidoState extends State<WebViewEmbutido> {
  late final WebViewController _controller;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController();

    // 🌟 A MÁGICA CROSS-PLATFORM 🌟
    // Só tenta configurar essas coisas nativas se NÃO for Web (ou seja, se for Celular)
    if (!kIsWeb) {
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _carregando = false);
          },
        ),
      );
    } else {
      // Se for Web, o carregamento do Iframe é instantâneo e não tem delegate
      _carregando = false; 
    }

    // Carrega a URL normalmente em qualquer plataforma
    _controller.loadRequest(Uri.parse(widget.url)); 
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_carregando)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF00447C)),
          ),
      ],
    );
  }
}