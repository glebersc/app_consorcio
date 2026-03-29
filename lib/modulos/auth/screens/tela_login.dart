import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:math';
import '../../../core/utils/sessao_usuario.dart';
import '../../dashboard/screens/home_page.dart';

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
          .from('sys_usuarios')
          .select()
          .eq('cpf', cpfLimpo)
          .eq('senha', _senhaController.text)
          .maybeSingle();

      if (resposta == null) {
        setState(() => _mensagemErro = 'CPF ou senha incorretos.');
      } else if (resposta['grupo_id'] == null) {
        setState(() => _mensagemErro = 'Usuário sem grupo de acesso liberado.');
      } else {
        // 🌟 VERIFICA SE A SENHA É TEMPORÁRIA 🌟
        if (resposta['senha_temporaria'] == true) {
          _mostrarTrocaDeSenhaObrigatoria(resposta);
        } else {
          // Entra direto se for senha definitiva
          _concluirLoginEEntrar(resposta);
        }
      }
    } catch (e) {
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
      barrierDismissible: false, // Impede de fechar clicando fora
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
                    // Se cancelar, ele volta pro login e apaga a senha digitada
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
                      // Salva a nova senha e TIRA a flag de temporária
                      await Supabase.instance.client.from('sys_usuarios').update({
                        'senha': novaSenhaController.text,
                        'senha_temporaria': false
                      }).eq('id', usuario['id']);

                      // Atualiza os dados locais para refletir a nova senha
                      usuario['senha'] = novaSenhaController.text;
                      usuario['senha_temporaria'] = false;

                      if (mounted) {
                        Navigator.pop(context); // Fecha o modal
                        _concluirLoginEEntrar(usuario); // Entra no sistema!
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
  // 🔐 FLUXO DE RECUPERAÇÃO DE SENHA (UX Inteligente)
  // ==========================================
  void _mostrarRecuperacaoSenha() async {
    // Lê o que já está digitado na tela de login
    String cpfDigitado = _cpfMask.unmaskText(_cpfController.text);
    
    int etapa = 1;
    String cpfBusca = cpfDigitado;
    String emailReal = '';
    String emailMascarado = '';
    int? idUsuarioRecuperacao;
    String erroModal = '';
    
    // Inicia a máscara do modal já com o CPF da tela, caso o usuário precise dele
    final cpfRecuperacaoController = TextEditingController(text: _cpfController.text);
    final emailConfirmacaoController = TextEditingController();
    final maskRecuperacao = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')}, initialText: _cpfController.text);
    bool processando = false;

    String mascararEmail(String email) {
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

    // Se o CPF já estiver preenchido com 11 dígitos, busca antes de abrir o modal!
    if (cpfDigitado.length == 11) {
      setState(() => _carregando = true);
      try {
        final res = await Supabase.instance.client.from('sys_usuarios').select('id, email').eq('cpf', cpfDigitado).maybeSingle();
        if (res != null) {
          emailReal = res['email'];
          idUsuarioRecuperacao = res['id'];
          emailMascarado = mascararEmail(emailReal);
          etapa = 2; // Pula a etapa de pedir o CPF!
        } else {
          // Se não achar, abre na etapa 1 avisando o erro
          erroModal = 'O CPF informado na tela não foi encontrado no sistema.';
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
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      const Text('Identidade confirmada e senha gerada com sucesso!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('Ao acessar o sistema com esta senha, você será obrigado a cadastrar uma nova senha definitiva. Para testes, sua senha temporária é:', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        child: SelectableText(erroModal, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)), 
                      )
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
                        final res = await Supabase.instance.client.from('sys_usuarios').select('id, email').eq('cpf', cpfBusca).maybeSingle();
                        if (res == null) {
                          setModalState(() => erroModal = 'CPF não encontrado no sistema.');
                        } else {
                          emailReal = res['email'];
                          idUsuarioRecuperacao = res['id'];
                          emailMascarado = mascararEmail(emailReal);
                          setModalState(() { etapa = 2; erroModal = ''; }); // Avança limpo
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
                        // Salva a senha e ativa a flag de temporária
                        await Supabase.instance.client.from('sys_usuarios').update({
                          'senha': novaSenha,
                          'senha_temporaria': true 
                        }).eq('id', idUsuarioRecuperacao!);
                        
                        setModalState(() { 
                          etapa = 3; 
                          erroModal = novaSenha; 
                        });
                      } catch (e) {
                        setModalState(() => erroModal = 'Erro ao gerar nova senha.');
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