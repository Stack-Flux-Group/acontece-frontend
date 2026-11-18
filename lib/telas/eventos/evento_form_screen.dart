// =============================================================================
// evento_form_screen.dart - FORMULARIO DE CRIAR / EDITAR EVENTO
// =============================================================================
//
// Tela empilhada (aberta com Navigator.push). Ao terminar, devolve via `pop`:
//   * true  -> salvou (a lista deve recarregar)
//   * false -> cancelou
// So o organizador chega aqui.
//
// CONCEITO - Form + GlobalKey<FormState>: o `Form` agrupa campos; a chave
// permite chamar `validate()` para rodar o `validator` de TODOS os campos.
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_dates.dart';
import '../../infraestrutura/api_exception.dart';
import '../../infraestrutura/area_selo.dart';
import '../../infraestrutura/formatters.dart';
import '../../infraestrutura/theme.dart';
import '../../infraestrutura/validators.dart';
import '../../modelos_da_api/evento.dart';
import '../../services.dart';
import '../../componentes_visuais/error_banner.dart';
import '../../componentes_visuais/par_responsivo.dart';

/// Criacao e edicao de evento.
///
/// Duas coisas do back-end moldam esta tela:
///
/// 1. **O endereco nao e digitado.** O `EventoRequestDTO` aceita apenas `cep` e
///    `numero`; logradouro, bairro, cidade e uf vem do ViaCEP, consultado pelo
///    back-end antes de salvar. Entao o formulario tem um campo de CEP, nao seis
///    de endereco.
/// 2. **`PUT` e substituicao total.** Na edicao, o formulario nasce preenchido
///    com todos os valores atuais ([EventoInput.fromEvento]); qualquer campo
///    deixado de fora voltaria como `null`.
class EventoFormScreen extends StatefulWidget {
  const EventoFormScreen({super.key, this.evento});

  /// `null` para criar; preenchido para editar.
  final Evento? evento;

  /// Atalho: estamos editando?
  bool get editando => evento != null;

  @override
  State<EventoFormScreen> createState() => _EventoFormScreenState();
}

class _EventoFormScreenState extends State<EventoFormScreen> {
  /// Chave do formulario, usada para validar todos os campos de uma vez.
  final _form = GlobalKey<FormState>();

  // Um controller por campo de texto. `late final`: so recebem valor no
  // `initState` (nao da para usar `widget` na declaracao).
  late final TextEditingController _titulo;
  late final TextEditingController _descricao;
  late final TextEditingController _vagas;
  late final TextEditingController _cep;
  late final TextEditingController _numero;
  late final TextEditingController _fotoUrl;

  /// Datas escolhidas nos seletores (nao sao campos de texto).
  DateTime? _inicio;
  DateTime? _fim;

  /// `true` enquanto a requisicao de salvar esta em andamento.
  bool _salvando = false;

  /// Ultimo erro da API (mostrado no topo do formulario).
  ApiException? _erro;

  @override
  void initState() {
    super.initState();
    // Na edicao, preenche cada campo com o valor atual; na criacao, vazio.
    // `evento?.titulo ?? ''`: se evento for nulo, usa ''.
    final evento = widget.evento;
    _titulo = TextEditingController(text: evento?.titulo ?? '');
    _descricao = TextEditingController(text: evento?.descricao ?? '');
    _vagas = TextEditingController(text: evento?.vagas.toString() ?? '');
    _cep = TextEditingController(
      // Mostra o CEP com mascara (85601-000).
      text: evento == null ? '' : Fmt.cep(evento.endereco.cep),
    );
    _numero = TextEditingController(text: evento?.endereco.numero ?? '');
    _fotoUrl = TextEditingController(text: evento?.fotoUrl ?? '');
    _inicio = evento?.dataInicio;
    _fim = evento?.dataFim;
  }

  @override
  void dispose() {
    // Todo controller criado precisa ser liberado.
    _titulo.dispose();
    _descricao.dispose();
    _vagas.dispose();
    _cep.dispose();
    _numero.dispose();
    _fotoUrl.dispose();
    super.dispose();
  }

