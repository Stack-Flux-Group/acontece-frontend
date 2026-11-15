# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

`acontece-frontend`: website em Flutter Web para a plataforma Acontece (eventos, participantes e inscrições). Consome a `acontece-api`, uma API REST em Kotlin/Spring Boot que vive em **repositório separado** (`github.com/Stack-Flux-Group/acontece-api`). Não é monorepo — nunca escreva caminhos relativos para o back-end, nem edite o código dele a partir daqui.

Idioma do produto: **pt-BR**. Todo o domínio da API é em português (`titulo`, `vagas`, `inscricoes`, `PENDENTE`), e a interface acompanha. Comentários de código são escritos sem acentuação; textos de interface e Markdown usam acentos normalmente.

## Comandos

O Flutter **não está no PATH** nesta máquina. Use o caminho completo ou adicione ao PATH:

```sh
FL="C:/Users/mathe/OneDrive/Documentos/flutter/bin/flutter.bat"
```

```sh
flutter pub get                  # dependências
flutter analyze                  # lint (deve ficar limpo; é o portão de qualidade)
flutter test                     # suíte completa
flutter test test/api_test.dart  # um arquivo
flutter test --plain-name "apaga o telefone com string vazia"   # um teste
flutter build web --release      # build de produção em build/web
```

### Modo demo (padrão)

Por padrão, `main.dart` injeta `core/demo_backend.dart`: um back-end falso em memória (via `MockClient`) que responde todas as rotas no formato real da API, com dados de exemplo. Não precisa de API nem de proxy:

```sh
flutter run -d chrome   # ou -d web-server, e abrir a porta que ele mostrar
```

Os dados voltam ao estado inicial ao recarregar a página. Para usar a API de verdade, passe `--dart-define=USE_API=true` e siga a seção abaixo.

### Rodar o app contra a API (dois processos)

```sh
node tools/dev_proxy.mjs
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5000 --dart-define=USE_API=true
```

Depois abra **http://localhost:8081**, a porta do **proxy**. Ver "A regra da mesma origem" abaixo — abrir a 5000 é o erro mais comum neste projeto.

Variações úteis:

```sh
API_TARGET=http://127.0.0.1:8080 node tools/dev_proxy.mjs  # apontar para a API local
node tools/dev_proxy.mjs --static                          # servir build/web (pré-visualizar produção)
```

## A regra da mesma origem (o fato arquitetural central)

A API **não envia nenhum header `Access-Control-Allow-*`**. Verificado contra o deploy: `OPTIONS /participantes` responde 200 com `allow: GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH` e zero headers de CORS.

Por isso o app **nunca** usa a URL absoluta da API. `ApiConfig.baseUrl` é `/api` — relativo — e quem repassa `/api/*` para a API é a camada de hospedagem:

- desenvolvimento: `tools/dev_proxy.mjs` (Node puro, sem dependências), escutando na 8081
- produção: uma regra de rewrite transparente (status 200) configurada no host

Como o navegador não faz requisição cross-origin, o CORS não entra em cena.

**O erro mais comum do projeto:** abrir `localhost:5000` (servidor do Flutter) em vez de `localhost:8081` (proxy). Nesse caso `/api/evento/listar/` cai no servidor de arquivos, que por ser servidor de SPA devolve `index.html` com status **200**, não 404. O `ApiClient` detecta HTML onde esperava JSON e lança `ApiException.misrouted`, cuja mensagem já instrui a trocar de porta. Se alguém reportar "a API respondeu de forma estranha", **verifique a porta antes de investigar código**.

Ao mexer no `baseUrl`, mantenha o contrato `/api`: trocá-lo para a URL absoluta volta a quebrar no navegador até a API ter CORS.

## Arquitetura

Camadas, de dentro para fora. A regra: cada camada só conhece a de dentro.

```
core/          infraestrutura sem UI (rede, erros, datas, validações, tema)
models/        espelho dos DTOs da API, com fromJson/toJson à mão
repositories/  uma classe por recurso; isola TODA a peculiaridade de rota
screens/ widgets/   interface
services.dart  InheritedWidget que entrega os repositórios
```

**`core/api_client.dart` é o único ponto de rede do app.** Concentra montagem de URL, timeout, decodificação UTF-8 e tradução de qualquer falha para `ApiException`. Nenhuma tela ou repositório deve usar `package:http` direto.

**`repositories/` existe para que nenhuma tela saiba das esquisitices da API.** Quando descobrir uma nova peculiaridade de rota, ela vai para o repositório com um comentário explicando o porquê — não para a tela.

**`widgets/async_view.dart` padroniza os três estados chatos** (carregando, erro com retry, vazio). Toda tela que busca dados usa `AsyncView<T>`. O idioma para filtros é o `reloadKey`: monte uma string com o estado dos filtros e uma versão incrementável, e o `AsyncView` recarrega sozinho quando ela muda. Exemplo em `eventos_list_screen.dart` (`_chave`). Depois de criar, editar ou excluir algo, incremente `_versao` em vez de tentar segurar a função `reload`.

