import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/icones_sistema.dart'; // 🌟 Importando o tradutor de ícones!

class TelaPerfisAtuacao extends StatefulWidget {
  const TelaPerfisAtuacao({super.key});

  @override
  State<TelaPerfisAtuacao> createState() => _TelaPerfisAtuacaoState();
}

class _TelaPerfisAtuacaoState extends State<TelaPerfisAtuacao> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _perfis = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      final res = await _supabase.from('cad_perfis_atuacao').select().order('tipo_pessoa').order('nome');
      setState(() => _perfis = res);
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _excluirPerfil(int id) async {
    try {
      await _supabase.from('cad_perfis_atuacao').delete().eq('id', id);
      _buscarDados();
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? perfilAtual]) {
    final bool editando = perfilAtual != null;
    final nomeController = TextEditingController(text: editando ? perfilAtual['nome'] : '');
    final iconeController = TextEditingController(text: editando ? perfilAtual['icone'] : 'label');
    String tipoSelecionado = editando ? perfilAtual['tipo_pessoa'] : 'F';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(editando ? 'Editar Perfil' : 'Novo Perfil de Atuação', style: const TextStyle(color: Color(0xFF00447C))),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Perfil', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    
                    // 🌟 CAMPO DE ÍCONE COM PREVIEW EM TEMPO REAL 🌟
                    TextField(
                      controller: iconeController, 
                      decoration: InputDecoration(
                        labelText: 'Ícone (Ex: face, business, local_hospital)', 
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(IconesSistema.traduzir(iconeController.text), color: const Color(0xFF00447C)),
                      ),
                      onChanged: (text) => setModalState(() {}), // Atualiza o ícone ao digitar
                    ),
                    const SizedBox(height: 16),

                    const Align(alignment: Alignment.centerLeft, child: Text('Este perfil será exclusivo para:')),
                    Row(
                      children: [
                        Radio<String>(value: 'F', groupValue: tipoSelecionado, onChanged: (v) => setModalState(() => tipoSelecionado = v!)),
                        const Text('Pessoa Física'),
                        const SizedBox(width: 16),
                        Radio<String>(value: 'J', groupValue: tipoSelecionado, onChanged: (v) => setModalState(() => tipoSelecionado = v!)),
                        const Text('Pessoa Jurídica'),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nomeController.text.isEmpty) return;
                    try {
                      final dados = {
                        'nome': nomeController.text, 
                        'tipo_pessoa': tipoSelecionado,
                        'icone': iconeController.text.isEmpty ? 'label' : iconeController.text // Salva o ícone
                      };
                      if (editando) {
                        await _supabase.from('cad_perfis_atuacao').update(dados).eq('id', perfilAtual['id']);
                      } else {
                        await _supabase.from('cad_perfis_atuacao').insert(dados);
                      }
                      if (mounted) Navigator.pop(context);
                      _buscarDados();
                    } catch (e) {
                      debugPrint('Erro ao salvar: $e');
                    }
                  },
                  child: const Text('Salvar'),
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
    if (_carregando) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white,
        onPressed: () => _mostrarFormulario(), icon: const Icon(Icons.add), label: const Text('Novo Perfil'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _perfis.length,
        itemBuilder: (context, index) {
          final perfil = _perfis[index];
          bool isFisica = perfil['tipo_pessoa'] == 'F';
          return Card(
            child: ListTile(
              // 🌟 MOSTRA O ÍCONE OFICIAL DO PERFIL AQUI TAMBÉM 🌟
              leading: CircleAvatar(
                backgroundColor: isFisica ? Colors.blue.shade50 : Colors.orange.shade50,
                child: Icon(IconesSistema.traduzir(perfil['icone']), color: isFisica ? Colors.blue : Colors.orange),
              ),
              title: Text(perfil['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isFisica ? 'Exclusivo para Pessoa Física (CPF)' : 'Exclusivo para Pessoa Jurídica (CNPJ)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(perfil)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _excluirPerfil(perfil['id'])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}