import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelaGruposPermissoes extends StatefulWidget {
  const TelaGruposPermissoes({super.key});

  @override
  State<TelaGruposPermissoes> createState() => _TelaGruposPermissoesState();
}

class _TelaGruposPermissoesState extends State<TelaGruposPermissoes> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _grupos = [];
  List<dynamic> _todosOsMenus = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      // Busca os grupos e TODOS os menus do sistema de uma vez
      final respostaGrupos = await _supabase.from('sys_grupos').select().order('nome');
      final respostaMenus = await _supabase.from('sys_menus').select().order('ordem');
      
      setState(() {
        _grupos = respostaGrupos;
        _todosOsMenus = respostaMenus;
      });
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _excluirGrupo(int id) async {
    try {
      await _supabase.from('sys_grupos').delete().eq('id', id);
      _buscarDados();
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? grupoAtual]) async {
    final bool editando = grupoAtual != null;
    final nomeController = TextEditingController(text: editando ? grupoAtual['nome'] : '');
    final descController = TextEditingController(text: editando ? grupoAtual['descricao'] : '');
    
    // Conjunto (Set) para guardar os IDs dos menus que estão marcados
    Set<int> menusSelecionados = {};
    bool carregandoPermissoes = editando;

    // Se estiver editando, vai no banco buscar o que já estava marcado
    if (editando) {
      try {
        final permissoes = await _supabase.from('sys_permissoes').select('menu_id').eq('grupo_id', grupoAtual['id']);
        menusSelecionados = permissoes.map<int>((p) => p['menu_id'] as int).toSet();
      } catch (e) {
        debugPrint('Erro ao buscar permissões: $e');
      }
      carregandoPermissoes = false;
    }

    // Filtra para a construção visual
    var menusPais = _todosOsMenus.where((m) => m['parent_id'] == null).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(editando ? 'Editar Grupo e Permissões' : 'Novo Grupo de Acesso', style: const TextStyle(color: Color(0xFF00447C))),
              content: SizedBox(
                width: 500, // Deixei a janela mais larguinha
                child: carregandoPermissoes 
                  ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Grupo (Ex: Vendedores)')),
                          const SizedBox(height: 8),
                          TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descrição (Opcional)')),
                          const SizedBox(height: 24),
                          
                          const Text('Liberação de Telas e Menus:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Divider(),
                          
                          // 🌟 A ÁRVORE DINÂMICA DE PERMISSÕES 🌟
                          ...menusPais.map((pai) {
                            var filhos = _todosOsMenus.where((m) => m['parent_id'] == pai['id']).toList();
                            return Column(
                              children: [
                                // Checkbox do Menu Pai
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: const Color(0xFF00447C),
                                  title: Text(pai['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  value: menusSelecionados.contains(pai['id']),
                                  onChanged: (bool? marcado) {
                                    setDialogState(() {
                                      if (marcado == true) {
                                        menusSelecionados.add(pai['id']);
                                      } else {
                                        menusSelecionados.remove(pai['id']);
                                        // Dica UX: Se desmarcar o pai, desmarca os filhos junto
                                        for (var f in filhos) { menusSelecionados.remove(f['id']); }
                                      }
                                    });
                                  },
                                ),
                                // Checkboxes dos Submenus (Filhos)
                                ...filhos.map((filho) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 32.0), // Recuo visual
                                    child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: const Color(0xFF00447C),
                                      title: Text(filho['titulo']),
                                      value: menusSelecionados.contains(filho['id']),
                                      onChanged: (bool? marcado) {
                                        setDialogState(() {
                                          if (marcado == true) {
                                            menusSelecionados.add(filho['id']);
                                            // Dica UX: Se marcar um filho, obriga a marcar o pai pra pasta aparecer
                                            menusSelecionados.add(pai['id']);
                                          } else {
                                            menusSelecionados.remove(filho['id']);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      int grupoId;
                      // 1. Salva os dados do Grupo
                      if (editando) {
                        await _supabase.from('sys_grupos').update({'nome': nomeController.text, 'descricao': descController.text}).eq('id', grupoAtual['id']);
                        grupoId = grupoAtual['id'];
                        // Limpa as permissões antigas desse grupo para gravar as novas
                        await _supabase.from('sys_permissoes').delete().eq('grupo_id', grupoId);
                      } else {
                        final insert = await _supabase.from('sys_grupos').insert({'nome': nomeController.text, 'descricao': descController.text}).select();
                        grupoId = insert[0]['id'];
                      }

                      // 2. Salva as permissões marcadas (Salva em lote para ser ultra rápido)
                      if (menusSelecionados.isNotEmpty) {
                        List<Map<String, dynamic>> listaParaSalvar = menusSelecionados.map((menuId) {
                          return {'grupo_id': grupoId, 'menu_id': menuId};
                        }).toList();
                        
                        await _supabase.from('sys_permissoes').insert(listaParaSalvar);
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
        backgroundColor: const Color(0xFF00447C),
        foregroundColor: Colors.white,
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.security),
        label: const Text('Novo Grupo'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _grupos.length,
        itemBuilder: (context, index) {
          final grupo = _grupos[index];
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF00447C), child: Icon(Icons.group, color: Colors.white)),
              title: Text(grupo['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(grupo['descricao'] ?? 'Sem descrição'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(grupo)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _excluirGrupo(grupo['id'])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}