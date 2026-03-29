class SessaoUsuario {
  // Padrão Singleton para manter a mesma instância viva no app todo
  static final SessaoUsuario _instancia = SessaoUsuario._interno();
  factory SessaoUsuario() => _instancia;
  SessaoUsuario._interno();

  // Guarda os dados do usuário logado (id, nome, email, grupo_id, etc)
  Map<String, dynamic>? usuarioAtual;

  bool get estaLogado => usuarioAtual != null;
  int? get grupoId => usuarioAtual?['grupo_id'];
  String get nome => usuarioAtual?['nome_completo'] ?? 'Usuário';

  void deslogar() {
    usuarioAtual = null;
  }
}