### Decisões deliberadas (não "corrija" sem motivo)

Quatro dependências diretas: `material_ui`, `http`, `intl`, `cupertino_icons`. Sem geração de código.

- **Interface: `package:material_ui/material_ui.dart`**, não `package:flutter/material.dart`. A Material saiu do SDK no Flutter 3.47 e o projeto usa a versão em pacote. É a mesma API; só não misture os dois imports no mesmo projeto. Os delegates de localização (`GlobalMaterialLocalizations.delegates`, com `pt`) vêm do próprio `material_ui` — **não** adicione `flutter_localizations`.
- **Estado:** `StatefulWidget` + `FutureBuilder` + `AsyncView`. Sem Provider, Riverpod ou Bloc.
- **Injeção:** `InheritedWidget` em `services.dart`. Consequência prática: `Services.of(context)` **não funciona em `initState`** — use `didChangeDependencies` com um flag de uma vez só (padrão em `inscricoes_list_screen.dart`).
- **Navegação:** `Navigator` + `MaterialPageRoute`, sem `go_router`. As telas devolvem `bool` no `pop` para sinalizar "algo mudou, recarregue".
- **JSON:** `fromJson`/`toJson` manuais. Sem `build_runner`.

### Armadilhas já resolvidas (não reintroduza)

- **`heroTag` nos FABs.** As três abas vivem num `IndexedStack`, então os três `FloatingActionButton` coexistem. Sem `heroTag` distinta, o `Hero` lança "multiple heroes share the same tag" e **toda navegação quebra**. Qualquer FAB novo numa aba precisa de tag própria.
- **Datas nunca convertem fuso.** Ver abaixo.

## Datas: o ponto mais fácil de errar

A API usa `java.time.LocalDateTime` — data e hora **sem fuso**, digitadas em horário de Brasília. O JSON chega como `"2026-12-04T17:06:44.19"` (note a fração de segundo, que a API realmente envia) e deve voltar como `"2026-12-04T17:06:44"`, nunca com `Z` nem offset: o Jackson recusa.

A regra que mantém tudo coerente: **nunca converter fuso**. Os valores são hora de parede do início ao fim. Use `ApiDates.parse` e `ApiDates.format`, nunca `toIso8601String()` cru nem `toUtc()`.

Para decidir se um evento já encerrou, use `ApiDates.nowInSaoPaulo()` — não `DateTime.now()`. O back-end tem um `Clock` fixo em `America/Sao_Paulo` (`ClockConfig.kt`) justamente porque as datas são naive e o servidor roda em UTC. Comparar com o fuso do navegador do visitante levaria o app a uma conclusão diferente da API.

## Erros

Toda a API responde erro com o mesmo envelope (`GlobalExceptionHandler`):

```json
{"timestamp":"...","status":400,"error":"Bad Request",
 "message":"Dados inválidos na requisição","path":"/participantes",
 "fieldErrors":[{"field":"cpf","message":"CPF inválido"}]}
```

As mensagens já vêm em português e são específicas ("Evento sem vagas disponíveis", "Já existe um participante com esse CPF"). **Exiba-as como vêm**, em vez de reescrever no cliente. Os `fieldErrors` alimentam erro inline no campo do formulário via `ApiException.forField(nome)`; a `message` vai para o `ErrorBanner` ou snackbar.

`ApiException.isMissingEndpoint` distingue "a rota não existe nesta build da API" de "o registro não existe" — ambos são 404. É o que sustenta a sondagem da aba de Inscrições.

## Cold start de ~146 segundos

A API está numa instância gratuita do Render que hiberna. O cold start foi medido três vezes: 147 s, 146 s e 145,9 s. Daí o timeout de **180 s** em `ApiConfig.timeout` e o aviso de "acordando o servidor" que o `AsyncView` mostra após 8 s. Não reduza esses valores sem resolver a hibernação, e conte com essa demora ao testar manualmente.

Esse número também condena a estratégia de rewrite em alguns hosts: a Netlify documenta timeout de **26 s** para proxy, bem abaixo do cold start.

## Particularidades da API que o código trata

| Comportamento | Onde |
|---|---|
| `GET /evento/listar/` exige a barra final e devolve a tabela inteira, sem paginação | `evento_repository.dart` |
| `POST /evento/criar` responde 200, não 201, e sem `Location` | `evento_repository.dart` |
| `GET /evento/buscar/periodo` filtra por `dataInicio`, não por sobreposição | `eventos_list_screen.dart` |
| `PUT /evento/atualizar/{id}` é substituição total; partir de `EventoInput.fromEvento` | `models/evento.dart` |
| Endereço vem do ViaCEP: o cliente envia só `cep` e `numero` | `evento_form_screen.dart` |
| `telefone` só é apagado enviando `""`; `null` mantém o valor antigo | `ParticipantePatch` |
| `GET /participantes` não tem ordenação padrão no servidor | `participante_repository.dart` |
| `PENDENTE → CONFIRMADA/CANCELADA`, `CONFIRMADA → CANCELADA`, `CANCELADA` terminal | `status_inscricao.dart` |
| `CANCELADA` libera vaga; `PENDENTE` e `CONFIRMADA` ocupam | `inscricao_repository.dart` |