  /// Escolhe data e depois hora; [inicio] diz qual das duas datas editar.
  Future<void> _escolherDataHora({required bool inicio}) async {
    // Valor de partida do seletor: a data atual do campo, senao o inicio,
    // senao "amanha" (em horario de Sao Paulo).
    final atual =
        (inicio ? _inicio : _fim) ??
        _inicio ??
        ApiDates.nowInSaoPaulo().add(const Duration(days: 1));

    // Calendario; devolve null se cancelar.
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: inicio ? 'Data de início' : 'Data de fim',
    );
    // `mounted`: apos um `await`, confirma que a tela ainda existe.
    if (data == null || !mounted) return;

    // Relogio; devolve null se cancelar.
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual.hour, minute: atual.minute),
      helpText: inicio ? 'Hora de início' : 'Hora de fim',
    );
    if (!mounted) return;

    // Junta a data escolhida com a hora (ou mantem a hora anterior se cancelou).
    final escolhido = DateTime(
      data.year,
      data.month,
      data.day,
      hora?.hour ?? atual.hour,
      hora?.minute ?? atual.minute,
    );

    setState(() {
      if (inicio) {
        _inicio = escolhido;
        // Sugere um fim coerente: o back-end exige fim > inicio.
        if (_fim == null || !_fim!.isAfter(escolhido)) {
          _fim = escolhido.add(const Duration(hours: 2));
        }
      } else {
        _fim = escolhido;
      }
    });
  }

  /// Valida, monta o corpo e envia (POST se criando, PUT se editando).
  Future<void> _salvar() async {
    // Limpa o erro anterior.
    setState(() => _erro = null);

    // `validate()` roda todos os `validator`; `?.`/`?? false` tratam estado nulo.
    final formOk = _form.currentState?.validate() ?? false;
    // Regra de datas (nao e um campo de texto, entao validamos a parte).
    final erroPeriodo = Validators.periodoEvento(_inicio, _fim);
    if (!formOk || erroPeriodo != null) {
      if (erroPeriodo != null) {
        setState(() => _erro = ApiException(message: erroPeriodo));
      }
      // Interrompe: nada e enviado se houver erro.
      return;
    }

    // Monta o objeto de envio a partir dos campos.
    final input = EventoInput(
      titulo: _titulo.text.trim(),
      descricao: _descricao.text.trim(),
      // `!` seguro: `periodoEvento` ja garantiu que nao sao nulos.
      dataInicio: _inicio!,
      dataFim: _fim!,
      // Texto -> numero inteiro (o validador ja garantiu que e valido).
      vagas: int.parse(_vagas.text.trim()),
      cep: _cep.text.trim(),
      numero: _numero.text.trim(),
      fotoUrl: _fotoUrl.text.trim(),
    );

    // Bloqueia o formulario e mostra "Salvando...".
    setState(() => _salvando = true);
    try {
      final repo = Services.of(context).eventos;
      // Editando => PUT; criando => POST. Ambos devolvem o Evento salvo.
      final evento = widget.editando
          ? await repo.atualizar(widget.evento!.id, input)
          : await repo.criar(input);
      if (!mounted) return;
      mostrarSucesso(
        context,
        widget.editando
            ? 'Evento atualizado.'
            : 'Evento "${evento.titulo}" criado.',
      );
      // Fecha a tela devolvendo `true` ("algo mudou").
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // Falha: mostra o erro e libera o formulario para tentar de novo.
      if (!mounted) return;
      setState(() {
        _erro = e;
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editando ? 'Editar evento' : 'Novo evento'),
      ),
      // AbsorbPointer: enquanto salva, engole toques/cliques (evita duplo envio).
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: folgaFinalDaLista(context),
          children: [
            // Largura maxima de 720 para o formulario nao esticar demais.
            ContentWidth(
              maxWidth: 720,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Banner de erro no topo, se houver.
                    if (erro != null) ...[
                      ErrorBanner(error: erro),
                      const SizedBox(height: 16),
                    ],

                    // TextFormField = TextField com suporte a validacao.
                    TextFormField(
                      controller: _titulo,
                      // Limite de 100 caracteres (com contador na tela).
                      maxLength: 100,
                      // Primeira letra de cada frase em maiuscula.
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        helperText: 'Até 100 caracteres',
                      ),
                      // Funcao que devolve null (ok) ou a mensagem de erro.
                      validator: Validators.tituloEvento,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descricao,
                      // Campo de texto com 4 linhas de altura.
                      maxLines: 4,
                      // Limite da API (`@Size(max = 2000)`), com contador na
                      // tela. O `validator` abaixo repete a regra para quem
                      // colar um texto maior que o permitido.
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        // Mantem o rotulo no topo, ja que o campo e alto.
                        alignLabelWithHint: true,
                      ),
                      validator: Validators.descricaoEvento,
                    ),
                    const SizedBox(height: 20),

                    _Secao('Quando'),
                    // Inicio e fim lado a lado (empilhados no celular).
                    ParResponsivo(
                      esquerda: _CampoDataHora(
                        rotulo: 'Início *',
                        valor: _inicio,
                        onPressed: () => _escolherDataHora(inicio: true),
                      ),
                      direita: _CampoDataHora(
                        rotulo: 'Fim *',
                        valor: _fim,
                        onPressed: () => _escolherDataHora(inicio: false),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Nota(
                      'As datas são interpretadas no horário de Brasília. O fim '
                      'precisa ser depois do início.',
                    ),
                    const SizedBox(height: 20),

                    _Secao('Onde'),
                    // CEP ocupa 2/3 da linha; numero, 1/3.
                    ParResponsivo(
                      flexEsquerda: 2,
                      esquerda: TextFormField(
                        controller: _cep,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'CEP *',
                          hintText: '85601-000',
                        ),
                        validator: Validators.cep,
                      ),
                      direita: TextFormField(
                        controller: _numero,
                        decoration: const InputDecoration(
                          labelText: 'Número',
                          hintText: '123',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Nota(
                      'Rua, bairro e cidade são preenchidos automaticamente a '
                      'partir do CEP, por isso salvar pode levar alguns '
                      'segundos.',
                    ),
                    const SizedBox(height: 20),

                    _Secao('Vagas e imagem'),
                    TextFormField(
                      controller: _vagas,
                      // Teclado numerico em dispositivos moveis.
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Vagas *',
                        helperText: 'Precisa ser maior que zero',
                      ),
                      validator: Validators.vagas,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fotoUrl,
                      // Teclado otimizado para digitar enderecos de site.
                      keyboardType: TextInputType.url,
                      // Limite da API (`@Size(max = 1000)` da fotoUrl).
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'URL da foto',
                        hintText: 'https://...',
                        helperText:
                            'Cole o endereço de uma imagem já publicada',
                      ),
                      validator: Validators.fotoUrl,
                    ),

                    // Aviso extra so na edicao.
                    if (widget.editando) ...[
                      const SizedBox(height: 16),
                      _Nota(
                        'Salvar reescreve todos os campos do evento e consulta '
                        'o CEP de novo. Os valores atuais já vêm preenchidos '
                        'para que nada se perca.',
                      ),
                    ],

                    const SizedBox(height: 28),
                    AcoesFormulario(
                      principal: FilledButton.icon(
                        // `null` desabilita o botao enquanto salva.
                        onPressed: _salvando ? null : _salvar,
                        // Spinner pequeno enquanto salva; icone normal depois.
                        icon: _salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _salvando
                              ? 'Salvando...'
                              : widget.editando
                              ? 'Salvar alterações'
                              : 'Criar evento',
                        ),
                      ),
                      secundario: TextButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo "clicavel" que mostra data+hora e abre os seletores ao tocar.
class _CampoDataHora extends StatelessWidget {
  const _CampoDataHora({
    required this.rotulo,
    required this.valor,
    required this.onPressed,
  });

  final String rotulo;

  /// Data atual do campo (nula = ainda nao escolhida).
  final DateTime? valor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(4),
    // InputDecorator: desenha a moldura/rotulo de um campo sem ser um
    // TextField (aqui o "conteudo" e um Text).
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        suffixIcon: const Icon(Icons.event),
      ),
      child: Text(
        valor == null ? 'Escolher data e hora' : Fmt.dataHora(valor!),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          // Texto de dica em cinza; valor escolhido na cor normal (null).
          color: valor == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    ),
  );
}

/// Titulo de secao do formulario ("QUANDO", "ONDE"...).
class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      // Converte o texto para MAIUSCULAS.
      titulo.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Texto pequeno de orientacao abaixo de um grupo de campos.
class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}
