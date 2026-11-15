import 'package:acontece_frontend/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CPF', () {
    test('aceita CPF valido com e sem pontuacao', () {
      // CPF de teste com digitos verificadores corretos.
      expect(Validators.isCpfValid('529.982.247-25'), isTrue);
      expect(Validators.isCpfValid('52998224725'), isTrue);
      expect(Validators.cpf('529.982.247-25'), isNull);
    });

    test('recusa digito verificador errado', () {
      expect(Validators.isCpfValid('529.982.247-26'), isFalse);
      expect(Validators.cpf('52998224726'), 'CPF inválido');
    });

    test('recusa sequencia de digito repetido, como o @CPF do back-end', () {
      for (final repetido in ['00000000000', '11111111111', '99999999999']) {
        expect(Validators.isCpfValid(repetido), isFalse, reason: repetido);
      }
    });

    test('recusa quantidade de digitos diferente de 11', () {
      expect(Validators.isCpfValid('1234567890'), isFalse);
      expect(Validators.isCpfValid('123456789012'), isFalse);
      expect(Validators.cpf(''), 'O CPF é obrigatório');
    });
  });

  group('CEP', () {
    test('aceita os dois formatos que o @Pattern do back-end permite', () {
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
      expect(Validators.telefone(''), isNull);
      expect(Validators.telefone(null), isNull);
    });

    test('aceita 10 e 11 digitos', () {
      expect(Validators.telefone('4699887766'), isNull);
      expect(Validators.telefone('46999887766'), isNull);
    });

    test('recusa fora da faixa de 10 a 11 digitos', () {
      expect(
        Validators.telefone('469988776'),
        'O telefone deve ter 10 ou 11 dígitos',
      );
      expect(
        Validators.telefone('469998877669'),
        'O telefone deve ter 10 ou 11 dígitos',
      );
    });
  });

  group('titulo e vagas do evento', () {
    test('titulo e obrigatorio e tem limite de 100', () {
      expect(Validators.tituloEvento(''), 'O título do evento é obrigatório');
      expect(
        Validators.tituloEvento('   '),
        'O título do evento é obrigatório',
      );
      expect(Validators.tituloEvento('a' * 100), isNull);
      expect(Validators.tituloEvento('a' * 101), 'No máximo 100 caracteres');
    });

    test('vagas precisa ser inteiro maior que zero', () {
      expect(Validators.vagas('1'), isNull);
      expect(Validators.vagas('200'), isNull);
      expect(Validators.vagas('0'), 'Vagas deve ser maior que zero');
      expect(Validators.vagas('-5'), 'Vagas deve ser maior que zero');
      expect(Validators.vagas('3,5'), 'Use apenas números inteiros');
      expect(Validators.vagas(''), 'Informe a quantidade de vagas');
    });
  });

  group('periodo do evento', () {
    test('fim precisa ser estritamente depois do inicio', () {
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
      expect(Validators.email('a+b@dominio.io'), isNull);
    });

    test('recusa invalidos', () {
      expect(Validators.email('sem-arroba'), 'E-mail inválido');
      expect(Validators.email('sem@dominio'), 'E-mail inválido');
      expect(Validators.email(''), 'O e-mail é obrigatório');
    });
  });

  group('senha', () {
    test('exige entre 8 e 72 caracteres, como o ParticipanteRequest', () {
      expect(Validators.senha(''), 'A senha é obrigatória');
      expect(
        Validators.senha('1234567'),
        'A senha deve ter entre 8 e 72 caracteres',
      );
      expect(
        Validators.senha('a' * 73),
        'A senha deve ter entre 8 e 72 caracteres',
      );
      expect(Validators.senha('12345678'), isNull);
      expect(Validators.senha('a' * 72), isNull);
    });
  });
}
