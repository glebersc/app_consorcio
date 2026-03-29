import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class VerificadorAtualizacao {
  // 🌟 TODA VEZ QUE VOCÊ FIZER UM PUSH, VOCÊ MUDA ESTE NÚMERO AQUI E NO BANCO!
  static const String versaoDesteApp = '1.0.0'; 

  static Future<void> checar() async {
    // Só roda essa verificação se estiver no navegador Web
    if (!kIsWeb) return; 

    try {
      final res = await Supabase.instance.client
          .from('sys_configuracoes')
          .select('versao_web')
          .eq('id', 1)
          .single();

      String versaoDoBanco = res['versao_web'];

      // Se a versão do código for diferente da versão do banco...
      if (versaoDoBanco != versaoDesteApp) {
        // ...Ele recarrega a página à força, jogando um carimbo de tempo na URL
        // Isso "engana" o navegador do celular fazendo ele baixar tudo do zero!
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        html.window.location.href = '/?v=$timestamp';
      }
    } catch (e) {
      debugPrint('Erro ao checar versão: $e');
    }
  }
}