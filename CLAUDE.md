# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

`acontece-frontend`: website em Flutter Web para a plataforma Acontece (eventos, participantes e inscrições). Consome a `acontece-api`, uma API REST em Kotlin/Spring Boot que vive em **repositório separado** (`github.com/Stack-Flux-Group/acontece-api`). Não é monorepo — nunca escreva caminhos relativos para o back-end, nem edite o código dele a partir daqui.

Idioma do produto: **pt-BR**. Todo o domínio da API é em português (`titulo`, `vagas`, `inscricoes`, `PENDENTE`), e a interface acompanha. Comentários de código são escritos sem acentuação; textos de interface e Markdown usam acentos normalmente.

## Comandos

O Flutter **não está no PATH** nesta máquina. Use o caminho completo:

```sh
FL="C:/Users/mathe/OneDrive/Documentos/flutter/bin"
"$FL/flutter.bat" pub get
"$FL/flutter.bat" analyze                 # lint (deve ficar limpo; é o portão de qualidade)
"$FL/flutter.bat" test                    # suíte completa
"$FL/flutter.bat" test --plain-name "sair volta para a tela de entrada"
"$FL/dart.bat" format lib test            # `flutter format` não existe mais
"$FL/flutter.bat" build web --release     # build de produção em build/web
"$FL/flutter.bat" run -d chrome --web-port=5173
```

**A porta 5173 não é opcional.** A API envia CORS só para `http://localhost:5173`, `http://localhost:3000` e `https://acontece.netlify.app` (`cors.allowed-origins` no back-end). Em outra porta o navegador bloqueia tudo e o app mostra "Sem conexão com a API" (o `ClientException` do navegador não diz que foi CORS).

Plugins Flutter (ex.: `shared_preferences`) exigem Modo de Desenvolvedor no Windows por causa de symlinks, e ele não está ativo. Por isso o token é salvo com `package:web` direto, via import condicional (`infraestrutura/token_storage*.dart`).

## Autenticação e papéis (o fato central)

A API usa JWT (`POST /auth/login` → `{token, tipo, expiraEmSegundos, usuarioId, papel}`). O papel vem na claim `papel`; o e-mail, na claim `email` (o `TokenResponse` não traz o e-mail, então ele é lido do próprio JWT em `UsuarioLogado.fromToken`). O **nome** vem de `GET /me`, buscado em segundo plano por `Sessao.sincronizar` (ao abrir com sessão salva, depois do login e depois de editar o perfil); falha ali é ignorada e a barra mostra o e-mail.

| Rota | Quem pode |
|---|---|
| `POST /auth/login`, `POST /participantes` | qualquer um (sem token) |
| `GET /eventos`, `GET /eventos/{id}` | qualquer logado |
| demais `/eventos/**` | ORGANIZADOR |
| `GET /me`, `PATCH /me/senha` | qualquer logado |
| `GET /participantes` | ORGANIZADOR |
| `GET/PATCH/DELETE /participantes/{id}` | ORGANIZADOR ou o próprio participante |
| `POST /inscricoes` | PARTICIPANTE, sempre em nome próprio (`participanteId` do corpo é sobrescrito pelo token) |
| `GET /inscricoes` | logado; participante é travado no próprio id |
| `PATCH /inscricoes/{id}/status` | ORGANIZADOR |
| `PATCH /inscricoes/{id}/cancelar` | PARTICIPANTE, só a própria (sem corpo; evento encerrado → 400) |

Consequências no front:

- Organizador **não** cria inscrição; participante **não** confirma, mas **cancela a própria** (`InscricaoRepository.cancelar`, rota própria). O organizador muda status por `atualizarStatus`.
- Todo evento traz `vagasDisponiveis`: a ocupação (`vagasOcupadas`, `lotado`) é calculada no `Evento` e vale para os dois papéis. Não conte inscrições pelo cliente.
- `GET /eventos` é paginado (máx. 100): use `listarTodos` quando a tela precisa da lista inteira. As rotas `/evento/...` são obsoletas; não as use.
- A senha se troca em `PATCH /me/senha` (`TrocarSenhaScreen`). Não existe cadastro de organizador.
- 429 no login e na troca de senha (5 erros do mesmo IP e e-mail, 15 min). `Retry-After` não é legível no navegador, então o texto não cita o tempo exato.
- 401/403 do filtro de segurança chegam **com corpo vazio**; as mensagens vêm de `ApiException._genericFor`. Já o 401 do login e o 403 de `AccessDeniedException` vêm com o envelope normal.

