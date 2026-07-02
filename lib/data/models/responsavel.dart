import 'package:flutter/material.dart';

class Responsavel {
  final String nome;
  final String iniciais;
  final Color cor;

  const Responsavel({
    required this.nome,
    required this.iniciais,
    required this.cor,
  });

  static const todos = [
    Responsavel(nome: 'Tatiane', iniciais: 'TA', cor: Color(0xFF7C3AED)),
    Responsavel(nome: 'Bryan', iniciais: 'BR', cor: Color(0xFF0891B2)),
    Responsavel(nome: 'Juliana', iniciais: 'JU', cor: Color(0xFFDB2777)),
    Responsavel(nome: 'Marcos Silva', iniciais: 'MS', cor: Color(0xFFEA580C)),
    Responsavel(nome: 'Patrícia Lima', iniciais: 'PL', cor: Color(0xFF0D9488)),
  ];

  static Responsavel? byNome(String nome) {
    for (final r in todos) {
      if (r.nome == nome) return r;
    }
    return null;
  }
}
