import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importa a tela principal que criamos
import 'modulos/dashboard/screens/home_page.dart'; 

Future<void> main() async {
  // Garante que o Flutter está pronto antes de chamar o banco
  WidgetsFlutterBinding.ensureInitialized();

  // Conecta o seu App ao seu Banco de Dados
  await Supabase.initialize(
    url: 'https://tsqiklnuokajswnvppns.supabase.co',   // <--- COLOQUE SUA URL AQUI
    anonKey: 'sb_publishable_lMavK9BdpLcKlYdZxBVJXg_o_rZeTYp', // <--- COLOQUE SUA CHAVE AQUI
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo 1CÓDIGO',
      debugShowCheckedModeBanner: false, // Remove a faixa de 'DEBUG' da tela
      theme: ThemeData(
        // Define a cor principal do sistema (Aquele azul escuro bonito)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00447C)),
        useMaterial3: true, // Usa o design mais moderno do Google
      ),
      // Chama a tela responsiva que criamos no outro arquivo
      home: const HomePage(), 
    );
  }
}