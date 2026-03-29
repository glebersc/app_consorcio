import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class TelaUsuarios extends StatefulWidget {
  const TelaUsuarios({super.key});

  @override
  State<TelaUsuarios> createState() => _TelaUsuariosState();
}

class _TelaUsuariosState extends State<TelaUsuarios> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _usuarios = [];
  List<dynamic> _grupos = [];
  bool _carregando = true;

  // Máscara para o CPF
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      // Busca os usuários e faz um "JOIN" para trazer o nome do grupo junto
      final resUsuarios = await _supabase.from('sys_usuarios').select('*, sys_grupos(nome)').order('nome_completo');
      final resGrupos = await _supabase.from('sys_grupos').select().order('nome');
      
      setState(() {
        _usuarios = resUsuarios;
        _grupos = resGrupos;
      });
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _excluirUsuario(int id) async {
    try {
      await _supabase.from('sys_usuarios').delete().eq('id', id);
      _buscarDados();
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? userAtual]) {
    final bool editando = userAtual != null;
    
    final nomeController = TextEditingController(text: editando ? userAtual['nome_completo'] : '');
    final emailController = TextEditingController(text: editando ? userAtual['email'] : '');
    final senhaController = TextEditingController(text: editando ? userAtual['senha'] : '');
    
    // Configura o CPF já com a máscara caso esteja editando
    final cpfController = TextEditingController(text: editando ? _cpfMask.maskText(userAtual['cpf']) : '');
    
    // Configura a data
    DateTime? dataSelecionada;
    final dataController = TextEditingController();
    if (editando && userAtual['data_nascimento'] != null) {
      dataSelecionada = DateTime.parse(userAtual['data_nascimento']);
      dataController.text = "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}/${dataSelecionada.year}";
    }

    int? grupoSelecionado = editando ? userAtual['grupo_id'] : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(editando ? 'Editar Usuário' : 'Novo Usuário', style: const TextStyle(color: Color(0xFF00447C))),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome Completo')),
                      const SizedBox(height: 10),
                      
                      TextField(
                        controller: cpfController, 
                        inputFormatters: [_cpfMask], // Aplica a máscara aqui
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'CPF')
                      ),
                      const SizedBox(height: 10),
                      
                      // Campo de Data com Calendário
                      TextField(
                        controller: dataController,
                        readOnly: true, // Impede de digitar texto aleatório
                        decoration: const InputDecoration(
                          labelText: 'Data de Nascimento',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          DateTime? pick = await showDatePicker(
                            context: context,
                            initialDate: dataSelecionada ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (pick != null) {
                            setDialogState(() {
                              dataSelecionada = pick;
                              dataController.text = "${pick.day.toString().padLeft(2, '0')}/${pick.month.toString().padLeft(2, '0')}/${pick.year}";
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
                      const SizedBox(height: 10),
                      
                      TextField(controller: senhaController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
                      const SizedBox(height: 10),
                      
                      DropdownButtonFormField<int>(
                        value: grupoSelecionado,
                        decoration: const InputDecoration(labelText: 'Grupo de Permissões'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('Sem Grupo (Acesso Bloqueado)')),
                          ..._grupos.map((g) => DropdownMenuItem<int>(value: g['id'], child: Text(g['nome']))),
                        ],
                        onChanged: (valor) => setDialogState(() => grupoSelecionado = valor),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white),
                  onPressed: () async {
                    // Prepara a data para o banco (YYYY-MM-DD)
                    String? dataBanco;
                    if (dataSelecionada != null) {
                      dataBanco = "${dataSelecionada!.year}-${dataSelecionada!.month.toString().padLeft(2, '0')}-${dataSelecionada!.day.toString().padLeft(2, '0')}";
                    }

                    // Remove a máscara do CPF para salvar só os números no banco
                    String cpfLimpo = _cpfMask.unmaskText(cpfController.text);

                    final dados = {
                      'nome_completo': nomeController.text,
                      'cpf': cpfLimpo.isEmpty ? null : cpfLimpo,
                      'data_nascimento': dataBanco,
                      'email': emailController.text,
                      'senha': senhaController.text,
                      'grupo_id': grupoSelecionado,
                    };

                    try {
                      if (editando) {
                        await _supabase.from('sys_usuarios').update(dados).eq('id', userAtual['id']);
                      } else {
                        await _supabase.from('sys_usuarios').insert(dados);
                      }
                      if (mounted) Navigator.pop(context);
                      _buscarDados();
                    } catch (e) {
                      debugPrint('Erro ao salvar: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro! Verifique se CPF ou E-mail já existem.'), backgroundColor: Colors.red));
                      }
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
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Usuário'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
            columns: const [
              DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('E-mail', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Grupo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _usuarios.map((user) {
              return DataRow(
                cells: [
                  DataCell(Text(user['nome_completo'])),
                  DataCell(Text(user['email'])),
                  // Mostra o nome do grupo vindo do JOIN, ou 'Sem Grupo'
                  DataCell(Text(user['sys_grupos'] != null ? user['sys_grupos']['nome'] : 'Sem Grupo', style: TextStyle(color: user['sys_grupos'] == null ? Colors.red : Colors.black))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(user)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _excluirUsuario(user['id'])),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}