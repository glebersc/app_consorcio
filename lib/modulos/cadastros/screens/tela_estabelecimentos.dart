import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/servico_cep.dart';

class TelaEstabelecimentos extends StatefulWidget {
  const TelaEstabelecimentos({super.key});

  @override
  State<TelaEstabelecimentos> createState() => _TelaEstabelecimentosState();
}

class _TelaEstabelecimentosState extends State<TelaEstabelecimentos> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _estabelecimentos = []; 
  List<dynamic> _estabelecimentosFiltrados = []; 
  bool _carregando = true;

  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      // Traz o estabelecimento e já lista as pessoas vinculadas a ele!
      final res = await _supabase.from('cad_estabelecimentos').select('''
        *,
        cad_vinculos (funcao, cad_pessoas (nome, documento))
      ''').order('razao_social');
      
      setState(() {
        _estabelecimentos = res;
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
      _estabelecimentosFiltrados = _estabelecimentos.where((e) {
        final termo = _buscaController.text.toLowerCase();
        return e['razao_social'].toString().toLowerCase().contains(termo) || 
               e['nome_fantasia'].toString().toLowerCase().contains(termo) || 
               e['cnpj'].toString().contains(termo);
      }).toList();
    });
  }

  Future<void> _excluir(int id) async {
    try { await _supabase.from('cad_estabelecimentos').delete().eq('id', id); _buscarDados(); } 
    catch (e) { debugPrint('Erro ao excluir: $e'); }
  }

  void _mostrarFormulario([Map<String, dynamic>? estabAtual]) {
    final bool editando = estabAtual != null;
    int abaAtiva = 0; 
    bool carregandoCep = false;

    var maskCnpj = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
    var maskCnes = MaskTextInputFormatter(mask: '#######', filter: {"#": RegExp(r'[0-9]')}); // CNES tem 7 digitos
    
    final cnpjController = TextEditingController(text: editando && estabAtual['cnpj'] != null ? maskCnpj.maskText(estabAtual['cnpj']) : '');
    final cnesController = TextEditingController(text: editando ? estabAtual['cnes'] : '');
    final razaoController = TextEditingController(text: editando ? estabAtual['razao_social'] : '');
    final fantasiaController = TextEditingController(text: editando ? estabAtual['nome_fantasia'] : '');
    
    String? tipoUnidade = editando ? estabAtual['tipo_unidade'] : null;
    String? complexidade = editando ? estabAtual['complexidade'] : null;
    final subtipoController = TextEditingController(text: editando ? estabAtual['subtipo'] : '');

    final tel1Controller = TextEditingController(text: editando ? estabAtual['telefone'] : '');
    final tel2Controller = TextEditingController(text: editando ? estabAtual['telefone_2'] : '');
    final tel3Controller = TextEditingController(text: editando ? estabAtual['telefone_3'] : '');
    final emailController = TextEditingController(text: editando ? estabAtual['email'] : '');
    
    var maskCep = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
    final cepController = TextEditingController(text: editando && estabAtual['cep'] != null ? maskCep.maskText(estabAtual['cep']) : '');
    final ufController = TextEditingController(text: editando ? estabAtual['uf'] : '');
    final municipioController = TextEditingController(text: editando ? estabAtual['municipio'] : '');
    final bairroController = TextEditingController(text: editando ? estabAtual['bairro'] : '');
    final logradouroController = TextEditingController(text: editando ? estabAtual['logradouro'] : '');
    final numeroController = TextEditingController(text: editando ? estabAtual['numero'] : '');
    bool semNumero = editando ? estabAtual['sem_numero'] ?? false : false;
    final complementoController = TextEditingController(text: editando ? estabAtual['complemento'] : '');
    final refController = TextEditingController(text: editando ? estabAtual['ponto_referencia'] : '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {

            Widget campoTexto(String label, TextEditingController ctrl, {List<TextInputFormatter>? masks}) {
              return TextField(controller: ctrl, inputFormatters: masks, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
            }

            Future<void> buscarCepLocal() async {
              setModalState(() => carregandoCep = true);
              final resultado = await ServicoCep.buscar(cepController.text);
              if (resultado != null) {
                setModalState(() {
                  logradouroController.text = resultado['logradouro']!; bairroController.text = resultado['bairro']!;
                  municipioController.text = resultado['municipio']!; ufController.text = resultado['uf']!;
                });
              }
              setModalState(() => carregandoCep = false);
            }

            Widget construirConteudoDireita() {
              if (abaAtiva == 0) { // IDENTIFICAÇÃO
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dados do Estabelecimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('CNPJ', cnpjController, masks: [maskCnpj])),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('CNES', cnesController, masks: [maskCnes])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      campoTexto('Razão Social *', razaoController),
                      const SizedBox(height: 16),
                      campoTexto('Nome Fantasia', fantasiaController),
                      const SizedBox(height: 32),
                      const Text('Classificação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tipoUnidade, decoration: const InputDecoration(labelText: 'Tipo de Unidade', border: OutlineInputBorder()),
                              items: ['Hospital', 'Clínica/Centro de Especialidades', 'Posto de Saúde (UBS)', 'Laboratório', 'Consultório Isolado', 'Farmácia', 'Secretaria de Saúde'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => tipoUnidade = val),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: complexidade, decoration: const InputDecoration(labelText: 'Complexidade', border: OutlineInputBorder()),
                              items: ['Atenção Básica', 'Média Complexidade', 'Alta Complexidade'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => complexidade = val),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('Subtipo (Opcional)', subtipoController)),
                        ],
                      )
                    ],
                  ),
                );
              } 
              else if (abaAtiva == 1) { // ENDEREÇO E CONTATO
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cepController, inputFormatters: [maskCep],
                              decoration: InputDecoration(labelText: 'CEP', border: const OutlineInputBorder(), suffixIcon: carregandoCep ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: buscarCepLocal)),
                              onSubmitted: (_) => buscarCepLocal(),
                            )
                          ),
                          const SizedBox(width: 16), Expanded(child: campoTexto('UF', ufController)),
                          const SizedBox(width: 16), Expanded(flex: 2, child: campoTexto('Município', municipioController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 2, child: campoTexto('Logradouro', logradouroController)),
                          const SizedBox(width: 16), Expanded(child: campoTexto('Número', numeroController)),
                          Checkbox(value: semNumero, onChanged: (v) => setModalState(() { semNumero = v!; if(v) numeroController.clear(); })),
                          const Text('S/N', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Bairro', bairroController)),
                          const SizedBox(width: 16), Expanded(child: campoTexto('Complemento', complementoController)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Contatos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Telefone 1', tel1Controller)), const SizedBox(width: 16),
                          Expanded(child: campoTexto('Telefone 2', tel2Controller)), const SizedBox(width: 16),
                          Expanded(child: campoTexto('Telefone 3', tel3Controller)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      campoTexto('E-mail do Estabelecimento', emailController),
                    ]
                  )
                );
              } else { // VÍNCULOS
                 // Aqui listamos quem faz parte. O cadastro do vínculo será feito na Tela de Pessoas!
                 List<dynamic> vinculados = editando ? estabAtual['cad_vinculos'] : [];
                 
                 return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profissionais e Vínculos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      const Text('A gestão de vínculos (adicionar pessoas) é realizada através da tela "Cadastro Pessoa". Abaixo estão os profissionais atualmente vinculados a esta unidade:', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      
                      vinculados.isEmpty 
                        ? const Center(child: Text('Nenhum profissional vinculado ainda.', style: TextStyle(fontStyle: FontStyle.italic)))
                        : Expanded(
                            child: ListView.builder(
                              itemCount: vinculados.length,
                              itemBuilder: (context, index) {
                                final v = vinculados[index];
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.person)),
                                    title: Text(v['cad_pessoas']['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Função: ${v['funcao']}'),
                                  ),
                                );
                              },
                            ),
                          )
                    ],
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
                      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(right: BorderSide(color: Colors.grey.shade300))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.all(24.0), child: Text('Estabelecimento', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00447C)))),
                          ListTile(
                            leading: Icon(Icons.business, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.grey), title: Text('Identificação', style: TextStyle(fontWeight: abaAtiva == 0 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 0, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 0),
                          ),
                          ListTile(
                            leading: Icon(Icons.location_on, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.grey), title: Text('Endereço e Contato', style: TextStyle(fontWeight: abaAtiva == 1 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 1, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 1),
                          ),
                          if (editando) ListTile(
                            leading: Icon(Icons.people, color: abaAtiva == 2 ? const Color(0xFF00447C) : Colors.grey), title: Text('Equipe / Vínculos', style: TextStyle(fontWeight: abaAtiva == 2 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 2 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 2, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 2),
                          ),
                          const Spacer(), const Divider(),
                          Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, child: TextButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('Cancelar', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context))))
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
                                icon: const Icon(Icons.save), label: const Text('Salvar Estabelecimento', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  if (razaoController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A Razão Social é obrigatória.'), backgroundColor: Colors.red)); return;
                                  }

                                  try {
                                    final dados = {
                                      'cnpj': maskCnpj.unmaskText(cnpjController.text).isEmpty ? null : maskCnpj.unmaskText(cnpjController.text),
                                      'cnes': cnesController.text, 'razao_social': razaoController.text, 'nome_fantasia': fantasiaController.text,
                                      'tipo_unidade': tipoUnidade, 'complexidade': complexidade, 'subtipo': subtipoController.text,
                                      'telefone': tel1Controller.text, 'telefone_2': tel2Controller.text, 'telefone_3': tel3Controller.text, 'email': emailController.text,
                                      'cep': maskCep.unmaskText(cepController.text), 'uf': ufController.text, 'municipio': municipioController.text, 'bairro': bairroController.text,
                                      'logradouro': logradouroController.text, 'sem_numero': semNumero, 'numero': semNumero ? null : numeroController.text,
                                      'complemento': complementoController.text, 'ponto_referencia': refController.text,
                                    };

                                    if (editando) { await _supabase.from('cad_estabelecimentos').update(dados).eq('id', estabAtual['id']); } 
                                    else { await _supabase.from('cad_estabelecimentos').insert(dados); }

                                    if (mounted) Navigator.pop(context);
                                    _buscarDados();
                                  } catch (e) {
                                    debugPrint('Erro ao salvar: $e');
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar. Verifique se o CNPJ já existe.'), backgroundColor: Colors.red));
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
        backgroundColor: const Color(0xFF00447C), foregroundColor: Colors.white,
        onPressed: () => _mostrarFormulario(), icon: const Icon(Icons.add_business), label: const Text('Novo Estabelecimento'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(hintText: 'Buscar por Razão Social, Fantasia ou CNPJ...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              onChanged: (value) => _aplicarFiltros(), 
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
                    DataColumn(label: Text('Razão Social / Fantasia', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CNPJ', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CNES', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _estabelecimentosFiltrados.map((estab) { 
                    return DataRow(
                      cells: [
                        DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [ Text(estab['razao_social'], style: const TextStyle(fontWeight: FontWeight.bold)), if(estab['nome_fantasia'] != null && estab['nome_fantasia'].toString().isNotEmpty) Text(estab['nome_fantasia'], style: const TextStyle(fontSize: 12, color: Colors.grey)) ])),
                        DataCell(Text(estab['cnpj'] != null ? MaskTextInputFormatter(mask: '##.###.###/####-##').maskText(estab['cnpj']) : '-')),
                        DataCell(Text(estab['cnes'] ?? '-')),
                        DataCell(Text(estab['tipo_unidade'] ?? '-')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(estab)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _excluir(estab['id'])),
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