Fluxo de sessão: `Sessao` (`infraestrutura/sessao.dart`, um `ChangeNotifier`) guarda o `UsuarioLogado` no `TokenStorage`. `Services` liga o `ApiClient` a ela (`tokenProvider`, `onUnauthorized`). `main.dart` escuta a sessão e alterna entre `LoginScreen` e `HomeShell`; ao deslogar, faz `popUntil(isFirst)` para fechar telas empilhadas. Um 401 em pedido **com token** chama `sessao.expirou()` → volta ao login com aviso.

## Arquitetura

```
infraestrutura/     rede, sessão, erros, datas, validações, tema (sem UI)
modelos_da_api/     espelho dos DTOs da API, com fromJson/toJson à mão
acesso_a_api/       uma classe por recurso; isola TODA a peculiaridade de rota
telas/              telas (autenticacao/, eventos/, inscricoes/, participantes/)
componentes_visuais/ widgets reutilizáveis
services.dart       InheritedWidget que entrega sessão e repositórios
```

**`infraestrutura/api_client.dart` é o único ponto de rede do app.** Concentra URL, header `Authorization`, timeout, decodificação UTF-8 e tradução de falhas para `ApiException`.

**`acesso_a_api/` existe para que nenhuma tela saiba das esquisitices da API.** Peculiaridade nova vai para o repositório com comentário, não para a tela.

**`componentes_visuais/async_view.dart` padroniza carregando / erro com retry / vazio.** O idioma para filtros é o `reloadKey` (ver `_chave` em `eventos_list_screen.dart`); depois de criar/editar/excluir, incremente `_versao`.

As abas recebem o `UsuarioLogado` por construtor (`HomeShell` → telas). As páginas principais usam `CabecalhoPagina` (faixa em degradê) em vez de `AppBar`; ele mostra botão de voltar sozinho quando a tela foi empilhada. Em tela estreita, `ContaBotao` no cabeçalho dá acesso ao "Sair".

### Decisões deliberadas (não "corrija" sem motivo)

Dependências diretas: `material_ui`, `http`, `intl`, `web`, `cupertino_icons`. Sem geração de código.

- **Interface: `package:material_ui/material_ui.dart`**, não `package:flutter/material.dart`. Os delegates de localização vêm do próprio `material_ui` — **não** adicione `flutter_localizations`.
- **Estado:** `StatefulWidget` + `AsyncView`; a sessão é um `ChangeNotifier` escutado com `ListenableBuilder`. Sem Provider/Riverpod/Bloc.
- **Injeção:** `InheritedWidget` em `services.dart`. `Services.of(context)` **não funciona em `initState`** — use `didChangeDependencies` com flag.
- **Navegação:** `Navigator` + `MaterialPageRoute`. Telas devolvem `bool` no `pop` para "algo mudou".
- **Tema:** paleta da marca em `Paleta` (`infraestrutura/theme.dart`). Use as cores dela ou do `ColorScheme` derivado; não introduza cores fora da paleta (exceto erro).

### Armadilhas já resolvidas (não reintroduza)

- **`heroTag` nos FABs.** As abas vivem num `IndexedStack`; FAB sem `heroTag` própria quebra a navegação.
- **Overflow com a fonte de teste.** A fonte dos testes de widget é bem mais larga que a real; `Row` com texto sem `Expanded`/`Flexible` estoura lá. Prefira `Wrap` ou `Expanded`.
- **Selo "Powered by Netlify".** Em `*.netlify.app` o Netlify injeta um iframe fixo no canto inferior direito (~194×61 px, z-index máximo) que cobre FAB, abas da barra inferior e o fim das listas. `ReservaInferior` (`infraestrutura/area_selo.dart`, aplicada no `MaterialApp.builder`) soma 64 px a `MediaQuery.padding/viewPadding` só nesse domínio; FAB, snackbar e `NavigationBar` já respeitam isso. Listas rolavéis usam `folgaFinalDaLista(context, base: N)` em vez de `EdgeInsets.only(bottom: N)`. Tela nova com FAB ou botão no rodapé deve seguir o mesmo caminho.
- **Datas nunca convertem fuso.** Ver abaixo.

## Datas: o ponto mais fácil de errar

A API usa `java.time.LocalDateTime` — data e hora **sem fuso**, em horário de Brasília. O JSON chega como `"2026-12-04T17:06:44.19"` e deve voltar como `"2026-12-04T17:06:44"`, sem `Z` nem offset. Use `ApiDates.parse`/`ApiDates.format`, nunca `toIso8601String()` nem `toUtc()`. Para "já encerrou?", use `ApiDates.nowInSaoPaulo()` (o back-end tem `Clock` fixo em `America/Sao_Paulo`).

