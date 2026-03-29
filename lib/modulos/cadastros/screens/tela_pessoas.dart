import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/icones_sistema.dart';
import '../../../core/utils/servico_cep.dart';
import '../../../core/utils/servico_imagem.dart';

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
  List<dynamic> _todosOsPerfisFisicos = [];
  bool _carregando = true;

  final _buscaController = TextEditingController();
  Set<int> _filtrosDePerfilAtivos = {};

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      final resPessoas = await _supabase.from('cad_pessoas')
          .select('*, sys_usuarios (id, grupo_id, sys_grupos(nome)), cad_pessoas_perfis (perfil_id)')
          .eq('tipo_pessoa', 'F').order('nome');
      final resGrupos = await _supabase.from('sys_grupos').select().order('nome');
      final resPerfis = await _supabase.from('cad_perfis_atuacao').select().eq('tipo_pessoa', 'F').order('nome');
      
      setState(() {
        _pessoasBanco = resPessoas; _grupos = resGrupos; _todosOsPerfisFisicos = resPerfis;
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
          List<int> perfisDessaPessoa = (p['cad_pessoas_perfis'] as List).map<int>((item) => item['perfil_id'] as int).toList();
          for (var idFiltro in _filtrosDePerfilAtivos) {
            if (perfisDessaPessoa.contains(idFiltro)) { matchFiltros = true; break; }
          }
        }
        return matchTexto && matchFiltros;
      }).toList();
    });
  }

  Future<void> _excluirPessoa(int id) async {
    try { await _supabase.from('cad_pessoas').delete().eq('id', id); _buscarDados(); } 
    catch (e) { debugPrint('Erro ao excluir: $e'); }
  }

  void _mostrarFormulario([Map<String, dynamic>? pessoaAtual]) {
    final bool editando = pessoaAtual != null;
    int abaAtiva = 0; 
    bool carregandoCep = false;

    // Controladores - Dados Básicos
    String? fotoBase64 = editando ? pessoaAtual['foto_base64'] : null;
    final nomeController = TextEditingController(text: editando ? pessoaAtual['nome'] : '');
    final nomeSocialController = TextEditingController(text: editando ? pessoaAtual['nome_social'] : '');
    
    var maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
    var maskCns = MaskTextInputFormatter(mask: '### #### #### ####', filter: {"#": RegExp(r'[0-9]')});
    final docController = TextEditingController(text: editando ? maskCpf.maskText(pessoaAtual['documento']) : '');
    final cnsController = TextEditingController(text: editando ? (pessoaAtual['cns'] != null ? maskCns.maskText(pessoaAtual['cns']) : '') : '');
    
    DateTime? dataNasc;
    final dataNascController = TextEditingController();
    if (editando && pessoaAtual['data_nascimento'] != null) {
      dataNasc = DateTime.parse(pessoaAtual['data_nascimento']);
      dataNascController.text = "${dataNasc.day.toString().padLeft(2, '0')}/${dataNasc.month.toString().padLeft(2, '0')}/${dataNasc.year}";
    }

    String? sexoSelecionado = editando ? pessoaAtual['sexo'] : null;
    String? racaSelecionada = editando ? pessoaAtual['raca_cor'] : null;
    
    // Filiação
    bool maeDesconhecida = editando ? pessoaAtual['mae_desconhecida'] ?? false : false;
    bool paiDesconhecido = editando ? pessoaAtual['pai_desconhecido'] ?? false : false;
    final nomeMaeController = TextEditingController(text: editando ? pessoaAtual['nome_mae'] : '');
    final nomePaiController = TextEditingController(text: editando ? pessoaAtual['nome_pai'] : '');

    // Nacionalidade
    String nacionalidade = editando ? pessoaAtual['nacionalidade'] ?? 'Brasileira' : 'Brasileira';
    final munNascController = TextEditingController(text: editando ? pessoaAtual['municipio_nascimento'] : '');
    final paisOrigemController = TextEditingController(text: editando ? pessoaAtual['pais_origem'] : '');
    
    DateTime? dataNatCheg;
    final dataNatChegController = TextEditingController();
    if (editando) {
      if (pessoaAtual['data_naturalizacao'] != null) dataNatCheg = DateTime.parse(pessoaAtual['data_naturalizacao']);
      if (pessoaAtual['data_chegada'] != null) dataNatCheg = DateTime.parse(pessoaAtual['data_chegada']);
      if (dataNatCheg != null) dataNatChegController.text = "${dataNatCheg.day.toString().padLeft(2, '0')}/${dataNatCheg.month.toString().padLeft(2, '0')}/${dataNatCheg.year}";
    }

    // Contato & Endereço
    final tel1Controller = TextEditingController(text: editando ? pessoaAtual['telefone'] : '');
    final tel2Controller = TextEditingController(text: editando ? pessoaAtual['telefone_2'] : '');
    final tel3Controller = TextEditingController(text: editando ? pessoaAtual['telefone_3'] : '');
    final emailController = TextEditingController(text: editando ? pessoaAtual['email'] : '');
    
    var maskCep = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});
    final cepController = TextEditingController(text: editando && pessoaAtual['cep'] != null ? maskCep.maskText(pessoaAtual['cep']) : '');
    final ufController = TextEditingController(text: editando ? pessoaAtual['uf'] : '');
    final municipioController = TextEditingController(text: editando ? pessoaAtual['municipio'] : '');
    final bairroController = TextEditingController(text: editando ? pessoaAtual['bairro'] : '');
    final logradouroController = TextEditingController(text: editando ? pessoaAtual['logradouro'] : '');
    final numeroController = TextEditingController(text: editando ? pessoaAtual['numero'] : '');
    bool semNumero = editando ? pessoaAtual['sem_numero'] ?? false : false;
    final complementoController = TextEditingController(text: editando ? pessoaAtual['complemento'] : '');
    final refController = TextEditingController(text: editando ? pessoaAtual['ponto_referencia'] : '');

    // Complementares
    final nisController = TextEditingController(text: editando ? pessoaAtual['nis'] : '');
    String? estadoCivil = editando ? pessoaAtual['estado_civil'] : null;
    String? tipoSang = editando ? pessoaAtual['tipo_sanguineo'] : null;
    final ocupacaoController = TextEditingController(text: editando ? pessoaAtual['ocupacao'] : '');
    String? escolaridade = editando ? pessoaAtual['escolaridade'] : null;

    // Perfis e Acesso
    Set<int> perfisSelecionados = editando ? (pessoaAtual['cad_pessoas_perfis'] as List).map<int>((item) => item['perfil_id'] as int).toSet() : {};
    bool temAcesso = editando && pessoaAtual['sys_usuarios'] != null;
    final senhaController = TextEditingController();
    int? grupoSelecionado = temAcesso ? pessoaAtual['sys_usuarios']['grupo_id'] : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {

            // Helper para campos limpos
            Widget campoTexto(String label, TextEditingController ctrl, {bool readOnly = false, List<TextInputFormatter>? masks, Widget? prefix, Widget? suffix}) {
              return TextField(
                controller: ctrl, readOnly: readOnly, inputFormatters: masks,
                decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: prefix, suffixIcon: suffix),
              );
            }

            // Mágica do CEP encapsulada no Serviço!
            Future<void> buscarCepLocal() async {
              setModalState(() => carregandoCep = true);
              final resultado = await ServicoCep.buscar(cepController.text);
              if (resultado != null) {
                setModalState(() {
                  logradouroController.text = resultado['logradouro']!;
                  bairroController.text = resultado['bairro']!;
                  municipioController.text = resultado['municipio']!;
                  ufController.text = resultado['uf']!;
                });
              } else if (maskCep.unmaskText(cepController.text).length == 8) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CEP não encontrado.'), backgroundColor: Colors.orange));
              }
              setModalState(() => carregandoCep = false);
            }

            Widget construirConteudoDireita() {
              if (abaAtiva == 0) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Identificação Principal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 50, backgroundColor: Colors.grey.shade200,
                                backgroundImage: fotoBase64 != null ? MemoryImage(base64Decode(fotoBase64!)) : null,
                                child: fotoBase64 == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.upload, size: 16), label: const Text('Alterar Foto'),
                                onPressed: () async {
                                  // Mágica da Foto encapsulada no Serviço!
                                  String? novaFoto = await ServicoImagem.capturarBase64();
                                  if (novaFoto != null) {
                                    setModalState(() => fotoBase64 = novaFoto);
                                  }
                                },
                              )
                            ],
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: campoTexto('CPF *', docController, masks: [maskCpf])),
                                    const SizedBox(width: 16),
                                    Expanded(child: campoTexto('Cartão SUS (CNS)', cnsController, masks: [maskCns])),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                campoTexto('Nome Completo *', nomeController),
                                const SizedBox(height: 16),
                                campoTexto('Nome Social', nomeSocialController),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dataNascController, readOnly: true,
                              decoration: const InputDecoration(labelText: 'Data de Nascimento', suffixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                              onTap: () async {
                                DateTime? pick = await showDatePicker(context: context, initialDate: dataNasc ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                                if (pick != null) { setModalState(() { dataNasc = pick; dataNascController.text = "${pick.day.toString().padLeft(2, '0')}/${pick.month.toString().padLeft(2, '0')}/${pick.year}"; }); }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sexoSelecionado, decoration: const InputDecoration(labelText: 'Sexo', border: OutlineInputBorder()),
                              items: ['Masculino', 'Feminino'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => sexoSelecionado = val),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: racaSelecionada, decoration: const InputDecoration(labelText: 'Raça / Cor', border: OutlineInputBorder()),
                              items: ['Branca', 'Preta', 'Amarela', 'Parda', 'Indígena'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => racaSelecionada = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      const Text('Filiação e Origem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Nome da Mãe', nomeMaeController, readOnly: maeDesconhecida)),
                          Checkbox(value: maeDesconhecida, onChanged: (v) => setModalState(() { maeDesconhecida = v!; if(v) nomeMaeController.clear(); })),
                          const Text('Desconhecida', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Nome do Pai', nomePaiController, readOnly: paiDesconhecido)),
                          Checkbox(value: paiDesconhecido, onChanged: (v) => setModalState(() { paiDesconhecido = v!; if(v) nomePaiController.clear(); })),
                          const Text('Desconhecido', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: nacionalidade, decoration: const InputDecoration(labelText: 'Naturalidade', border: OutlineInputBorder()),
                              items: ['Brasileira', 'Naturalizado', 'Estrangeiro'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() { nacionalidade = val!; munNascController.clear(); paisOrigemController.clear(); dataNatChegController.clear(); dataNatCheg = null; }),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (nacionalidade == 'Brasileira') Expanded(flex: 2, child: campoTexto('Município de Nascimento', munNascController)),
                          if (nacionalidade != 'Brasileira') ...[
                            Expanded(child: campoTexto('País de Origem', paisOrigemController)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: dataNatChegController, readOnly: true,
                                decoration: InputDecoration(labelText: nacionalidade == 'Naturalizado' ? 'Data de Naturalização' : 'Data de Chegada', suffixIcon: const Icon(Icons.calendar_today), border: const OutlineInputBorder()),
                                onTap: () async {
                                  DateTime? pick = await showDatePicker(context: context, initialDate: dataNatCheg ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                                  if (pick != null) { setModalState(() { dataNatCheg = pick; dataNatChegController.text = "${pick.day.toString().padLeft(2, '0')}/${pick.month.toString().padLeft(2, '0')}/${pick.year}"; }); }
                                },
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                );
              } 
              else if (abaAtiva == 1) { 
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
                              decoration: InputDecoration(
                                labelText: 'CEP', border: const OutlineInputBorder(),
                                suffixIcon: carregandoCep ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: buscarCepLocal)
                              ),
                              onSubmitted: (_) => buscarCepLocal(),
                            )
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('UF', ufController)),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: campoTexto('Município', municipioController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 2, child: campoTexto('Logradouro (Rua, Av...)', logradouroController)),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('Número', numeroController, readOnly: semNumero)),
                          Checkbox(value: semNumero, onChanged: (v) => setModalState(() { semNumero = v!; if(v) numeroController.clear(); })),
                          const Text('S/N', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Bairro', bairroController)),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('Complemento (Apto, Bloco)', complementoController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      campoTexto('Ponto de Referência', refController),
                      const SizedBox(height: 32),
                      const Text('Contatos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Telefone Principal', tel1Controller, prefix: const Icon(Icons.phone))),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('Telefone 2', tel2Controller)),
                          const SizedBox(width: 16),
                          Expanded(child: campoTexto('Telefone 3', tel3Controller)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      campoTexto('E-mail Principal', emailController, prefix: const Icon(Icons.email)),
                    ]
                  )
                );
              }
              else if (abaAtiva == 2) { 
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informações Complementares', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Nº NIS (PIS/PASEP)', nisController)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tipoSang, decoration: const InputDecoration(labelText: 'Tipo Sanguíneo', border: OutlineInputBorder()),
                              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => tipoSang = val),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: estadoCivil, decoration: const InputDecoration(labelText: 'Estado Civil', border: OutlineInputBorder()),
                              items: ['Solteiro(a)', 'Casado(a)', 'Divorciado(a)', 'Viúvo(a)', 'União Estável'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => estadoCivil = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: campoTexto('Ocupação Principal', ocupacaoController)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: escolaridade, decoration: const InputDecoration(labelText: 'Nível de Escolaridade', border: OutlineInputBorder()),
                              items: ['Analfabeto', 'Ens. Fundamental Incompleto', 'Ens. Fundamental Completo', 'Ens. Médio Incompleto', 'Ens. Médio Completo', 'Ens. Superior Incompleto', 'Ens. Superior Completo', 'Pós-graduação'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setModalState(() => escolaridade = val),
                            ),
                          ),
                        ],
                      )
                    ]
                  )
                );
              }
              else if (abaAtiva == 3) { 
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Perfis de Atuação no Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00447C))),
                      const Divider(), const SizedBox(height: 16),
                      const Text('Selecione quais são os papéis desta pessoa (afeta o modo como ela é listada noutras telas):'),
                      const SizedBox(height: 16),
                      _todosOsPerfisFisicos.isEmpty 
                        ? const Text('Nenhum perfil cadastrado.', style: TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 16, runSpacing: 16,
                            children: _todosOsPerfisFisicos.map((perfil) {
                              return FilterChip(
                                avatar: Icon(IconesSistema.traduzir(perfil['icone']), size: 18, color: const Color(0xFF00447C)),
                                label: Text(perfil['nome']),
                                selected: perfisSelecionados.contains(perfil['id']),
                                onSelected: (marcado) { setModalState(() { if (marcado) perfisSelecionados.add(perfil['id']); else perfisSelecionados.remove(perfil['id']); }); },
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
                      const Divider(), const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Permitir acesso ao sistema para esta pessoa?', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Isso criará um usuário vinculado ao CPF.'),
                        value: temAcesso, activeColor: const Color(0xFF00447C),
                        onChanged: (val) { setModalState(() => temAcesso = val); }
                      ),
                      if (temAcesso) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<int>(
                                value: grupoSelecionado, decoration: const InputDecoration(labelText: 'Grupo de Permissões', border: OutlineInputBorder()),
                                items: [ const DropdownMenuItem<int>(value: null, child: Text('Selecione um grupo...')), ..._grupos.map((g) => DropdownMenuItem<int>(value: g['id'], child: Text(g['nome']))) ],
                                onChanged: (valor) => setModalState(() => grupoSelecionado = valor),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: senhaController, obscureText: true,
                                decoration: InputDecoration(
                                  labelText: editando && pessoaAtual['sys_usuarios'] != null ? 'Redefinir Senha (Deixe em branco para manter a atual)' : 'Senha de Acesso Inicial', 
                                  border: const OutlineInputBorder(), helperText: 'A senha será marcada como "temporária" e forçará a troca no primeiro login.'
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
                width: 1000, height: 700,
                child: Row(
                  children: [
                    Container(
                      width: 260,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)), border: Border(right: BorderSide(color: Colors.grey.shade300))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.all(24.0), child: Text('Cadastro Pessoa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00447C)))),
                          ListTile(
                            leading: Icon(Icons.person, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.grey), title: Text('Dados Pessoais', style: TextStyle(fontWeight: abaAtiva == 0 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 0 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 0, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 0),
                          ),
                          ListTile(
                            leading: Icon(Icons.location_on, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.grey), title: Text('Endereço e Contato', style: TextStyle(fontWeight: abaAtiva == 1 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 1 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 1, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 1),
                          ),
                          ListTile(
                            leading: Icon(Icons.library_books, color: abaAtiva == 2 ? const Color(0xFF00447C) : Colors.grey), title: Text('Complementares', style: TextStyle(fontWeight: abaAtiva == 2 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 2 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 2, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 2),
                          ),
                          ListTile(
                            leading: Icon(Icons.local_offer, color: abaAtiva == 3 ? const Color(0xFF00447C) : Colors.grey), title: Text('Perfis de Atuação', style: TextStyle(fontWeight: abaAtiva == 3 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 3 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 3, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 3),
                          ),
                          ListTile(
                            leading: Icon(Icons.security, color: abaAtiva == 4 ? const Color(0xFF00447C) : Colors.grey), title: Text('Acesso ao Sistema', style: TextStyle(fontWeight: abaAtiva == 4 ? FontWeight.bold : FontWeight.normal, color: abaAtiva == 4 ? const Color(0xFF00447C) : Colors.black87)),
                            selected: abaAtiva == 4, selectedTileColor: Colors.blue.withOpacity(0.1), onTap: () => setModalState(() => abaAtiva = 4),
                          ),
                          const Spacer(), const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(width: double.infinity, child: TextButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('Cancelar', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context))),
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
                                icon: const Icon(Icons.save), label: const Text('Salvar Cadastro', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  String docLimpo = maskCpf.unmaskText(docController.text);
                                  if (nomeController.text.isEmpty || docLimpo.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e CPF são obrigatórios.'), backgroundColor: Colors.red));
                                    return;
                                  }

                                  try {
                                    int pessoaId;
                                    final Map<String, dynamic> dadosPessoa = {
                                      'tipo_pessoa': 'F',
                                      'foto_base64': fotoBase64,
                                      'documento': docLimpo,
                                      'cns': maskCns.unmaskText(cnsController.text),
                                      'nome': nomeController.text,
                                      'nome_social': nomeSocialController.text,
                                      'data_nascimento': dataNasc != null ? "${dataNasc!.year}-${dataNasc!.month.toString().padLeft(2, '0')}-${dataNasc!.day.toString().padLeft(2, '0')}" : null,
                                      'sexo': sexoSelecionado,
                                      'raca_cor': racaSelecionada,
                                      'mae_desconhecida': maeDesconhecida, 'nome_mae': maeDesconhecida ? null : nomeMaeController.text,
                                      'pai_desconhecido': paiDesconhecido, 'nome_pai': paiDesconhecido ? null : nomePaiController.text,
                                      'nacionalidade': nacionalidade,
                                      'municipio_nascimento': nacionalidade == 'Brasileira' ? munNascController.text : null,
                                      'pais_origem': nacionalidade != 'Brasileira' ? paisOrigemController.text : null,
                                      'data_naturalizacao': nacionalidade == 'Naturalizado' && dataNatCheg != null ? "${dataNatCheg!.year}-${dataNatCheg!.month.toString().padLeft(2, '0')}-${dataNatCheg!.day.toString().padLeft(2, '0')}" : null,
                                      'data_chegada': nacionalidade == 'Estrangeiro' && dataNatCheg != null ? "${dataNatCheg!.year}-${dataNatCheg!.month.toString().padLeft(2, '0')}-${dataNatCheg!.day.toString().padLeft(2, '0')}" : null,
                                      'telefone': tel1Controller.text, 'telefone_2': tel2Controller.text, 'telefone_3': tel3Controller.text, 'email': emailController.text,
                                      'cep': maskCep.unmaskText(cepController.text), 'uf': ufController.text, 'municipio': municipioController.text, 'bairro': bairroController.text,
                                      'logradouro': logradouroController.text, 'sem_numero': semNumero, 'numero': semNumero ? null : numeroController.text,
                                      'complemento': complementoController.text, 'ponto_referencia': refController.text,
                                      'nis': nisController.text, 'estado_civil': estadoCivil, 'tipo_sanguineo': tipoSang, 'ocupacao': ocupacaoController.text, 'escolaridade': escolaridade,
                                    };

                                    if (editando) {
                                      await _supabase.from('cad_pessoas').update(dadosPessoa).eq('id', pessoaAtual['id']);
                                      pessoaId = pessoaAtual['id'];
                                      await _supabase.from('cad_pessoas_perfis').delete().eq('pessoa_id', pessoaId);
                                    } else {
                                      final insert = await _supabase.from('cad_pessoas').insert(dadosPessoa).select();
                                      pessoaId = insert[0]['id'];
                                    }

                                    if (perfisSelecionados.isNotEmpty) {
                                      List<Map<String, dynamic>> listaPerfisSalvar = perfisSelecionados.map((id) => {'pessoa_id': pessoaId, 'perfil_id': id}).toList();
                                      await _supabase.from('cad_pessoas_perfis').insert(listaPerfisSalvar);
                                    }

                                    if (temAcesso) {
                                      final Map<String, dynamic> dadosUsuario = { 'pessoa_id': pessoaId, 'grupo_id': grupoSelecionado };
                                      if (senhaController.text.isNotEmpty) { dadosUsuario['senha'] = senhaController.text; dadosUsuario['senha_temporaria'] = true; }
                                      final checkUser = await _supabase.from('sys_usuarios').select('id').eq('pessoa_id', pessoaId).maybeSingle();
                                      if (checkUser != null) { await _supabase.from('sys_usuarios').update(dadosUsuario).eq('id', checkUser['id']); } 
                                      else {
                                        if (senhaController.text.isEmpty) throw Exception('Digite uma senha inicial.');
                                        await _supabase.from('sys_usuarios').insert(dadosUsuario);
                                      }
                                    } else {
                                      await _supabase.from('sys_usuarios').delete().eq('pessoa_id', pessoaId);
                                    }

                                    if (mounted) Navigator.pop(context);
                                    _buscarDados();
                                  } catch (e) {
                                    debugPrint('Erro ao salvar: $e');
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar. Verifique se o CPF já existe.'), backgroundColor: Colors.red));
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
        onPressed: () => _mostrarFormulario(), icon: const Icon(Icons.person_add), label: const Text('Nova Pessoa Física'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(hintText: 'Buscar por Nome ou CPF...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                    onChanged: (value) => _aplicarFiltros(), 
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _todosOsPerfisFisicos.map((perfil) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: Icon(IconesSistema.traduzir(perfil['icone']), size: 18, color: const Color(0xFF00447C)), label: Text(perfil['nome']),
                            selected: _filtrosDePerfilAtivos.contains(perfil['id']),
                            onSelected: (marcado) { setState(() { if (marcado) _filtrosDePerfilAtivos.add(perfil['id']); else _filtrosDePerfilAtivos.remove(perfil['id']); }); _aplicarFiltros(); },
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
                    DataColumn(label: Text('Foto')),
                    DataColumn(label: Text('Nome Completo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CPF', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Perfis', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _pessoasFiltradas.map((pessoa) { 
                    List<int> idsDessaPessoa = (pessoa['cad_pessoas_perfis'] as List).map<int>((i) => i['perfil_id'] as int).toList();
                    var perfisDessaPessoa = _todosOsPerfisFisicos.where((p) => idsDessaPessoa.contains(p['id'])).toList();

                    return DataRow(
                      cells: [
                        DataCell(CircleAvatar(radius: 18, backgroundColor: Colors.grey.shade300, backgroundImage: pessoa['foto_base64'] != null ? MemoryImage(base64Decode(pessoa['foto_base64'])) : null, child: pessoa['foto_base64'] == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null)),
                        DataCell(Text(pessoa['nome'])),
                        DataCell(Text(MaskTextInputFormatter(mask: '###.###.###-##').maskText(pessoa['documento']))),
                        DataCell(
                          Wrap(spacing: 4, children: perfisDessaPessoa.map((p) => Chip(avatar: Icon(IconesSistema.traduzir(p['icone']), size: 14), label: Text(p['nome'], style: const TextStyle(fontSize: 10)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)).toList())
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