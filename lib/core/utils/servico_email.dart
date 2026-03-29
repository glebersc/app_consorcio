import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ServicoEmail {
  // 🌟 SUBSTITUA ESTES 3 VALORES PELOS SEUS DO EMAILJS 🌟
  static const String _serviceId = 'service_dnbnhbc';
  static const String _templateId = 'template_6gnpb6j';
  static const String _publicKey = 'EFz5GCMr3sE0XE4GF';

  static Future<bool> enviarEmailRecuperacao({
    required String emailDestino,
    required String novaSenha,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost', // Necessário para o Flutter Web
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'email_destino': emailDestino, // Variável que colocámos no template
            'nova_senha': novaSenha,       // Variável que colocámos no template
          }
        }),
      );

      // O EmailJS devolve a string "OK" se tudo correr bem
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao enviar email via EmailJS: $e');
      return false;
    }
  }
}