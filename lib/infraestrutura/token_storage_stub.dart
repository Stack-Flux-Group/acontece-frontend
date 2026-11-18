// Versao "stub" do armazenamento: escolhida pelo import condicional de
// token_storage.dart quando NAO se compila para o navegador (ex.: testes).

// Traz o contrato TokenStorage e a classe MemoryTokenStorage.
import 'token_storage.dart';

/// Fabrica usada fora da web: devolve um armazenamento em memoria.
/// Precisa ter o mesmo nome/assinatura da funcao em token_storage_web.dart,
/// pois o import condicional troca um arquivo pelo outro sem mudar o chamador.
TokenStorage criarStorage() => MemoryTokenStorage();
