<div align="center">

# Acontece — Front-end

**Website da plataforma Acontece: descubra eventos, inscreva-se em poucos cliques e gerencie a agenda da cidade.**

![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.14-0175C2?logo=dart&logoColor=white)
![Plataforma](https://img.shields.io/badge/plataforma-Web-26658C)
![Material 3](https://img.shields.io/badge/UI-Material%203-54ACBF)
![Testes](https://img.shields.io/badge/testes-138%20passando-023859)

[API em produção](https://acontece-api.onrender.com) ·
[Documentação da API (Swagger)](https://acontece-api.onrender.com/swagger-ui/index.html) ·
[Repositório da API](https://github.com/Stack-Flux-Group/acontece-api)

</div>

---

## Início rápido

Ao clonar o projeto, execute (precisa do [Flutter](#pré-requisitos) e do Chrome):

```sh
git clone https://github.com/Stack-Flux-Group/acontece-frontend.git
cd acontece-frontend
flutter pub get
```

**Rodar em localhost com a API de produção** (padrão, não precisa subir nada):

```sh
flutter run -d chrome --web-port=5173
```

**Rodar em localhost com a API local** (`acontece-api` rodando em `http://localhost:8080`):

```sh
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

> A porta **5173** é obrigatória: é a origem liberada no CORS da API. Em outra porta o site mostra "Sem conexão com a API". O primeiro acesso à API de produção pode levar ~2,5 min (servidor gratuito acordando). Detalhes em [Instalação e execução](#instalação-e-execução).

---

## Índice

1. [Sobre o projeto](#sobre-o-projeto)
2. [Funcionalidades](#funcionalidades)
3. [Tecnologias](#tecnologias)
4. [Identidade visual](#identidade-visual)
5. [Pré-requisitos](#pré-requisitos)
6. [Instalação e execução](#instalação-e-execução)
7. [Comandos importantes](#comandos-importantes)
8. [Configuração](#configuração)
9. [Autenticação e permissões](#autenticação-e-permissões)
10. [Arquitetura](#arquitetura)
11. [Estrutura de pastas](#estrutura-de-pastas)
12. [Testes](#testes)
13. [Build e deploy](#build-e-deploy)
14. [Particularidades da API tratadas](#particularidades-da-api-tratadas)
15. [Solução de problemas](#solução-de-problemas)
16. [Convenções do projeto](#convenções-do-projeto)

---

## Sobre o projeto

O **Acontece** é uma plataforma de eventos. Organizadores publicam eventos com data, local e número de vagas; participantes criam uma conta, encontram eventos e se inscrevem. Cada inscrição passa por um ciclo de status (`PENDENTE → CONFIRMADA → CANCELADA`) controlado pelo organizador.

Este repositório contém **apenas o front-end**, um website em **Flutter Web**. Toda a regra de negócio vive na [`acontece-api`](https://github.com/Stack-Flux-Group/acontece-api), uma API REST em Kotlin/Spring Boot mantida em **repositório separado**. O site consome essa API diretamente pelo navegador, autenticando-se com JWT.

> Os dois projetos são independentes: alterações no back-end são feitas no repositório da API, nunca a partir daqui.

---

## Funcionalidades

O site mostra telas diferentes conforme o **papel** de quem está logado.

| Área | Participante | Organizador |
|---|---|---|
| **Acesso** | Criar conta e entrar | Entrar (conta criada pela API) |
| **Eventos** | Ver catálogo, buscar por título, filtrar por período | Tudo do participante + criar, editar e excluir eventos |
| **Detalhe do evento** | Endereço, datas e botão **Quero me inscrever**; mostra o status da própria inscrição | Endereço, datas, **ocupação de vagas**, atalho para as inscrições do evento |
| **Inscrições** | **Minhas inscrições**, com filtro por evento e status | Todas as inscrições, com filtros por evento, participante e status; **confirmar** ou **cancelar** |
| **Participantes** | — | Lista paginada e ordenável; cadastrar, editar e excluir |
| **Perfil** | **Meu perfil**: ver e editar os próprios dados, excluir a conta | — |

Outros comportamentos:

- Sessão persistente: recarregar a página não desloga.
- Layout responsivo para celular, tablet, notebook e PC (veja [Layout responsivo](#layout-responsivo)).
- Cartões de evento sempre do mesmo tamanho, em uma grade que se adapta à largura.
- Avisos de "acordando o servidor" quando a API demora a responder.
- Erros da API exibidos com a mensagem original do back-end, incluindo erros por campo nos formulários.

---

## Tecnologias

| Pacote | Uso | Por que esta escolha |
|---|---|---|
| [`material_ui`](https://pub.dev/packages/material_ui) | Componentes Material 3 | A biblioteca Material saiu do SDK a partir do Flutter 3.47; os imports são `package:material_ui/material_ui.dart` |
| [`http`](https://pub.dev/packages/http) | Cliente HTTP | Um único ponto de rede (`core/api_client.dart`); não há necessidade do que o `dio` acrescenta |
| [`intl`](https://pub.dev/packages/intl) | Datas e números em pt-BR | Formatação localizada e serialização do `LocalDateTime` da API |
| [`web`](https://pub.dev/packages/web) | `localStorage` do navegador | Guarda a sessão sem plugin nativo (plugins exigem Modo de Desenvolvedor no Windows) |
| `cupertino_icons` | Ícones | Padrão do Flutter |
| `flutter_test`, `flutter_lints` | Testes e lint (dev) | Suíte de testes e regras de análise estática |

Decisões deliberadas para manter o projeto enxuto:

- **Estado:** `StatefulWidget` + o widget `AsyncView`; a sessão é um `ChangeNotifier`. Sem Provider, Riverpod ou Bloc.
- **Injeção de dependências:** um `InheritedWidget` (`services.dart`).
- **Navegação:** `Navigator` com `MaterialPageRoute`, sem `go_router`.
- **JSON:** `fromJson`/`toJson` escritos à mão, sem `build_runner`.

---

## Identidade visual

A paleta da marca é centralizada na classe `Paleta`, em [`lib/core/theme.dart`](lib/core/theme.dart), e dela deriva o `ColorScheme` dos temas claro e escuro.

| Cor | Hex | Nome | Onde aparece |
|---|---|---|---|
| ![#A7EBF2](https://img.shields.io/badge/-%20%20%20%20-A7EBF2) | `#A7EBF2` | Ciano suave | Item ativo do menu, textos sobre fundo escuro, selos |
| ![#54ACBF](https://img.shields.io/badge/-%20%20%20%20-54ACBF) | `#54ACBF` | Azul-turquesa | Acentos, barra de ocupação de vagas, inscrição pendente |
| ![#26658C](https://img.shields.io/badge/-%20%20%20%20-26658C) | `#26658C` | Azul médio | Cor primária: botões, links, inscrição confirmada |
| ![#023859](https://img.shields.io/badge/-%20%20%20%20-023859) | `#023859` | Azul-petróleo | Fim dos degradês, textos de marca |
| ![#011C40](https://img.shields.io/badge/-%20%20%20%20-011C40) | `#011C40` | Azul-marinho | Barra lateral, cabeçalhos, texto principal |

Os cabeçalhos das páginas e a tela de entrada usam o degradê marinho → petróleo → azul (`Paleta.degradeProfundo`). Eventos sem foto recebem um degradê da paleta, sempre o mesmo para o mesmo evento.

---

## Pré-requisitos

- **Flutter 3.50** ou superior (inclui o **Dart 3.14**)
- **Google Chrome** (para rodar e depurar)
- **Git**

Confira a instalação com:

```sh
flutter --version
flutter doctor
```

> **Flutter fora do PATH?** No Windows é possível chamar o executável pelo caminho completo, por exemplo `C:/caminho/para/flutter/bin/flutter.bat`. Todos os comandos deste README funcionam assim.

---

## Instalação e execução

**1. Clone o repositório**

```sh
git clone https://github.com/Stack-Flux-Group/acontece-frontend.git
cd acontece-frontend
```

**2. Instale as dependências**

```sh
flutter pub get
```

**3. Rode o site no Chrome, na porta 5173**

```sh
flutter run -d chrome --web-port=5173
```

> **Importante — a porta não é opcional.** A API só aceita chamadas do navegador vindas de origens liberadas no CORS: `http://localhost:5173`, `http://localhost:3000` e `https://acontece-frontend.vercel.app`. Em qualquer outra porta o navegador bloqueia as requisições e o site mostra **"Sem conexão com a API"**.

**4. Entre ou crie uma conta**

- **Participante:** clique em **Criar conta** na tela de entrada.
- **Organizador:** use as credenciais do organizador configurado na API (veja [Autenticação e permissões](#autenticação-e-permissões)).

### Usando uma API local

Com a `acontece-api` rodando na sua máquina:

```sh
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

### Primeiro acesso demorado

A API de produção está numa instância gratuita do Render que **hiberna** quando fica sem uso. O primeiro acesso do dia leva cerca de **2 minutos e meio** (medido entre 146 e 148 s). O site espera até 180 s e, depois de 8 s, avisa que o servidor está acordando. Os acessos seguintes são rápidos.

---

## Comandos importantes

| Comando | Para que serve |
|---|---|
| `flutter pub get` | Instala ou atualiza as dependências do `pubspec.yaml` |
| `flutter run -d chrome --web-port=5173` | Roda o site em modo de desenvolvimento, com hot reload |
| `flutter run -d web-server --web-port=5173` | Sobe só o servidor; abra `http://localhost:5173` em qualquer navegador |
| `flutter analyze` | Análise estática (lint). **Deve terminar sem nenhum problema** |
| `dart format lib test` | Formata o código no padrão oficial do Dart |
| `flutter test` | Roda toda a suíte de testes |
| `flutter test test/api_test.dart` | Roda um arquivo de testes |
| `flutter test --plain-name "sair volta para a tela de entrada"` | Roda um único teste pelo nome |
| `flutter build web --release` | Gera o build de produção em `build/web` |
| `flutter clean` | Apaga `build/` e caches; útil quando o build se comporta de forma estranha |

Atalhos durante o `flutter run`: **`r`** hot reload · **`R`** hot restart · **`q`** sair.

---

## Configuração

O endereço da API é definido em tempo de compilação com `--dart-define`:

| Variável | Padrão | Descrição |
|---|---|---|
| `API_BASE_URL` | `https://acontece-api.onrender.com` | Endereço base da API. Aceita URL absoluta ou caminho relativo (ex.: `/api`, se houver um proxy na mesma origem) |

Constantes de rede em [`lib/core/api_config.dart`](lib/core/api_config.dart):

| Constante | Valor | Motivo |
|---|---|---|
| `ApiConfig.timeout` | 180 s | Cobre o cold start da instância gratuita (~148 s) |
| `ApiConfig.coldStartHint` | 8 s | Tempo até exibir o aviso de "acordando o servidor" |

---

## Autenticação e permissões

### Fluxo de login

```text
Tela de entrada ──POST /auth/login──▶ API devolve o JWT
        │
        ▼
Sessao salva o token no localStorage
        │
        ▼
ApiClient envia "Authorization: Bearer <token>" em todas as chamadas
        │
        ▼
API responde 401 (token vencido)? ──▶ sessão encerrada, volta à tela de entrada
                                       com o aviso "Sua sessão expirou"
```

- O token vale **120 minutos** (padrão da API).
- O e-mail exibido no menu é lido do próprio JWT (claim `email`).
- Sair, ou ter a sessão expirada, fecha todas as telas abertas e volta à entrada.

### Como obter uma conta

| Papel | Como |
|---|---|
| **Participante** | Pelo botão **Criar conta**: nome, e-mail, CPF, telefone (opcional) e senha de 8 a 72 caracteres. Após o cadastro o site já entra automaticamente |
| **Organizador** | Não há cadastro público. O primeiro organizador é criado pela API ao iniciar, a partir das variáveis de ambiente `ORGANIZADOR_EMAIL` e `ORGANIZADOR_SENHA` do back-end |

### O que cada papel pode fazer na API

| Rota | Quem pode |
|---|---|
| `POST /auth/login`, `POST /participantes` | Qualquer pessoa (sem login) |
| `GET /evento/**` | Qualquer usuário logado |
| `POST/PUT/DELETE /evento/**` | Organizador |
| `GET /participantes` | Organizador |
| `GET/PATCH/DELETE /participantes/{id}` | Organizador ou o próprio participante |
| `POST /inscricoes` | Participante, sempre em nome próprio |
| `GET /inscricoes` | Usuário logado (o participante vê só as dele) |
| `PATCH /inscricoes/{id}/status` | Organizador |

A interface só mostra as ações que o papel permite, para que o usuário não receba um erro 403.

---

## Arquitetura

O código é organizado em camadas, e cada camada só conhece a de dentro:

```text
┌──────────────────────────────────────────────────────────┐
│ screens/ + widgets/        Interface (telas e componentes) │
├──────────────────────────────────────────────────────────┤
│ services.dart              Entrega sessão e repositórios   │
├──────────────────────────────────────────────────────────┤
│ repositories/              Uma classe por recurso da API   │
├──────────────────────────────────────────────────────────┤
│ models/                    Espelho dos DTOs da API         │
├──────────────────────────────────────────────────────────┤
│ core/                      Rede, sessão, erros, datas, tema│
└──────────────────────────────────────────────────────────┘
                              │ HTTPS + JWT
                              ▼
                        acontece-api
```

Princípios que guiam o código:

- **`core/api_client.dart` é o único ponto de rede.** Monta a URL, injeta o token, aplica o timeout, decodifica UTF-8 e converte qualquer falha em `ApiException`. Nenhuma tela usa `package:http` diretamente.
- **Os repositórios isolam as peculiaridades da API.** Rotas com verbo no caminho, barra final obrigatória e regras de permissão ficam documentadas ali, e as telas só chamam métodos com nome de domínio.
- **`widgets/async_view.dart` padroniza os três estados** de qualquer tela que busca dados: carregando, erro com "tentar de novo" e vazio.
- **`core/sessao.dart`** guarda quem está logado. A raiz do app (`main.dart`) escuta a sessão e alterna entre a tela de entrada e a casca do site (`HomeShell`), que monta as abas conforme o papel.

---

## Estrutura de pastas

```text
acontece-frontend/
├── lib/
│   ├── main.dart                         # Ponto de entrada: tema, locale pt-BR, login ↔ site
│   ├── services.dart                     # InheritedWidget com a sessão e os repositórios
│   │
│   ├── core/                             # Infraestrutura, sem interface
│   │   ├── api_config.dart               # API_BASE_URL, timeout e tempo do aviso de cold start
│   │   ├── api_client.dart               # Único ponto de rede (token, timeout, erros)
│   │   ├── api_exception.dart            # Envelope de erro da API, fieldErrors, 401/403
│   │   ├── api_dates.dart                # LocalDateTime sem fuso; "agora" em São Paulo
│   │   ├── sessao.dart                   # Usuário logado: entrar, sair, expirar
│   │   ├── token_storage.dart            # Interface de armazenamento da sessão
│   │   ├── token_storage_web.dart        # Implementação com localStorage (navegador)
│   │   ├── token_storage_stub.dart       # Implementação em memória (testes)
│   │   ├── validators.dart               # Regras espelhadas do Bean Validation da API
│   │   ├── formatters.dart               # Máscaras de CPF, CEP, telefone e datas
│   │   └── theme.dart                    # Paleta, temas claro/escuro e logo
│   │
│   ├── models/                           # Espelho dos DTOs da API
│   │   ├── auth.dart                     # Papel, LoginInput, TokenResponse, UsuarioLogado
│   │   ├── evento.dart                   # Evento e EventoInput (criar/editar)
│   │   ├── endereco.dart                 # Endereço preenchido pelo ViaCEP
│   │   ├── participante.dart             # Participante, cadastro e PATCH parcial
│   │   ├── inscricao.dart                # Inscrição e InscricaoInput
│   │   ├── status_inscricao.dart         # Enum e máquina de estados
│   │   └── paged_model.dart              # Paginação do Spring Data
│   │
│   ├── repositories/                     # Acesso à API, um por recurso
│   │   ├── auth_repository.dart          # /auth/login
│   │   ├── evento_repository.dart        # /evento/*
│   │   ├── participante_repository.dart  # /participantes
│   │   └── inscricao_repository.dart     # /inscricoes
│   │
│   ├── screens/                          # Telas
│   │   ├── auth/
│   │   │   └── login_screen.dart         # Entrar e criar conta
│   │   ├── home_shell.dart               # Navegação por papel (barra lateral / inferior)
│   │   ├── eventos/
│   │   │   ├── eventos_list_screen.dart  # Catálogo com busca e filtro por período
│   │   │   ├── evento_detail_screen.dart # Detalhe, inscrição ou gestão do evento
│   │   │   └── evento_form_screen.dart   # Criar e editar evento (organizador)
│   │   ├── inscricoes/
│   │   │   └── inscricoes_list_screen.dart # Todas (organizador) ou minhas (participante)
│   │   └── participantes/
│   │       ├── participantes_list_screen.dart # Lista paginada (organizador)
│   │       ├── participante_form_screen.dart  # Cadastro e edição
│   │       └── perfil_screen.dart             # Meu perfil (participante)
│   │
│   └── widgets/                          # Componentes reutilizáveis
│       ├── async_view.dart               # Carregando / erro / vazio
│       ├── aviso_servidor_lento.dart     # Aviso de cold start nos formulários
│       ├── cabecalho_pagina.dart         # Cabeçalho em degradê das páginas
│       ├── error_banner.dart             # Exibição de erros e snackbars
│       ├── evento_card.dart              # Cartão de evento e foto com fallback
│       ├── pickers.dart                  # Seletores de evento/participante e confirmações
│       └── status_chip.dart              # Selos de status e de vagas
│
├── test/
│   ├── validators_test.dart              # Validações (CPF, CEP, senha...)
│   ├── api_test.dart                     # Datas, erros, modelos, JWT, paginação
│   └── app_test.dart                     # Telas renderizadas para cada papel
│
├── web/                                  # index.html, manifest, ícones e _redirects
├── pubspec.yaml                          # Dependências e metadados
├── analysis_options.yaml                 # Regras do flutter analyze
└── CLAUDE.md                             # Notas técnicas detalhadas para manutenção
```

> As pastas `android/`, `ios/`, `linux/`, `macos/` e `windows/` foram geradas pelo `flutter create` e não são mantidas: o alvo do projeto é **Web**.

---

## Testes

A suíte tem **138 testes**, todos rodando sem acesso à rede:

| Arquivo | O que cobre |
|---|---|
| `test/validators_test.dart` | Regras espelhadas da API: dígitos verificadores do CPF, CEP, telefone, título, vagas, período do evento, senha de 8 a 72 caracteres |
| `test/api_test.dart` | Datas sem fuso e com fração de segundo, envelope de erro (incluindo 401/403 sem corpo), modelos, leitura do JWT, sessão, paginação e montagem de URL |
| `test/app_test.dart` | Telas renderizadas de verdade com um `MockClient` que devolve **respostas reais da API**: login, criar conta, sessão expirada, eventos, inscrição, inscrições e perfil, para cada papel. Inclui o teste de **responsividade**: as telas principais, nos dois papéis, em 4 larguras (celular, tablet, notebook e desktop), falhando em qualquer overflow, e a conferência de que todos os cartões de evento têm o mesmo tamanho |
| `test/contraste_test.dart` | **Acessibilidade de cores**: calcula o contraste WCAG dos pares usados no site (tema claro e escuro, botões desabilitados, selos, textos sobre os degradês) e exige no mínimo 4,5:1 para texto e 3:1 para ícones e bordas |

```sh
flutter test                                        # tudo
flutter test test/app_test.dart                     # um arquivo
flutter test --plain-name "participante se inscreve pelo detalhe do evento"
```

---

## Layout responsivo

As faixas de largura ficam no enum `Tela`, em [`lib/core/theme.dart`](lib/core/theme.dart). Nenhuma tela compara larguras soltas: todas perguntam a `Tela.of(context)`.

| Faixa | Largura | Navegação | Grade de eventos |
|---|---|---|---|
| **Celular** | menos de 600 px | Barra inferior | 1 coluna |
| **Tablet** | 600 a 899 px | Barra lateral compacta (só ícones) | 2 colunas |
| **Notebook** | 900 a 1279 px | Barra lateral completa | 2 a 3 colunas |
| **Desktop** | 1280 px ou mais | Barra lateral completa, conteúdo até 1280 px | 3 a 4 colunas |

A grade calcula as colunas pela largura que sobra ao conteúdo, com no mínimo 300 px por cartão. Todos os cartões têm a mesma altura (`EventoCard.altura`), que cresce junto com o tamanho de fonte do sistema. No celular, os formulários empilham os campos lado a lado, o selo de status das inscrições desce para a própria linha e as ações de participante viram um menu.

---

## Build e deploy

```sh
flutter build web --release
```

O resultado fica em **`build/web`** e é um site estático: basta publicar o conteúdo dessa pasta em qualquer hospedagem (Vercel, Netlify, GitHub Pages...).

Pontos de atenção:

- **O build precisa ser feito localmente.** Hospedagens de site estático não têm Flutter instalado, e `build/` está no `.gitignore`. Um deploy que tente compilar a partir do Git falha com `flutter: command not found`.
- **O domínio precisa estar liberado no CORS da API.** Hoje a origem de produção liberada é `https://acontece-frontend.vercel.app`. Publicar em outro domínio exige adicioná-lo à variável `CORS_ALLOWED_ORIGINS` da API.
- **Netlify:** o arquivo `web/_redirects` é copiado para o build e já contém o fallback de SPA (`/* /index.html 200`).

---

## Particularidades da API tratadas

Comportamentos não óbvios da API e onde o front-end lida com eles:

| Comportamento | Onde é tratado |
|---|---|
| `POST /inscricoes` aceita só `eventoId`; o participante vem do token | `models/inscricao.dart` (`InscricaoInput`) |
| `GET /inscricoes` para participante ignora `participanteId` e devolve só as dele | `inscricoes_list_screen.dart` |
| A ocupação de vagas só pode ser contada pelo organizador | `InscricaoRepository.contarAtivasDoEvento` |
| Respostas 401/403 do filtro de segurança chegam **sem corpo** | `ApiException` (mensagens próprias) |
| Não existe rota para trocar a senha; o `PATCH` de participante não aceita `senha` | `participante_form_screen.dart` |
| `GET /evento/listar/` exige a barra final e devolve todos os eventos, sem paginação | `evento_repository.dart` |
| `POST /evento/criar` responde 200, e não 201 | `evento_repository.dart` |
| Endereço vem do ViaCEP: o cliente envia só `cep` e `numero` | `evento_form_screen.dart` |
| Datas são `LocalDateTime` sem fuso e com fração de segundo (`2026-12-04T17:06:44.19`) | `core/api_dates.dart` |
| "Agora" é comparado no fuso `America/Sao_Paulo`, como o `Clock` da API | `ApiDates.nowInSaoPaulo` |
| `PUT /evento/atualizar/{id}` substitui todos os campos | `EventoInput.fromEvento` |
| O `telefone` só é apagado enviando `""`; `null` mantém o valor | `ParticipantePatch` |
| Status: `PENDENTE → CONFIRMADA/CANCELADA`, `CONFIRMADA → CANCELADA`, `CANCELADA` é final | `models/status_inscricao.dart` |

---

## Solução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| **"Sem conexão com a API"** | Site aberto numa porta fora do CORS da API, ou sem internet | Rode com `--web-port=5173` (ou 3000) e verifique a conexão |
| Tela carregando por ~2 minutos | Cold start do servidor gratuito do Render | Aguarde; os acessos seguintes são rápidos |
| **"Sua sessão expirou"** | O token passou de 120 minutos ou foi recusado | Entre novamente |
| **"Você não tem permissão para esta operação"** | O papel logado não pode fazer aquela ação | Entre com uma conta do papel adequado |
| **"E-mail ou senha inválidos"** | Credenciais erradas (a API não diz qual das duas, de propósito) | Confira os dados ou crie uma conta |
| **"A requisição não chegou à API"** | `API_BASE_URL` aponta para algo que não é a API | Corrija o `--dart-define=API_BASE_URL=...` |
| `flutter` não é reconhecido | Flutter fora do PATH | Adicione `flutter/bin` ao PATH ou use o caminho completo |
| Plugin pede **Modo de Desenvolvedor** no Windows | Plugins Flutter usam symlinks | Ative em Configurações > Para desenvolvedores, ou evite plugins (o projeto usa `package:web` por isso) |
| Build com comportamento estranho | Cache desatualizado | `flutter clean` e depois `flutter pub get` |

---

## Convenções do projeto

- **Idioma:** a interface e a documentação são em **português do Brasil**, com acentos. Comentários de código são escritos sem acentuação.
- **Qualidade:** antes de cada commit, `flutter analyze` precisa terminar sem problemas e `flutter test` precisa passar.
- **Formatação:** `dart format lib test`.
- **Rede:** nunca use `package:http` fora de `core/api_client.dart`; peculiaridades de rota vão para o repositório correspondente.
- **Datas:** nunca converta fuso. Use `ApiDates.parse` e `ApiDates.format`.
- **Erros:** exiba a mensagem da API como ela vem; não reescreva no cliente.
- **Botões flutuantes:** todo `FloatingActionButton` dentro de uma aba precisa de `heroTag` própria, porque as abas coexistem num `IndexedStack`.
- **Cores:** use a `Paleta` ou o `ColorScheme` do tema; não introduza cores fora da identidade visual (exceto as de erro).

Para notas técnicas mais detalhadas sobre manutenção, consulte o [`CLAUDE.md`](CLAUDE.md).
