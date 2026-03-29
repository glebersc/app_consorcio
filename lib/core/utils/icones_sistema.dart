import 'package:flutter/material.dart';

// Este é o seu Banco Central de Ícones.
// Achou um ícone legal no fonts.google.com/icons? É só colocar o nome dele aqui!
class IconesSistema {
  static final Map<String, IconData> catalogo = {
    // 🏠 Básicos / Interface
    'home': Icons.home,
    'dashboard': Icons.dashboard,
    'settings': Icons.settings,
    'search': Icons.search,
    'info': Icons.info,
    'help': Icons.help,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'build': Icons.build,
    
    // 📁 Arquivos e Pastas
    'folder': Icons.folder,
    'folder_open': Icons.folder_open,
    'article': Icons.article,
    'description': Icons.description,
    'picture_as_pdf': Icons.picture_as_pdf,
    'assignment': Icons.assignment,
    'inventory': Icons.inventory,
    'list_alt': Icons.list_alt,

    // 🏢 Negócios / ERP
    'business': Icons.business,
    'store': Icons.store,
    'shopping_cart': Icons.shopping_cart,
    'local_shipping': Icons.local_shipping,
    'receipt': Icons.receipt,
    'analytics': Icons.analytics,
    'trending_up': Icons.trending_up,
    'work': Icons.work,
    'event': Icons.event,

    // 💰 Finanças
    'attach_money': Icons.attach_money,
    'monetization_on': Icons.monetization_on,
    'account_balance': Icons.account_balance,
    'credit_card': Icons.credit_card,
    'point_of_sale': Icons.point_of_sale,

    // 👥 Pessoas / Usuários
    'person': Icons.person,
    'people': Icons.people,
    'groups': Icons.groups,
    'badge': Icons.badge,
    'account_circle': Icons.account_circle,
    'manage_accounts': Icons.manage_accounts,
    'handshake': Icons.handshake,

    // 🏥 Saúde / Clínica (Adicionei pois vi 'SIGTAP' no seu print)
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'healing': Icons.healing,
    'vaccines': Icons.vaccines,
    'bloodtype': Icons.bloodtype,
    'monitor_heart': Icons.monitor_heart,
    'science': Icons.science,
    'psychology': Icons.psychology,

    // 💻 Tecnologia
    'computer': Icons.computer,
    'smartphone': Icons.smartphone,
    'print': Icons.print,
    'cloud': Icons.cloud,
    'security': Icons.security,
  };

  // Função que o sistema vai usar para converter a palavra no desenho
  static IconData traduzir(String? nomeIcone) {
    if (nomeIcone == null) return Icons.circle; // Ícone padrão se vier vazio
    return catalogo[nomeIcone] ?? Icons.circle;
  }
}