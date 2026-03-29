import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ServicoImagem {
  /// Abre a galeria (ou câmera) e retorna a imagem já convertida em Base64, pronta pro banco.
  static Future<String?> capturarBase64({ImageSource fonte = ImageSource.gallery}) async {
    final ImagePicker picker = ImagePicker();
    
    // Abre a janela do sistema pedindo a imagem. Já comprime para 50% e limita o tamanho máximo.
    final XFile? image = await picker.pickImage(
      source: fonte, 
      imageQuality: 50, 
      maxWidth: 800,
      maxHeight: 800,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      return base64Encode(bytes); // Transforma a foto em um textão legível pelo banco
    }
    
    return null; // O usuário cancelou a escolha da foto
  }
}