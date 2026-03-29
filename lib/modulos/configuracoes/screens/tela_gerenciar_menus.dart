import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/icones_sistema.dart'; // Nosso Dicionário Central!

class TelaGerenciarMenus extends StatefulWidget {
  const TelaGerenciarMenus({super.key});

  @override
  State<TelaGerenciarMenus> createState() => _TelaGerenciarMenusState();
}

class _TelaGerenciarMenusState extends State<TelaGerenciarMenus> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _menusDoBanco = [];
  List<Map<String, dynamic>> _menusExibicao = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarMenus();
  }

  Future<void> _buscarMenus() async {
    setState(() => _carregando = true);
    try {
      final resposta = await _supabase.from('sys_menus').select().order('ordem', ascending: true);
      _menusDoBanco = resposta;
      _construirListaHierarquica();
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _construirListaHierarquica() {
    _menusExibicao.clear();
    var pais = _menusDoBanco.where((m) => m['parent_id'] == null).toList();
    for (var pai in pais) {
      _menusExibicao.add(Map<String, dynamic>.from(pai));
      var filhos = _menusDoBanco.where((m) => m['parent_id'] == pai['id']).toList();
      for (var filho in filhos) {
        _menusExibicao.add(Map<String, dynamic>.from(filho));
      }
    }
  }

  Future<void> _atualizarOrdemNoBanco() async {
    try {
      for (int i = 0; i < _menusExibicao.length; i++) {
        await _supabase.from('sys_menus').update({'ordem': i}).eq('id', _menusExibicao[i]['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ordem salva com sucesso!'), backgroundColor: Colors.green));
      }
      _buscarMenus(); 
    } catch (e) {
      debugPrint('Erro ao reordenar: $e');
    }
  }

  Future<void> _excluirMenu(int id) async {
    try {
      await _supabase.from('sys_menus').delete().eq('id', id);
      _buscarMenus();
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? menuAtual]) {
    final bool editando = menuAtual != null;
    final tituloController = TextEditingController(text: editando ? menuAtual['titulo'] : '');
    final rotaController = TextEditingController(text: editando ? menuAtual['rota_tela'] : '');
    int? parentIdSelecionado = editando ? menuAtual['parent_id'] : null;
    String? iconeSelecionado = editando ? menuAtual['icone'] : null;
    
    // 🌟 NOVA VARIÁVEL: Guarda o tipo do menu 🌟
    String tipoAcaoSelecionado = editando ? (menuAtual['tipo_acao'] ?? 'tela') : 'tela';

    if (iconeSelecionado != null && !IconesSistema.catalogo.containsKey(iconeSelecionado)) {
      iconeSelecionado = null;
    }

    final menusPais = _menusDoBanco.where((m) => m['parent_id'] == null && (editando ? m['id'] != menuAtual['id'] : true)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(editando ? 'Editar Menu' : 'Novo Menu', style: const TextStyle(color: Color(0xFF00447C))),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: tituloController, decoration: const InputDecoration(labelText: 'Título do Menu (Ex: Relatórios)')),
                      const SizedBox(height: 16),
                      
                      // 🌟 O NOVO SELETOR DE TIPO DE AÇÃO 🌟
                      DropdownButtonFormField<String>(
                        value: tipoAcaoSelecionado,
                        decoration: const InputDecoration(labelText: 'O que este menu vai abrir?'),
                        items: const [
                          DropdownMenuItem(value: 'tela', child: Text('Tela Interna do Sistema')),
                          DropdownMenuItem(value: 'link_interno', child: Text('Link Embutido (Iframe)')),
                          DropdownMenuItem(value: 'link_externo', child: Text('Link Externo (Nova Aba)')),
                        ],
                        onChanged: (valor) => setDialogState(() => tipoAcaoSelecionado = valor!),
                      ),
                      
                      const SizedBox(height: 16),
                      // O rótulo do campo muda de acordo com o que o usuário escolheu acima
                      TextField(
                        controller: rotaController, 
                        decoration: InputDecoration(
                          labelText: tipoAcaoSelecionado == 'tela' 
                              ? 'Rota da Tela (Ex: tela_relatorios)' 
                              : 'URL do Link (Ex: https://meusistema.com)'
                        )
                      ),

                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: parentIdSelecionado,
                        decoration: const InputDecoration(labelText: 'Submenu de (Opcional):'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('Nenhum (Menu Principal)')),
                          ...menusPais.map((m) => DropdownMenuItem<int>(value: m['id'], child: Text(m['titulo']))),
                        ],
                        onChanged: (valor) => setDialogState(() => parentIdSelecionado = valor),
                      ),
                      
                      const SizedBox(height: 24),
                      const Text('Selecione um Ícone:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Wrap(
                          spacing: 8, runSpacing: 8, 
                          children: IconesSistema.catalogo.entries.map((entry) {
                            final isSelected = iconeSelecionado == entry.key;
                            return InkWell(
                              onTap: () => setDialogState(() => iconeSelecionado = entry.key),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF00447C) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? const Color(0xFF00447C) : Colors.grey.shade300),
                                  boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00447C).withOpacity(0.3), blurRadius: 4, spreadRadius: 1)] : [],
                                ),
                                child: Icon(entry.value, color: isSelected ? Colors.white : Colors.black87, size: 24),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      if (iconeSelecionado != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setDialogState(() => iconeSelecionado = null), 
                            icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                            label: const Text('Remover Ícone', style: TextStyle(color: Colors.red, fontSize: 12))
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: () async {
                    final dados = {
                      'titulo': tituloController.text,
                      'icone': iconeSelecionado, 
                      'rota_tela': rotaController.text.isEmpty ? null : rotaController.text,
                      'parent_id': parentIdSelecionado,
                      'tipo_acao': tipoAcaoSelecionado, // 🌟 Salva o novo tipo no banco 🌟
                    };

                    try {
                      if (editando) {
                        await _supabase.from('sys_menus').update(dados).eq('id', menuAtual['id']);
                      } else {
                        dados['ordem'] = _menusExibicao.length;
                        await _supabase.from('sys_menus').insert(dados);
                      }
                      if (mounted) Navigator.pop(context);
                      _buscarMenus();
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
        icon: const Icon(Icons.add),
        label: const Text('Novo Menu'),
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.all(16),
        itemCount: _menusExibicao.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = _menusExibicao.removeAt(oldIndex);
            _menusExibicao.insert(newIndex, item);
          });
          _atualizarOrdemNoBanco();
        },
        itemBuilder: (context, index) {
          final menu = _menusExibicao[index];
          final bool isSubmenu = menu['parent_id'] != null;
          
          return ReorderableDragStartListener(
            key: ValueKey(menu['id']),
            index: index,
            child: Card(
              elevation: 1,
              margin: EdgeInsets.only(bottom: 8, left: isSubmenu ? 40 : 0),
              child: ListTile(
                leading: Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                title: Row(
                  children: [
                    // 🌟 CHAMA O CATÁLOGO CENTRAL AQUI TAMBÉM 🌟
                    Icon(
                      menu['icone'] != null && IconesSistema.catalogo.containsKey(menu['icone']) 
                          ? IconesSistema.catalogo[menu['icone']] 
                          : Icons.menu, 
                      color: isSubmenu ? Colors.grey : const Color(0xFF00447C), 
                      size: 18
                    ),
                    const SizedBox(width: 10),
                    Text(
                      menu['titulo'], 
                      style: TextStyle(fontWeight: isSubmenu ? FontWeight.normal : FontWeight.bold, color: isSubmenu ? Colors.black87 : const Color(0xFF00447C))
                    ),
                  ],
                ),
                subtitle: Text(menu['rota_tela'] ?? 'Pasta de Submenus', style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _mostrarFormulario(menu)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _excluirMenu(menu['id'])),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}