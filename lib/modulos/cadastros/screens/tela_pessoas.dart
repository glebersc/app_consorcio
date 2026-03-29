import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../core/utils/icones_sistema.dart'; // 🌟 Importador de ícones

class TelaPessoas extends StatefulWidget {
  const TelaPessoas({super.key});

  @override
  State<TelaPessoas> createState() => _TelaPessoasState();
}

class _TelaPessoasState extends State<TelaPessoas> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _pessoasBanco = []; 
  List<dynamic> _pessoasFiltradas = []; 
  List<dynamic> _grupos = [];
  List<dynamic> _todosOsPerfis = []; // Lista Mestra de Perfis do Banco
  bool _carregando = true;

  final _buscaController = TextEditingController();
  Set<int> _filtrosDePerfilAtivos = {}; // Guarda IDs dos perfis que o usuário clicou para filtrar

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      // BUSCA MULTI-RELACIONAL: Pessoa -> Usuário E Pessoa -> Perfis Atrelados
      final resPessoas = await _supabase.from('cad_pessoas').select('''
        *,
        sys_usuarios (id, grupo_id, sys_grupos(nome)),
        cad_pessoas_perfis (perfil_id)
      ''').order('nome');
      
      final resGrupos = await _supabase.from('sys_grupos').select().order('nome');
      final resPerfis = await _supabase.from('cad_perfis_atuacao').select().order('nome');
      
      setState(() {
        _pessoasBanco = resPessoas;
        _grupos = resGrupos;
        _todosOsPerfis = resPerfis;
      });
      _aplicarFiltros(); 
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _pessoasFiltradas = _pessoasBanco.where((p) {
        final termo = _buscaController.text.toLowerCase();
        final matchTexto = p['nome'].toString().toLowerCase().contains(termo) || p['documento'].toString().contains(termo);

        bool matchFiltros = true;
        if (_filtrosDePerfilAtivos.isNotEmpty) {
          matchFiltros = false;
          // Pega a lista de IDs de perfil que essa pessoa tem
          List<int> perfisDessaPessoa = (p['cad_pessoas_perfis'] as List).map<int>((item) => item['perfil_id'] as int).toList();
          
          // Se a pessoa tiver PELO MENOS UM dos perfis marcados no filtro, ela aparece!
          for (var idFiltro in _filtrosDePerfilAtivos) {
            if (perfisDessaPessoa.contains(idFiltro)) {
              matchFiltros = true;
              break;
            }
          }
        }
        return matchTexto && matchFiltros;
      }).toList();
    });
  }

  Future<void> _excluirPessoa(int id) async {
    try {
      await _supabase.from('cad_pessoas').delete().eq('id', id);
      _buscarDados();
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? pessoaAtual]) {
    final bool editando = pessoaAtual != null;
    int abaAtiva = 0; 

    String tipoPessoa = editando ? pessoaAtual['tipo_pessoa'] : 'F';
    final nomeController = TextEditingController(text: editando ? pessoaAtual['nome'] : '');
    final emailController = TextEditingController(text: editando ? pessoaAtual['email'] : '');
    final telefoneController = TextEditingController(text: editando ? pessoaAtual['telefone'] : '');
    
    // Controle Dinâmico de Perfis Selecionados
    Set<int> perfisSelecionados = {};
    if (editando) {
      perfisSelecionados = (pessoaAtual['cad_pessoas_perfis'] as List).map<int>((item) => item['perfil_id'] as int).toSet();
    }

    var maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
    var maskCnpj = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
    final docController = TextEditingController(text: editando ? (tipoPessoa == 'F' ? maskCpf.maskText(pessoaAtual['documento']) : maskCnpj.maskText(pessoaAtual['documento'])) : '');
    
    DateTime? dataSelecionada;
    final dataController = TextEditingController();
    if (editando && pessoaAtual['data_nascimento'] != null) {
      dataSelecionada = DateTime.parse(pessoaAtual['data_nascimento']);
      dataController.text = "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}/${dataSelecionada.year}";
    }

    bool temAcesso = editando && pessoaAtual['sys_usuarios'] != null;
    final senhaController = TextEditingController();
    int? grupoSelecionado = temAcesso ? pessoaAtual['sys_usuarios']['grupo_id'] : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Só exibe perfis que baterem com PF ou PJ
            var perfisPermitidosNestaTela = _todosOsPerfis.where((p) => p['tipo_pessoa'] == tipoPessoa).toList();

            Widget construirConteudoDireita() {
              if (abaAtiva == 0) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dados Principais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(),
                      
                      Row(
                        children: [
                          Radio<String>(value: 'F', groupValue: tipoPessoa, onChanged: (val) { 
                            setModalState(() { tipoPessoa = val!; docController.clear(); perfisSelecionados.clear(); }); 
                          }),
                          const Text('Pessoa Física (CPF)'),
                          const SizedBox(width: 20),
                          Radio<String>(value: 'J', groupValue: tipoPessoa, onChanged: (val) { 
                            setModalState(() { tipoPessoa = val!; docController.clear(); perfisSelecionados.clear(); }); 
                          }),
                          const Text('Pessoa Jurídica (CNPJ)'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(controller: nomeController, decoration: InputDecoration(labelText: tipoPessoa == 'F' ? 'Nome Completo' : 'Razão Social', border: const OutlineInputBorder())),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(child: TextField(controller: docController, inputFormatters: [tipoPessoa == 'F' ? maskCpf : maskCnpj], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tipoPessoa == 'F' ? 'CPF' : 'CNPJ', border: const OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: dataController, readOnly: true,
                              decoration: InputDecoration(labelText: tipoPessoa == 'F' ? 'Data de Nascimento' : 'Data de Fundação', suffixIcon: const Icon(Icons.calendar_today), border: const OutlineInputBorder()),
                              onTap: () async {
                                DateTime? pick = await showDatePicker(context: context, initialDate: dataSelecionada ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                                if (pick != null) { setModalState(() { dataSelecionada = pick; dataController.text = "${pick.day.toString().padLeft(2, '0')}/${pick.month.toString().padLeft(2, '0')}/${pick.year}"; }); }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(child: TextField(controller: telefoneController, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail Principal', border: OutlineInputBorder()))),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text('Perfis de Atuação (Tags Dinâmicas)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(),
                      
                      // GERA OS BOTÕES BASEADO NO BANCO COM ÍCONES!
                      perfisPermitidosNestaTela.isEmpty 
                        ? const Text('Nenhum perfil cadastrado para este tipo de pessoa.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                        : Wrap(
                            spacing: 16, runSpacing: 16,
                            children: perfisPermitidosNestaTela.map((perfil) {
                              return FilterChip(
                                avatar: Icon(IconesSistema.traduzir(perfil['icone']), size: 18, color: const Color(0xFF00447C)),
                                label: Text(perfil['nome']),
                                selected: perfisSelecionados.contains(perfil['id']),
                                onSelected: (marcado) {
                                  setModalState(() {
                                    if (marcado) perfisSelecionados.add(perfil['id']);
                                    else perfisSelecionados.remove(perfil['id']);
                                  });
                                },
                                selectedColor: Colors.blue.shade100,
                              );
                            }).toList(),
                          )
                    ],
                  ),
                );
              } else {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Controle de Acesso Web', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text('Permitir acesso ao sistema para esta pessoa?', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Isso criará um usuário vinculado ao documento (CPF/CNPJ).'),
                        value: temAcesso,
                        activeColor: const Color(0xFF00447C),
                        onChanged: (val) { setModalState(() => temAcesso = val); }
                      ),
                      
                      if (temAcesso) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<int>(
                                value: grupoSelecionado,
                                decoration: const InputDecoration(labelText: 'Grupo de Permissões', border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<int>(value: null, child: Text('Selecione um grupo...')),
                                  ..._grupos.map((g) => DropdownMenuItem<int>(value: g['id'], child: Text(g['nome']))),
                                ],
                                onChanged: (valor) => setModalState(() => grupoSelecionado = valor),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: senhaController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: editando && pessoaAtual['sys_usuarios'] != null ? 'Redefinir Senha (Deixe em branco para manter a atual)' : 'Senha de Acesso Inicial', 
                                  border: const OutlineInputBorder(),
                                  helperText: 'A senha será marcada como "temporária" e forçará a troca no primeiro login.'
                                )
                              ),
                            ],
                          ),
                        )
                      ]
                    ],
                  ),
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SizedBox(
                width: 900, height: 600,
                child: Row(
                  children: [
                    Container(
                      width: 250,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)), border: Border(right: BorderSide(color: Colors.grey.shade300))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text('Cadastro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                          ),
                          ListTile(
                            leading: Icon(Icons.person, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.grey),
                            title: Text('Dados Gerais', style: TextStyle(fontWeight: abaAtiva == 0 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 0, selectedTileColor: Colors.blue.withOpacity(0.1),
                            onTap: () => setModalState(() => abaAtiva = 0),
                          ),
                          ListTile(
                            leading: Icon(Icons.security, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.grey),
                            title: Text('Acesso ao Sistema', style: TextStyle(fontWeight: abaAtiva == 1 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 1, selectedTileColor: Colors.blue.withOpacity(0.1),
                            onTap: () => setModalState(() => abaAtiva = 1),
                          ),
                          const Spacer(),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                icon: const Icon(Icons.close, color: Colors.red), label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                                onPressed: () => Navigator.pop(context)
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Expanded(child: construirConteudoDireita()),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                                icon: const Icon(Icons.save),
                                label: const Text('Salvar Cadastro', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  String docLimpo = tipoPessoa == 'F' ? maskCpf.unmaskText(docController.text) : maskCnpj.unmaskText(docController.text);
                                  
                                  if (nomeController.text.isEmpty || docLimpo.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e Documento são obrigatórios.'), backgroundColor: Colors.red));
                                    return;
                                  }

                                  String? dataBanco;
                                  if (dataSelecionada != null) {
                                    dataBanco = "${dataSelecionada!.year}-${dataSelecionada!.month.toString().padLeft(2, '0')}-${dataSelecionada!.day.toString().padLeft(2, '0')}";
                                  }

                                  try {
                                    int pessoaId;
                                    
                                    final Map<String, dynamic> dadosPessoa = {
                                      'tipo_pessoa': tipoPessoa, 'nome': nomeController.text, 'documento': docLimpo,
                                      'email': emailController.text, 'telefone': telefoneController.text, 'data_nascimento': dataBanco
                                    };

                                    if (editando) {
                                      await _supabase.from('cad_pessoas').update(dadosPessoa).eq('id', pessoaAtual['id']);
                                      pessoaId = pessoaAtual['id'];
                                      // Limpa as permissões antigas da pessoa
                                      await _supabase.from('cad_pessoas_perfis').delete().eq('pessoa_id', pessoaId);
                                    } else {
                                      final insert = await _supabase.from('cad_pessoas').insert(dadosPessoa).select();
                                      pessoaId = insert[0]['id'];
                                    }

                                    // Salva as novas permissões dinâmicas
                                    if (perfisSelecionados.isNotEmpty) {
                                      List<Map<String, dynamic>> listaPerfisSalvar = perfisSelecionados.map((idPerfil) {
                                        return {'pessoa_id': pessoaId, 'perfil_id': idPerfil};
                                      }).toList();
                                      await _supabase.from('cad_pessoas_perfis').insert(listaPerfisSalvar);
                                    }

                                    if (temAcesso) {
                                      final Map<String, dynamic> dadosUsuario = { 'pessoa_id': pessoaId, 'grupo_id': grupoSelecionado };
                                      if (senhaController.text.isNotEmpty) {
                                        dadosUsuario['senha'] = senhaController.text;
                                        dadosUsuario['senha_temporaria'] = true; 
                                      }

                                      final checkUser = await _supabase.from('sys_usuarios').select('id').eq('pessoa_id', pessoaId).maybeSingle();
                                      if (checkUser != null) {
                                        await _supabase.from('sys_usuarios').update(dadosUsuario).eq('id', checkUser['id']);
                                      } else {
                                        if (senhaController.text.isEmpty) throw Exception('Digite uma senha inicial para o acesso.');
                                        await _supabase.from('sys_usuarios').insert(dadosUsuario);
                                      }
                                    } else {
                                      await _supabase.from('sys_usuarios').delete().eq('pessoa_id', pessoaId);
                                    }

                                    if (mounted) Navigator.pop(context);
                                    _buscarDados();
                                  } catch (e) {
                                    debugPrint('Erro ao salvar: $e');
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar. Verifique se o CPF/CNPJ já existe.'), backgroundColor: Colors.red));
                                  }
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
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
        icon: const Icon(Icons.add_business),
        label: const Text('Nova Pessoa / Entidade'),
      ),
      body: Column(
        children: [
          // 🌟 BARRA DE BUSCA E FILTROS DINÂMICOS 🌟
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por Nome ou Documento...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => _aplicarFiltros(), 
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      // GERA OS CHIPS DO TOPO BASEADO NA LISTA DE PERFIS (AGORA COM ÍCONES!)
                      children: _todosOsPerfis.map((perfil) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: Icon(IconesSistema.traduzir(perfil['icone']), size: 18, color: const Color(0xFF00447C)),
                            label: Text(perfil['nome']),
                            selected: _filtrosDePerfilAtivos.contains(perfil['id']),
                            onSelected: (marcado) {
                              setState(() {
                                if (marcado) _filtrosDePerfilAtivos.add(perfil['id']);
                                else _filtrosDePerfilAtivos.remove(perfil['id']);
                              });
                              _aplicarFiltros();
                            },
                            selectedColor: Colors.blue.shade100,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                  columns: const [
                    DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Nome / Razão Social', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Documento', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Perfis', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Acesso Web?', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _pessoasFiltradas.map((pessoa) { 
                    bool temAcesso = pessoa['sys_usuarios'] != null;
                    String nomeGrupo = temAcesso && pessoa['sys_usuarios']['sys_grupos'] != null 
                        ? pessoa['sys_usuarios']['sys_grupos']['nome'] : 'Sem Grupo';

                    // 🌟 GERA AS TAGS DA TABELA COM ÍCONE E TEXTO 🌟
                    List<int> idsDessaPessoa = (pessoa['cad_pessoas_perfis'] as List).map<int>((i) => i['perfil_id'] as int).toList();
                    var perfisDessaPessoa = _todosOsPerfis.where((p) => idsDessaPessoa.contains(p['id'])).toList();

                    return DataRow(
                      cells: [
                        DataCell(Icon(pessoa['tipo_pessoa'] == 'F' ? Icons.person : Icons.business, color: Colors.grey)),
                        DataCell(Text(pessoa['nome'])),
                        DataCell(Text(pessoa['documento'])),
                        DataCell(
                          Wrap(
                            spacing: 4,
                            children: perfisDessaPessoa.map((p) => Chip(
                              avatar: Icon(IconesSistema.traduzir(p['icone']), size: 14),
                              label: Text(p['nome'], style: const TextStyle(fontSize: 10)), 
                              padding: EdgeInsets.zero, 
                              visualDensity: VisualDensity.compact
                            )).toList()
                          )
                        ),
                        DataCell(
                          temAcesso 
                            ? Chip(label: Text(nomeGrupo, style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.green)
                            : const Chip(label: Text('Bloqueado', style: TextStyle(fontSize: 12)), backgroundColor: Colors.grey)
                        ),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(pessoa)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _excluirPessoa(pessoa['id'])),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}