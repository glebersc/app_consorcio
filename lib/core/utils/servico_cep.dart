import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ServicoCep {
  /// Retorna um mapa com logradouro, bairro, municipio e uf. Retorna null se falhar.
  static Future<Map<String, String>?> buscar(String cep) async {
    // Limpa a string para garantir que só tem números
    String cepLimpo = cep.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cepLimpo.length != 8) return null;

    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/'));
      
      if (response.statusCode == 200) {
        final dados = json.decode(response.body);
        
        // O ViaCEP retorna "erro": true se o CEP não existir (ex: 99999999)
        if (dados['erro'] == null) {
          return {
            'logradouro': dados['logradouro'] ?? '',
            'bairro': dados['bairro'] ?? '',
            'municipio': dados['localidade'] ?? '',
            'uf': dados['uf'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('Erro no ServicoCep: $e');
    }
    return null;
  }
}