// =============================================================================
// endereco.dart - MODELO DE ENDERECO (somente leitura)
// =============================================================================
//
// CONCEITO - "model": classe simples que representa um dado da API. Os models
// ficam em `lib/modelos_da_api/` e espelham os DTOs (objetos de transferencia) do
// back-end. Cada um tem `fromJson` (JSON -> objeto) e, quando ha envio,
// `toJson` (objeto -> JSON). Sao escritos a mao, sem geracao de codigo.
// =============================================================================

// Para montar o texto do endereco em uma linha (`Fmt.enderecoLinha`).
import '../infraestrutura/formatters.dart';

/// Espelha `Endereco.kt` (`@Embeddable`).
///
/// O cliente **nunca** monta um endereco: ele envia apenas `cep` e `numero`, e o
/// back-end preenche logradouro/bairro/cidade/uf consultando o ViaCEP antes de
/// salvar. Por isso esta classe so e lida, nunca enviada.
class Endereco {
  /// `const` + todos os campos `final` => objeto imutavel (nao muda depois de
  /// criado), o que evita bugs de estado compartilhado.
  const Endereco({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.numero,
  });

  /// CEP do local (ex.: "85601-000").
  final String cep;

  /// Rua/avenida (preenchido pelo ViaCEP).
  final String logradouro;

  /// Bairro.
  final String bairro;

  /// Cidade.
  final String cidade;

  /// Sigla do estado (ex.: "PR").
  final String uf;

  /// Numero do imovel; opcional (`?` = pode ser nulo).
  final String? numero;

  /// Constroi a partir do JSON da API.
  /// `(json['cep'] ?? '').toString()` => se a chave faltar/for nula, usa vazio.
  /// `as String?` faz a "conversao de tipo" (cast) para texto anulavel.
  factory Endereco.fromJson(Map<String, dynamic> json) => Endereco(
    cep: (json['cep'] ?? '').toString(),
    logradouro: (json['logradouro'] ?? '').toString(),
    bairro: (json['bairro'] ?? '').toString(),
    cidade: (json['cidade'] ?? '').toString(),
    uf: (json['uf'] ?? '').toString(),
    numero: json['numero'] as String?,
  );

  /// "Avenida Julio Assis Cavalheiro, 02 · Centro · Francisco Beltrao - PR"
  /// (getter: usado como propriedade, `endereco.linha`).
  String get linha => Fmt.enderecoLinha(
    logradouro: logradouro,
    numero: numero,
    bairro: bairro,
    cidade: cidade,
    uf: uf,
  );

  /// "Francisco Beltrao - PR", para listagens compactas.
  /// Sem UF, mostra so a cidade. `'$cidade - $uf'` junta os dois com interpolacao.
  String get cidadeUf => uf.isEmpty ? cidade : '$cidade - $uf';
}
