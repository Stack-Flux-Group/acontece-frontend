import '../core/formatters.dart';

/// Espelha `Endereco.kt` (`@Embeddable`).
///
/// O cliente **nunca** monta um endereco: ele envia apenas `cep` e `numero`, e o
/// back-end preenche logradouro/bairro/cidade/uf consultando o ViaCEP antes de
/// salvar. Por isso esta classe so e lida, nunca enviada.
class Endereco {
  const Endereco({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.numero,
  });

  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
  final String? numero;

  factory Endereco.fromJson(Map<String, dynamic> json) => Endereco(
    cep: (json['cep'] ?? '').toString(),
    logradouro: (json['logradouro'] ?? '').toString(),
    bairro: (json['bairro'] ?? '').toString(),
    cidade: (json['cidade'] ?? '').toString(),
    uf: (json['uf'] ?? '').toString(),
    numero: json['numero'] as String?,
  );

  /// "Avenida Julio Assis Cavalheiro, 02 · Centro · Francisco Beltrao - PR"
  String get linha => Fmt.enderecoLinha(
    logradouro: logradouro,
    numero: numero,
    bairro: bairro,
    cidade: cidade,
    uf: uf,
  );

  /// "Francisco Beltrao - PR", para listagens compactas.
  String get cidadeUf => uf.isEmpty ? cidade : '$cidade - $uf';
}
