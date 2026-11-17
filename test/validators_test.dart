// =============================================================================
// validators_test.dart - TESTES UNITARIOS DAS VALIDACOES (core/validators.dart)
// =============================================================================
//
// CONCEITO - teste unitario: codigo que chama uma funcao com entradas
// conhecidas e CONFERE a saida esperada. Se a saida for diferente, o teste
// falha. Aqui nao ha tela nem rede: so funcoes puras.
//
// Vocabulario do pacote de testes:
//   * `group(nome, () {...})`  agrupa testes relacionados (organiza o relatorio)
//   * `test(nome, () {...})`   um caso de teste
//   * `expect(real, esperado)` falha se `real` nao casar com `esperado`
//   * matchers: `isTrue`, `isFalse`, `isNull` (e um valor comum = igualdade)
//   * `reason:` mensagem extra mostrada quando o `expect` falha
// =============================================================================

// Import com `package:acontece_frontend/...` = codigo do proprio app (o nome do
// pacote vem do pubspec.yaml).
import 'package:acontece_frontend/core/validators.dart';
// Biblioteca de testes do Flutter: group, test, expect, matchers.
import 'package:flutter_test/flutter_test.dart';

/// Ponto de entrada: o executor de testes chama `main()` e registra os grupos.
void main() {
  group('CPF', () {
    test('aceita CPF valido com e sem pontuacao', () {
      // CPF de teste com digitos verificadores corretos.
      expect(Validators.isCpfValid('529.982.247-25'), isTrue);
      expect(Validators.isCpfValid('52998224725'), isTrue);
      // `isNull`: o validador devolve null quando NAO ha erro.
      expect(Validators.cpf('529.982.247-25'), isNull);
    });

    test('recusa digito verificador errado', () {
      expect(Validators.isCpfValid('529.982.247-26'), isFalse);
      // Aqui o valor esperado e a mensagem de erro exata.
      expect(Validators.cpf('52998224726'), 'CPF inválido');
    });

    test('recusa sequencia de digito repetido, como o @CPF do back-end', () {
      // Laco: repete a mesma verificacao para varias entradas.
      for (final repetido in ['00000000000', '11111111111', '99999999999']) {
        // `reason` mostra qual entrada falhou, se falhar.
        expect(Validators.isCpfValid(repetido), isFalse, reason: repetido);
      }
    });

    test('recusa quantidade de digitos diferente de 11', () {
      // 10 digitos (curto) e 12 digitos (longo).
      expect(Validators.isCpfValid('1234567890'), isFalse);
      expect(Validators.isCpfValid('123456789012'), isFalse);
      expect(Validators.cpf(''), 'O CPF é obrigatório');
    });
  });

  group('CEP', () {
    test('aceita os dois formatos que o @Pattern do back-end permite', () {
      // Com e sem hifen.
      expect(Validators.cep('85601000'), isNull);
      expect(Validators.cep('85601-000'), isNull);
    });

    test('recusa tamanho errado e letras', () {
      expect(Validators.cep('8560100'), 'CEP deve ter 8 dígitos');
      expect(Validators.cep('8560-1000'), 'CEP deve ter 8 dígitos');
      expect(Validators.cep('abcde-fgh'), 'CEP deve ter 8 dígitos');
      expect(Validators.cep(''), 'O CEP é obrigatório');
    });
  });

  group('telefone', () {
    test('e opcional', () {
      // Vazio e nulo sao validos (campo opcional).
      expect(Validators.telefone(''), isNull);
      expect(Validators.telefone(null), isNull);
    });

    test('aceita 10 e 11 digitos', () {
      expect(Validators.telefone('4699887766'), isNull);
      expect(Validators.telefone('46999887766'), isNull);
    });

    test('recusa fora da faixa de 10 a 11 digitos', () {
      // 9 digitos (curto demais).
      expect(
        Validators.telefone('469988776'),
        'O telefone deve ter 10 ou 11 dígitos',
      );
      // 12 digitos (longo demais).
      expect(
        Validators.telefone('469998877669'),
        'O telefone deve ter 10 ou 11 dígitos',
      );
    });
  });

  group('titulo e vagas do evento', () {
    test('titulo e obrigatorio e tem limite de 100', () {
      expect(Validators.tituloEvento(''), 'O título do evento é obrigatório');
      // So espacos tambem conta como vazio (por causa do `trim`).
      expect(
        Validators.tituloEvento('   '),
        'O título do evento é obrigatório',
      );
      // `'a' * 100` repete o texto 100 vezes (limite exato: aceita).
      expect(Validators.tituloEvento('a' * 100), isNull);
      // 101 caracteres: passa do limite.
      expect(Validators.tituloEvento('a' * 101), 'No máximo 100 caracteres');
    });

    test('vagas precisa ser inteiro maior que zero', () {
      expect(Validators.vagas('1'), isNull);
      expect(Validators.vagas('200'), isNull);
      // Zero e negativo: recusados (precisa ser maior que zero).
      expect(Validators.vagas('0'), 'Vagas deve ser maior que zero');
      expect(Validators.vagas('-5'), 'Vagas deve ser maior que zero');
      // Decimal com virgula nao e inteiro.
      expect(Validators.vagas('3,5'), 'Use apenas números inteiros');
      expect(Validators.vagas(''), 'Informe a quantidade de vagas');
    });
  });

  group('periodo do evento', () {
    test('fim precisa ser estritamente depois do inicio', () {
      // DateTime(ano, mes, dia, hora): 4/dez/2026 as 17h.
      final inicio = DateTime(2026, 12, 4, 17);
      expect(
        Validators.periodoEvento(inicio, inicio.add(const Duration(hours: 2))),
        isNull,
      );
      // Igual nao passa: o back-end usa `dataFim.isAfter(dataInicio)`.
      expect(
        Validators.periodoEvento(inicio, inicio),
        'A data de fim deve ser posterior à data de início',
      );
      // Fim ANTES do inicio tambem e recusado.
      expect(
        Validators.periodoEvento(
          inicio,
          inicio.subtract(const Duration(days: 1)),
        ),
        'A data de fim deve ser posterior à data de início',
      );
    });
  });

  group('e-mail', () {
    test('aceita enderecos comuns', () {
      expect(Validators.email('maria.silva@exemplo.com.br'), isNull);
      // O `+` e permitido na parte local do e-mail.
      expect(Validators.email('a+b@dominio.io'), isNull);
    });

    test('recusa invalidos', () {
      // Sem `@`, sem ponto no dominio e vazio.
      expect(Validators.email('sem-arroba'), 'E-mail inválido');
      expect(Validators.email('sem@dominio'), 'E-mail inválido');
      expect(Validators.email(''), 'O e-mail é obrigatório');
    });
  });

  group('senha', () {
    test('exige entre 8 e 72 caracteres, como o ParticipanteRequest', () {
      expect(Validators.senha(''), 'A senha é obrigatória');
      // 7 caracteres: curta demais.
      expect(
        Validators.senha('1234567'),
        'A senha deve ter entre 8 e 72 caracteres',
      );
      // 73 caracteres: longa demais (BCrypt so le 72 bytes).
      expect(
        Validators.senha('a' * 73),
        'A senha deve ter entre 8 e 72 caracteres',
      );
      // Limites exatos sao aceitos.
      expect(Validators.senha('12345678'), isNull);
      expect(Validators.senha('a' * 72), isNull);
    });
  });
}
