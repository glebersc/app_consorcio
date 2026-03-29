import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:math';
import '../../../core/utils/sessao_usuario.dart';
import '../../dashboard/screens/home_page.dart';
import '../../../core/utils/verificador_atualizacao.dart'; // 🌟 Import do Cache
import '../../../core/utils/servico_email.dart'; // 🌟 Import do EmailJS

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  
  bool _carregando = false;
  String _mensagemErro = '';

  @override
  void initState() {
    super.initState();
    VerificadorAtualizacao.checar(); // 🌟 CHECA A VERSÃO AO ABRIR O SISTEMA
  }

  Future<void> _fazerLogin() async {
    setState(() {
      _carregando = true;
      _mensagemErro = '';
    });

    try {
      String cpfLimpo = _cpfMask.unmaskText(_cpfController.text);

      if (cpfLimpo.isEmpty || _senhaController.text.isEmpty) {
        setState(() => _mensagemErro = 'Preencha o CPF e a Senha.');
        return;
      }

      final resposta = await Supabase.instance.client
          .from('cad_pessoas')
          .select('*, sys_usuarios!inner(*)')
          .eq('documento', cpfLimpo)
          .eq('sys_usuarios.senha', _senhaController.text)
          .maybeSingle();

      if (resposta == null) {
        setState(() => _mensagemErro = 'CPF ou senha incorretos.');
      } else if (resposta['sys_usuarios']['grupo_id'] == null) {
        setState(() => _mensagemErro = 'Usuário sem grupo de acesso liberado.');
      } else {
        final usuarioFormatado = {
          'id': resposta['sys_usuarios']['id'],
          'pessoa_id': resposta['id'],
          'nome_completo': resposta['nome'],
          'email': resposta['email'],
          'grupo_id': resposta['sys_usuarios']['grupo_id'],
          'senha_temporaria': resposta['sys_usuarios']['senha_temporaria']
        };

        if (usuarioFormatado['senha_temporaria'] == true) {
          _mostrarTrocaDeSenhaObrigatoria(usuarioFormatado);
        } else {
          _concluirLoginEEntrar(usuarioFormatado);
        }
      }
    } catch (e) {
      debugPrint('Erro Login: $e');
      setState(() => _mensagemErro = 'Erro ao conectar no servidor.');
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _concluirLoginEEntrar(Map<String, dynamic> usuarioDados) {
    SessaoUsuario().usuarioAtual = usuarioDados;
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    }
  }

  // ==========================================
  // 🛡️ MODAL DE TROCA DE SENHA OBRIGATÓRIA
  // ==========================================
  void _mostrarTrocaDeSenhaObrigatoria(Map<String, dynamic> usuario) {
    final novaSenhaController = TextEditingController();
    final confirmaSenhaController = TextEditingController();
    bool processando = false;
    String erroModal = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Atualização de Segurança', style: TextStyle(color: Color(0xFF00447C))),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Você está usando uma senha temporária. Para sua segurança, cadastre uma nova senha definitiva agora.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    
                    if (erroModal.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.red.shade50, child: Text(erroModal, style: const TextStyle(color: Colors.red)),
                      ),

                    TextField(
                      controller: novaSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nova Senha', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmaSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirme a Nova Senha', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _senhaController.clear());
                  }, 
                  child: const Text('Cancelar')
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: processando ? null : () async {
                    if (novaSenhaController.text.length < 6) {
                      setModalState(() => erroModal = 'A senha deve ter no mínimo 6 caracteres.');
                      return;
                    }
                    if (novaSenhaController.text != confirmaSenhaController.text) {
                      setModalState(() => erroModal = 'As senhas não coincidem.');
                      return;
                    }

                    setModalState(() { processando = true; erroModal = ''; });
                    
                    try {
                      await Supabase.instance.client.from('sys_usuarios').update({
                        'senha': novaSenhaController.text,
                        'senha_temporaria': false
                      }).eq('id', usuario['id']);

                      usuario['senha'] = novaSenhaController.text;
                      usuario['senha_temporaria'] = false;

                      if (mounted) {
                        Navigator.pop(context);
                        _concluirLoginEEntrar(usuario); 
                      }
                    } catch (e) {
                      setModalState(() => erroModal = 'Erro ao salvar a nova senha.');
                    } finally {
                      setModalState(() => processando = false);
                    }
                  },
                  child: processando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar e Entrar'),
                )
              ],
            );
          }
        );
      }
    );
  }

  // ==========================================
  // 🔐 FLUXO DE RECUPERAÇÃO DE SENHA COM EMAIL REAL
  // ==========================================
  void _mostrarRecuperacaoSenha() async {
    String cpfDigitado = _cpfMask.unmaskText(_cpfController.text);
    
    int etapa = 1;
    String cpfBusca = cpfDigitado;
    String emailReal = '';
    String emailMascarado = '';
    int? idUsuarioRecuperacao;
    String erroModal = '';
    
    final cpfRecuperacaoController = TextEditingController(text: _cpfController.text);
    final emailConfirmacaoController = TextEditingController();
    final maskRecuperacao = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')}, initialText: _cpfController.text);
    bool processando = false;

    String mascararEmail(String email) {
      if (email.isEmpty) return 'Email não cadastrado';
      final partes = email.split('@');
      if (partes.length != 2) return email;
      String nome = partes[0];
      String dominio = partes[1];
      if (nome.length <= 3) return '${nome.substring(0, 1)}***@$dominio';
      String inicio = nome.substring(0, 2);
      String fim = nome.substring(nome.length - 2);
      return '$inicio****$fim@$dominio';
    }

    String gerarSenhaAleatoria() {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      Random rnd = Random();
      String senha = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      return '1C-$senha'; 
    }

    if (cpfDigitado.length == 11) {
      setState(() => _carregando = true);
      try {
        final res = await Supabase.instance.client
            .from('cad_pessoas')
            .select('id, email, sys_usuarios!inner(id)')
            .eq('documento', cpfDigitado)
            .maybeSingle();
            
        if (res != null) {
          emailReal = res['email'] ?? '';
          idUsuarioRecuperacao = res['sys_usuarios']['id']; 
          emailMascarado = mascararEmail(emailReal);
          etapa = 2; 
        } else {
          erroModal = 'O CPF informado na tela não possui acesso ao sistema.';
        }
      } catch (e) {
        erroModal = 'Erro ao verificar o CPF.';
      } finally {
        setState(() => _carregando = false);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Recuperar Senha', style: TextStyle(color: Color(0xFF00447C))),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (erroModal.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.red.shade50, child: Text(erroModal, style: const TextStyle(color: Colors.red)),
                      ),
                    
                    if (etapa == 1) ...[
                      const Text('Digite o seu CPF para localizarmos o seu cadastro.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextField(
                        controller: cpfRecuperacaoController,
                        inputFormatters: [maskRecuperacao],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Seu CPF', border: OutlineInputBorder()),
                      ),
                    ],

                    if (etapa == 2) ...[
                      Text('Encontramos seu cadastro! O e-mail vinculado a este CPF é:\n\n$emailMascarado\n\nPor segurança, digite o e-mail completo abaixo para confirmarmos a sua identidade.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailConfirmacaoController,
                        decoration: const InputDecoration(labelText: 'E-mail Completo', border: OutlineInputBorder()),
                      ),
                    ],

                    if (etapa == 3) ...[
                      const Icon(Icons.mark_email_read, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      const Text('E-mail enviado com sucesso!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      Text('Enviamos uma nova senha temporária para:\n$emailMascarado', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Text('Por favor, verifique sua caixa de entrada (e a pasta de spam). Ao fazer login, o sistema exigirá que você crie uma nova senha definitiva.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ]
                  ],
                ),
              ),
              actions: [
                if (etapa != 3)
                  TextButton(onPressed: processando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
                
                if (etapa == 1)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                    onPressed: processando ? null : () async {
                      setModalState(() { processando = true; erroModal = ''; });
                      cpfBusca = maskRecuperacao.unmaskText(cpfRecuperacaoController.text);
                      
                      if (cpfBusca.length != 11) {
                         setModalState(() { erroModal = 'Digite um CPF válido.'; processando = false; });
                         return;
                      }

                      try {
                        final res = await Supabase.instance.client
                            .from('cad_pessoas')
                            .select('id, email, sys_usuarios!inner(id)')
                            .eq('documento', cpfBusca)
                            .maybeSingle();
                            
                        if (res == null) {
                          setModalState(() => erroModal = 'CPF não possui acesso ao sistema.');
                        } else {
                          emailReal = res['email'] ?? '';
                          idUsuarioRecuperacao = res['sys_usuarios']['id'];
                          emailMascarado = mascararEmail(emailReal);
                          setModalState(() { etapa = 2; erroModal = ''; }); 
                        }
                      } catch (e) {
                        setModalState(() => erroModal = 'Erro ao buscar dados.');
                      } finally {
                        setModalState(() => processando = false);
                      }
                    },
                    child: processando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Buscar'),
                  ),

                if (etapa == 2)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                    onPressed: processando ? null : () async {
                      if (emailConfirmacaoController.text.trim().toLowerCase() != emailReal.toLowerCase()) {
                        setModalState(() => erroModal = 'O e-mail digitado não confere.');
                        return;
                      }

                      setModalState(() { processando = true; erroModal = ''; });
                      try {
                        String novaSenha = gerarSenhaAleatoria();
                        
                        // 1. Salva no banco
                        await Supabase.instance.client.from('sys_usuarios').update({
                          'senha': novaSenha,
                          'senha_temporaria': true 
                        }).eq('id', idUsuarioRecuperacao!);
                        
                        // 2. DISPARA O E-MAIL REAL 
                        bool emailEnviado = await ServicoEmail.enviarEmailRecuperacao(
                          emailDestino: emailReal,
                          novaSenha: novaSenha,
                        );

                        if (emailEnviado) {
                          setModalState(() { 
                            etapa = 3; 
                            erroModal = ''; 
                          });
                        } else {
                          setModalState(() => erroModal = 'A senha foi alterada, mas ocorreu um erro ao enviar o e-mail. Contate o suporte.');
                        }

                      } catch (e) {
                        setModalState(() => erroModal = 'Erro ao processar o pedido.');
                      } finally {
                        setModalState(() => processando = false);
                      }
                    },
                    child: processando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirmar e Gerar Senha'),
                  ),

                if (etapa == 3)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar ao Login'),
                  )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 64, color: Color(0xFF00447C)),
              const SizedBox(height: 16),
              const Text('Demo 1CÓDIGO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
              const Text('Acesso Restrito', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              if (_mensagemErro.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                  child: Text(_mensagemErro, style: TextStyle(color: Colors.red.shade800), textAlign: TextAlign.center),
                ),

              TextField(
                controller: _cpfController,
                inputFormatters: [_cpfMask],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CPF', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                onSubmitted: (_) => _fazerLogin(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.vpn_key_outlined), border: OutlineInputBorder()),
                onSubmitted: (_) => _fazerLogin(),
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _carregando ? null : _mostrarRecuperacaoSenha,
                  child: const Text('Esqueci minha senha', style: TextStyle(color: Color(0xFF00447C))),
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: _carregando ? null : _fazerLogin,
                  child: _carregando 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ENTRAR NO SISTEMA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}