A validade do token, ao contrário, é um instante real (claim `exp`, UTC) — essa comparação usa `DateTime.now().toUtc()`.

## Erros

Envelope único (`GlobalExceptionHandler`): `{timestamp, status, error, message, path, fieldErrors[]}`. As mensagens já vêm em português e específicas — **exiba-as como vêm**. `fieldErrors` alimentam erro inline via `ApiException.forField(nome)`.

## Cold start de ~148 segundos

Instância gratuita do Render que hiberna; medido 146–148 s (último em 15/11/2026, no `POST /auth/login`). Daí o timeout de **180 s** e os avisos de "acordando o servidor" após 8 s (`AsyncView` e `AvisoServidorLento` nos formulários de entrada). Não reduza esses valores.

## Layout responsivo e cores

- Faixas de tela: enum `Tela` em `infraestrutura/theme.dart` (celular < 600, tablet < 900, notebook < 1280, desktop). Use `Tela.of(context)`; **não** compare `MediaQuery` com números soltos. Para decisões que dependem da largura que sobra ao conteúdo (a barra lateral ocupa 88 ou 248 px), use `LayoutBuilder`, como a grade de eventos e o detalhe.
- Cartão de evento: altura fixa (`EventoCard.altura`), grade com `SliverGridDelegateWithFixedCrossAxisCount`. Não volte para `Wrap` nem para `maxCrossAxisExtent` (este arredonda para cima e gera colunas de 184 px no celular).
- **Cores sólidas.** Fundo translúcido some conforme o que está atrás. Em `ChoiceChip` o fundo vem de `color` (`WidgetStateProperty`), **não** de `backgroundColor`, que é ignorado no Material 3 e deixava texto branco sobre chip branco.
- Itens `enabled: false` de `PopupMenuItem` são pintados em cinza claro pelo Material; dê cor explícita ao texto.
- O botão desabilitado padrão do Material 3 tem contraste 2,3:1 nesta paleta; `AppTheme` define as cores desabilitadas. Não adicione `iconButtonTheme` global: fez o ícone de `IconButton.filled` sumir.
- A capa do detalhe usa altura **mínima** (cresce com o título) e `ContentWidth` centraliza: filho que não ocupa a largura toda fica centralizado, então use `SizedBox(width: double.infinity)`.

## Testes

176 testes:

- `test/validators_test.dart` — validações espelhadas do Bean Validation (inclui senha 8–72)
- `test/api_test.dart` — datas, envelope de erro, 401/403, modelos, JWT/sessão, paginação, URL
- `test/app_test.dart` — **telas renderizadas de verdade**, com `MockClient` devolvendo corpos reais da API. `_appCom(..., logado: Papel.x)` começa já logado (sessão no `MemoryTokenStorage`); sem `logado`, abre no login. `_tela(tester)` fixa uma janela larga (1400 px) — sem isso o teste roda em 800×600, no layout estreito.

- `test/contraste_test.dart` — contraste WCAG dos pares de cores (texto ≥ 4,5:1, ícones e bordas ≥ 3:1). Se mudar uma cor, esse teste diz se ficou ilegível. Os selos expõem suas cores em `coresStatusInscricao` e `coresEventoStatus` justamente para ele.
- O grupo "layout responsivo" de `app_test.dart` roda as telas em 375 / 768 / 1100 / 1920 px nos dois papéis; um overflow em qualquer largura derruba o teste.

Ao adicionar teste de widget, chame `initializeDateFormatting('pt_BR')` no `setUpAll`. Prefira fixtures copiadas de respostas reais da API.

## Ordem de publicação

O front usa as rotas novas (`/eventos`, `/me`, `/inscricoes/{id}/cancelar`). **Publique a API nova antes do front**: contra a API antiga a lista de eventos volta 404.

## Publicação

Compile localmente (`/build/` está no `.gitignore`, e nenhum host estático traz Flutter) e publique `build/web`. O domínio precisa estar em `CORS_ALLOWED_ORIGINS` da API. `web/_redirects` (Netlify) só tem o fallback de SPA.

**Alvo é Web.** `android/`, `ios/`, `linux/`, `macos/`, `windows/` são resíduo do `flutter create`.

**Credencial exposta no back-end.** `application.properties` do `acontece-api` tem a senha do Supabase em texto puro, num repositório com histórico git. Não é deste repositório, mas vale lembrar se o assunto aparecer.
