# acontece-frontend

Website desenvolvido em Flutter Web para gerenciamento de eventos, inscrições e participantes da plataforma Acontece. Consome a [acontece-api](https://github.com/Stack-Flux-Group/acontece-api), que vive em repositório separado.

# Requisitos

- Flutter 3.50 ou superior (Dart 3.14+)
- Node 18 ou superior, apenas para o proxy de desenvolvimento

Este projeto usa `package:material_ui`, a biblioteca Material que saiu do SDK do Flutter a partir da versão 3.47. Por isso os imports são `package:material_ui/material_ui.dart`, e não `package:flutter/material.dart`.

O alvo é **Web**. As pastas `android/`, `ios/`, `linux/`, `macos/` e `windows/` são resíduo do `flutter create` e não são mantidas: o código não depende de nada específico de plataforma e compilaria para elas, mas nenhuma foi testada.

# Decisões técnicas

O projeto é deliberadamente enxuto — quatro dependências diretas, nenhuma geração de código:

| Assunto | Escolha | Por quê |
|---|---|---|
| Interface | `material_ui` | É a biblioteca Material oficial, agora fora do SDK. Material 3, tema claro e escuro a partir de uma cor-semente |
| Rede | `http` | Um único ponto de rede, em `core/api_client.dart`. Não há necessidade do que o `dio` acrescenta |
| Datas e números | `intl` | Formatação em pt-BR e serialização do `LocalDateTime` da API |
| Estado | Nenhum pacote: `StatefulWidget`, `FutureBuilder` e o widget `AsyncView` | Três abas de CRUD não justificam Riverpod ou Bloc. O carregamento, o erro com retry e o estado vazio ficam concentrados em `widgets/async_view.dart`, que toda tela reusa |
| Injeção | `InheritedWidget` (`services.dart`) | São três repositórios sem estado, criados uma vez. Um Provider aqui seria peso sem retorno |
| Navegação | `Navigator` com `MaterialPageRoute` | Oito telas em hierarquia simples; `go_router` não se paga |
| JSON | `fromJson` e `toJson` escritos à mão | São seis modelos pequenos. Evita `build_runner` e código gerado no repositório |

A camada `repositories/` existe para que nenhuma tela conheça as peculiaridades das rotas: cada estranheza da API fica contida numa classe só, documentada no código e resumida na tabela ao fim deste arquivo.

# Instalar as dependências

```
flutter pub get
```

# Rodar o projeto

São necessários dois terminais. O primeiro sobe o proxy, o segundo compila o app:

```
node tools/dev_proxy.mjs
```

```
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5000
```

# Endereços para testar

- Site: http://localhost:8081
- Checagem da API pelo proxy: http://localhost:8081/api/evento/listar/

Abra sempre a porta **8081**, do proxy. Abrir a 5000 direto faz as chamadas de `/api` caírem no servidor de arquivos do Flutter, que responde `index.html` com status 200 — e o app acusa "A API respondeu em um formato inesperado".

A primeira chamada pode levar cerca de dois minutos: a API está numa instância gratuita do Render que hiberna quando fica sem uso. O cold start medido foi de 147 segundos, então o cliente usa timeout de 180 s e a tela exibe um aviso de "acordando o servidor" após 8 s.

# Por que existe um proxy

A API não envia nenhum header `Access-Control-Allow-*`. Um `OPTIONS /participantes` responde 200 com `allow: GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH` e nenhum header de CORS. Um site que chamasse `https://acontece-api.onrender.com` direto do navegador teria **todas** as requisições bloqueadas.

A solução adotada não altera a API: o app nunca cruza origem. Ele chama `/api/...`, um caminho relativo da mesma origem do site, e quem repassa para a API é a camada de hospedagem — `tools/dev_proxy.mjs` em desenvolvimento, e uma regra de rewrite no host em produção. Como a requisição do navegador não é cross-origin, o CORS não entra em cena.

Quando a API passar a enviar CORS, o proxy deixa de ser necessário e o app pode apontar direto para ela:

```
flutter run -d chrome --dart-define=API_BASE_URL=https://acontece-api.onrender.com
```

# Apontar para a API local

A versão publicada da API está atrás do código-fonte e não expõe o módulo de inscrições. Para exercitar essa parte, rode a API local e redirecione o proxy:

```
API_TARGET=http://127.0.0.1:8080 node tools/dev_proxy.mjs
```

# Testes e análise

```
flutter analyze
```

```
flutter test
```

São 53 testes. Cobrem o que é fácil de errar contra esta API: dígitos verificadores de CPF, as datas sem fuso e com fração de segundo, o envelope de erro, a máquina de estados das inscrições, o `PATCH` parcial de participante, e testes de widget que renderizam as telas contra as respostas reais da API.

# Publicar

```
flutter build web --release
```

Publique o conteúdo de `build/web`. Dois pontos importam:

- **A compilação tem de ser local.** Nenhum host de site estático traz Flutter instalado, e `/build/` está no `.gitignore`. Um deploy conectado ao git tentaria compilar e não encontraria o `flutter`.
- **O host precisa do rewrite de `/api/*`** para `https://acontece-api.onrender.com/:splat`, enquanto a API não tiver CORS. O rewrite precisa ser transparente (status 200), não um redirect: um 301 ou 302 mandaria o navegador para o domínio da API e o CORS voltaria a bloquear. Atenção ao timeout do host — a Netlify, por exemplo, documenta 26 s para proxy, abaixo do cold start da API.

Para conferir o resultado antes de publicar, o proxy serve o build pronto:

```
node tools/dev_proxy.mjs --static
```

## Estrutura do Projeto

```
lib/
├── main.dart                        # Ponto de entrada; tema, locale pt-BR e HomeShell
├── services.dart                    # Injeção dos repositórios (InheritedWidget)
├── core/                            # Infraestrutura que não conhece a interface
│   ├── api_config.dart              # baseUrl (--dart-define=API_BASE_URL) e timeouts
│   ├── api_client.dart              # Único ponto de rede; monta URL, decodifica, traduz erro
│   ├── api_exception.dart           # Espelha ApiErrorResponse, com os fieldErrors por campo
│   ├── api_dates.dart               # LocalDateTime sem fuso; "agora" em America/Sao_Paulo
│   ├── validators.dart              # Espelha o Bean Validation da API (inclui dígitos de CPF)
│   ├── formatters.dart              # Máscaras de CPF, CEP, telefone e datas em pt-BR
│   └── theme.dart                   # Material 3, tema claro e escuro, largura de conteúdo
├── models/                          # Espelho dos DTOs da API
│   ├── evento.dart                  # EventoResponseDTO e EventoRequestDTO
│   ├── endereco.dart                # Endereco (@Embeddable), preenchido pelo ViaCEP
│   ├── participante.dart            # Request, Response e o PATCH parcial
│   ├── inscricao.dart               # InscricaoResponse e InscricaoRequest
│   ├── status_inscricao.dart        # enum + máquina de estados (PENDENTE/CONFIRMADA/CANCELADA)
│   └── paged_model.dart             # PagedModel do Spring Data (content + page)
├── repositories/                    # Uma classe por recurso; isola as rotas
│   ├── evento_repository.dart       # /evento/* (verbos no caminho, sem paginação)
│   ├── participante_repository.dart # /participantes (paginado)
│   └── inscricao_repository.dart    # /inscricoes (filtros, status, contagem de vagas)
├── screens/
│   ├── home_shell.dart              # NavigationRail em tela larga, NavigationBar em estreita
│   ├── eventos/
│   │   ├── eventos_list_screen.dart   # Catálogo, busca por título e filtro por período
│   │   ├── evento_detail_screen.dart  # Detalhe, endereço, ocupação de vagas e ações
│   │   └── evento_form_screen.dart    # Criar e editar; CEP resolvido no servidor
│   ├── participantes/
│   │   ├── participantes_list_screen.dart # Lista paginada com ordenação
│   │   └── participante_form_screen.dart  # Cadastro e edição parcial
│   └── inscricoes/
│       ├── inscricoes_list_screen.dart    # Filtros e mudança de status
│       └── inscricao_form_screen.dart     # Escolher participante e evento
└── widgets/
    ├── async_view.dart              # Carregando / erro com retry / vazio, padronizado
    ├── error_banner.dart            # Exibe message e fieldErrors da API
    ├── evento_card.dart             # Cartão do evento e fallback de foto
    ├── status_chip.dart             # Selos de status e de ocupação de vagas
    └── pickers.dart                 # Seletores de participante e evento, e confirmações

tools/
└── dev_proxy.mjs                    # Proxy de desenvolvimento (Node puro, sem dependências)

test/
├── validators_test.dart             # Validações espelhadas da API
├── api_test.dart                    # Datas, envelope de erro, modelos, paginação
└── app_test.dart                    # Telas renderizadas contra respostas reais da API
```

## Funcionalidades

**Eventos** — listar, buscar por título, filtrar por período, ver detalhe, criar, editar e excluir. O endereço não é digitado: o cliente envia apenas CEP e número, e a API preenche logradouro, bairro, cidade e UF consultando o ViaCEP antes de salvar.

**Participantes** — listar com paginação e ordenação, cadastrar, editar parcialmente e excluir. CPF e e-mail são únicos, e o CPF é validado com os dígitos verificadores já no cliente.

**Inscrições** — criar, listar com filtros por evento, participante e status, e mover o status respeitando as transições que a API aceita. A interface só oferece transições válidas, então o usuário não provoca o erro 409.

## Particularidades da API que o código trata

Documentadas aqui porque não são óbvias ao ler o contrato:

| Comportamento | Onde é tratado |
|---|---|
| `GET /evento/listar/` exige a barra final e devolve a tabela inteira, sem paginação | `evento_repository.dart` |
| `POST /evento/criar` responde 200, não 201, e sem header `Location` | `evento_repository.dart` |
| Datas são `LocalDateTime` sem fuso e com fração de segundo (`2026-12-04T17:06:44.19`) | `core/api_dates.dart` |
| "Agora" é comparado em `America/Sao_Paulo`, como o `Clock` da API | `ApiDates.nowInSaoPaulo` |
| `GET /evento/buscar/periodo` filtra por `dataInicio`, não por sobreposição | `eventos_list_screen.dart` |
| `PUT /evento/atualizar/{id}` é substituição total dos campos | `EventoInput.fromEvento` |
| `telefone` só é apagado enviando `""`; `null` mantém o valor antigo | `ParticipantePatch` |
| `GET /participantes` não tem ordenação padrão no servidor | `participante_repository.dart` |
| `PENDENTE → CONFIRMADA/CANCELADA`, `CONFIRMADA → CANCELADA`, `CANCELADA` é terminal | `status_inscricao.dart` |
| `CANCELADA` libera vaga; `PENDENTE` e `CONFIRMADA` ocupam | `InscricaoRepository.contarAtivasDoEvento` |

## Sobre autenticação

A API não tem autenticação: não há login, senha, nem dono de evento, e nenhum endpoint exige credencial. O site reflete isso com honestidade — é um console de gestão, sem tela de login. Onde uma inscrição precisa saber de quem ela é, o participante é escolhido num seletor com busca.

## Limitações conhecidas

Dependem da API, não do front-end:

- **O módulo de inscrições não está publicado.** A versão no ar responde `404 "No static resource inscricoes."` em todas as rotas de `/inscricoes`. A aba está implementada por completo e protegida por uma sondagem: hoje ela explica que o módulo não foi publicado, e passa a funcionar sozinha quando a API for republicada.
- **A edição de participante depende de republicação.** A versão no ar expõe `PATCH /participantes` sem o `{id}`. O front usa `PATCH /participantes/{id}`, que é o contrato do código-fonte.
