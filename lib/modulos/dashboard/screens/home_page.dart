import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart'; // Escudo anti-iframe

import '../../configuracoes/screens/tela_gerenciar_menus.dart';
import '../../../core/utils/icones_sistema.dart'; 
import '../../../shared/widgets/web_view_embutido.dart';
import '../../configuracoes/screens/tela_grupos_permissoes.dart';
import '../../cadastros/screens/tela_usuarios.dart';
import '../../../core/utils/sessao_usuario.dart';
import '../../auth/screens/tela_login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color corPrincipal = const Color(0xFF00447C);
  final Color corFundo = const Color(0xFFF5F6F8);

  // Controle de Abas
  List<Map<String, String>> abasAbertas = [
    {'titulo': 'Área de Trabalho', 'rota': 'tela_dashboard'}
  ];
  String rotaAtiva = 'tela_dashboard';
  String tituloAtivo = 'Área de Trabalho'; 

  // Controle de Menus do Banco
  List<dynamic> _menusDoBanco = [];
  bool _carregandoMenus = true;

  @override
  void initState() {
    super.initState();
    _buscarMenusNoBanco();
  }

  Future<void> _buscarMenusNoBanco() async {
    try {
      final supabase = Supabase.instance.client;
      final grupoId = SessaoUsuario().grupoId;

      if (grupoId == null) return; // Se por acaso não tiver grupo, para aqui

      // 1. Busca TODOS os menus ordenados
      final todosMenus = await supabase.from('sys_menus').select().order('ordem', ascending: true);
      
      // 2. Busca as permissões EXATAS deste grupo
      final permissoes = await supabase.from('sys_permissoes').select('menu_id').eq('grupo_id', grupoId);
      
      // 3. Cria uma lista apenas com os IDs que ele pode ver
      final idsPermitidos = permissoes.map((p) => p['menu_id'] as int).toSet();

      // 4. Filtra a lista de menus original para manter só o que tem permissão
      final menusFiltrados = todosMenus.where((menu) => idsPermitidos.contains(menu['id'])).toList();

      setState(() {
        _menusDoBanco = menusFiltrados; // 🌟 AGORA A TELA SÓ DESENHA O QUE FOI FILTRADO!
        _carregandoMenus = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar menus: $e');
      setState(() => _carregandoMenus = false);
    }
  }

  void _mudarTela(String tituloDaTela, String? rota, String? tipoAcao, bool isWeb) async {
    Navigator.pop(context); // Fecha o menu lateral
    if (rota == null || rota.isEmpty) return; 

    // Se for link externo, abre o navegador e ignora o resto
    if (tipoAcao == 'link_externo') {
      final url = Uri.parse(rota);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return; 
    }

    // Se for link interno, adiciona o prefixo 'iframe|' na rota
    String rotaParaAbrir = tipoAcao == 'link_interno' ? 'iframe|$rota' : rota;

    setState(() {
      if (isWeb) {
        bool jaAberta = abasAbertas.any((aba) => aba['rota'] == rotaParaAbrir);
        if (!jaAberta) {
          abasAbertas.add({'titulo': tituloDaTela, 'rota': rotaParaAbrir});
        }
      } else {
        // No celular (que não tem barra de abas), limpamos para não estourar memória
        abasAbertas.clear();
        abasAbertas.add({'titulo': 'Área de Trabalho', 'rota': 'tela_dashboard'});
        if (rotaParaAbrir != 'tela_dashboard') {
          abasAbertas.add({'titulo': tituloDaTela, 'rota': rotaParaAbrir});
        }
      }
      rotaAtiva = rotaParaAbrir;
      tituloAtivo = tituloDaTela;
    });
  }

  void _fecharAba(String rotaParaFechar) {
    setState(() {
      abasAbertas.removeWhere((aba) => aba['rota'] == rotaParaFechar);
      if (rotaAtiva == rotaParaFechar) {
        rotaAtiva = 'tela_dashboard';
        tituloAtivo = 'Área de Trabalho';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWeb = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: corFundo,
          appBar: AppBar(
            backgroundColor: corPrincipal,
            foregroundColor: Colors.white,
            title: Text(
              isWeb || rotaAtiva == 'tela_dashboard' ? 'Demo 1CÓDIGO' : 'Demo 1CÓDIGO > $tituloAtivo', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // 🌟 MOSTRA O NOME DO USUÁRIO E O BOTÃO DE SAIR 🌟
              Center(child: Text('Olá, ${SessaoUsuario().nome}', style: const TextStyle(fontSize: 14))),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Sair do Sistema',
                onPressed: () {
                  SessaoUsuario().deslogar();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaLogin()));
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: Drawer(
            // 🌟 ESCUDO ANTI-IFRAME APLICADO AQUI 🌟
            child: PointerInterceptor(
              child: _buildMenuLateralDinamico(isWeb), 
            ),
          ),
          body: Column(
            children: [
              if (isWeb) _buildBarraDeAbas(),
              Expanded(
                child: _buildConteudoDaTela(), 
              )
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 🌟 NOVO ROTEADOR COM MEMÓRIA (IndexedStack)
  // ==========================================
  Widget _buildConteudoDaTela() {
    int indiceAtivo = abasAbertas.indexWhere((aba) => aba['rota'] == rotaAtiva);
    if (indiceAtivo == -1) indiceAtivo = 0; 

    return IndexedStack(
      index: indiceAtivo,
      children: abasAbertas.map((aba) {
        return KeyedSubtree(
          key: ValueKey(aba['rota']), 
          child: _obterTelaPorRota(aba['rota']!),
        );
      }).toList(),
    );
  }

  Widget _obterTelaPorRota(String rota) {
    if (rota.startsWith('iframe|')) {
      final urlDoLink = rota.replaceAll('iframe|', '');
      return WebViewEmbutido(url: urlDoLink);
    }

    switch (rota) {
      case 'tela_dashboard':
        return const Center(child: Text('Área de Trabalho Principal', style: TextStyle(fontSize: 18)));
      case 'tela_configuracoes': 
        return const TelaGerenciarMenus();
      case 'tela_grupos_permissoes': 
        return const TelaGruposPermissoes();
      case 'tela_usuarios': 
        return const TelaUsuarios();
      default:
        return Center(
          child: Text('Arquivo da tela ainda não criado para a rota:\n$rota', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54)),
        );
    }
  }

  Widget _buildBarraDeAbas() {
    return Container(
      height: 50,
      color: Colors.white,
      width: double.infinity,
      child: Row(
        children: abasAbertas.map((aba) {
          String nome = aba['titulo']!;
          String rota = aba['rota']!;
          bool isAtiva = rota == rotaAtiva;

          return GestureDetector(
            onTap: () => setState(() {
              rotaAtiva = rota;
              tituloAtivo = nome;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAtiva ? corPrincipal : Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(nome, style: TextStyle(color: isAtiva ? Colors.white : Colors.black87, fontWeight: isAtiva ? FontWeight.bold : FontWeight.normal)),
                  if (rota != 'tela_dashboard') ...[
                    const SizedBox(width: 10),
                    InkWell(onTap: () => _fecharAba(rota), child: Icon(Icons.close, size: 16, color: isAtiva ? Colors.white70 : Colors.grey)),
                  ]
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuLateralDinamico(bool isWeb) {
    if (_carregandoMenus) return const Center(child: CircularProgressIndicator());

    List<Widget> itensDoMenu = [];
    itensDoMenu.add(
      Container(
        height: 60,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        child: Text('Demo 1CÓDIGO', style: TextStyle(color: corPrincipal, fontSize: 20, fontWeight: FontWeight.bold)),
      )
    );
    itensDoMenu.add(Divider(height: 1, color: Colors.grey.shade200));

    var menusPrincipais = _menusDoBanco.where((menu) => menu['parent_id'] == null).toList();

    for (var menu in menusPrincipais) {
      var submenus = _menusDoBanco.where((m) => m['parent_id'] == menu['id']).toList();

      if (menu['rota_tela'] == 'tela_dashboard' && isWeb) continue; 

      if (submenus.isEmpty) {
        itensDoMenu.add(
          ListTile(
            leading: Icon(IconesSistema.traduzir(menu['icone']), color: corPrincipal),
            title: Text(menu['titulo'], style: menu['rota_tela'] == 'tela_dashboard' ? const TextStyle(fontWeight: FontWeight.bold) : null),
            onTap: () => _mudarTela(menu['titulo'], menu['rota_tela'], menu['tipo_acao'], isWeb),
          )
        );
      } else {
        List<Widget> subItensWidget = [];
        for (var sub in submenus) {
          subItensWidget.add(
            ListTile(
              contentPadding: const EdgeInsets.only(left: 54, right: 16),
              leading: Icon(IconesSistema.traduzir(sub['icone']), color: corPrincipal, size: 20),
              title: Text(sub['titulo']),
              onTap: () => _mudarTela(sub['titulo'], sub['rota_tela'], sub['tipo_acao'], isWeb),
            )
          );
        }

        itensDoMenu.add(
          ExpansionTile(
            leading: Icon(IconesSistema.traduzir(menu['icone']), color: corPrincipal),
            title: Text(menu['titulo']),
            children: subItensWidget,
          )
        );
      }
    }

    // 🌟 ALINHAMENTO CORRIGIDO AQUI 🌟
    return Container(
      alignment: Alignment.topCenter, 
      child: ListView(
        padding: EdgeInsets.zero, 
        children: itensDoMenu,
      ),
    );
  }
}