A interface só oferece transições de status válidas, para que o usuário nunca provoque o 409 de transição inválida.

**Sem autenticação:** a API não tem login, senha nem dono de evento, e nenhum endpoint exige credencial. O site é um console de gestão, sem tela de login. Onde uma inscrição precisa saber de quem é, o participante é escolhido num seletor. Não invente autenticação sem que a API tenha.

## Testes

55 testes. A abordagem vale conhecer antes de escrever novos:

- `test/validators_test.dart` — validações espelhadas do Bean Validation da API
- `test/api_test.dart` — datas, envelope de erro, modelos, paginação, montagem de URL
- `test/app_test.dart` — **telas renderizadas de verdade**, com `MockClient` do `package:http/testing.dart` devolvendo os corpos JSON **reais** da API

Esse último arquivo é o que dá confiança de verdade: foi ele que pegou o bug das `heroTag` duplicadas. Ao adicionar um teste de widget, chame `initializeDateFormatting('pt_BR')` no `setUpAll` — sem isso o `DateFormat` com nome de mês falha.

Prefira fixtures copiadas de respostas reais da API a JSON inventado: as peculiaridades (fração de segundo, `cpf` com 11 dígitos nus, `email` minúsculo) só aparecem nos dados verdadeiros.

## Estado atual

Completo e funcionando para tudo que a API publicada expõe. 35 arquivos de código, `flutter analyze` limpo, 55 testes passando, `flutter build web --release` compilando.

Funcionam: catálogo de eventos com busca por título e filtro por período, detalhe com endereço e ocupação de vagas, criar/editar/excluir evento, lista paginada de participantes, cadastro com validação de CPF, exclusão. A aba de Inscrições está implementada por completo mas fica protegida por uma sondagem (abaixo).

## O que falta, e de quem é

Nada bloqueante do lado do front-end. O que falta é na `acontece-api`, em repositório separado:

1. **Habilitar CORS** — um `WebMvcConfigurer` com `addCorsMappings`. Sem isso, o site publicado em qualquer domínio tem todas as requisições bloqueadas pelo navegador. É o único bloqueador real de produção.
2. **Republicar a API a partir do `main`** — o deploy está atrás do código-fonte.
3. **Testar `GET /inscricoes` contra o Postgres** — `InscricaoRepository.buscar` usa `(:status IS NULL OR i.status = :status)` com parâmetro sem tipo, padrão que às vezes estoura no PostgreSQL com `could not determine data type of parameter`. Os testes do back-end rodam em H2, que é permissivo, então o problema não apareceria lá.

Depois do item 1, o front compila com `--dart-define=API_BASE_URL=https://acontece-api.onrender.com` e o proxy deixa de ser necessário.

## Problemas conhecidos

**O deploy da API está atrás do código-fonte.** O `/v3/api-docs` publicado expõe 9 rotas:

| No código-fonte | No Render |
|---|---|
| `/inscricoes` (4 rotas) | ausente — `404 "No static resource inscricoes."` |
| `PATCH /participantes/{id}` | só `PATCH /participantes`, sem o `{id}` |
| `GET /participantes/{id}` | ausente |

Efeito no site: a aba de Inscrições mostra um card explicando que o módulo não foi publicado (sondagem em `inscricoes_list_screen.dart`), e editar participante falha. O front já usa o contrato correto do código-fonte, então ambos passam a funcionar **sem alteração nenhuma aqui** quando a API for republicada. A tela de detalhe de participante usa o objeto vindo da lista em vez de `GET /participantes/{id}`, justamente porque essa rota não existe no ar.

**Publicação exige compilar localmente.** Nenhum host de site estático traz Flutter instalado, e `/build/` está no `.gitignore`. Um deploy conectado ao git falha com `flutter: command not found`. Rode `flutter build web --release` e publique só `build/web`.

**Alvo é Web.** As pastas `android/`, `ios/`, `linux/`, `macos/` e `windows/` são resíduo do `flutter create` e nunca foram testadas. Nesta máquina um build desktop nem é possível: `flutter doctor` acusa Visual Studio ausente.

**Credencial exposta no back-end.** `application.properties` do `acontece-api` tem a senha do Supabase em texto puro, num repositório com histórico git. Não é deste repositório, mas vale lembrar se o assunto aparecer.
