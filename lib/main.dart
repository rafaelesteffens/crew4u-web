// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'platform/platform_document.dart';
import 'platform/platform_storage.dart';

const backendBaseUrl = String.fromEnvironment(
  'CREW4U_API_BASE_URL',
  defaultValue: 'https://crew4u-api.onrender.com',
);

void main() {
  runApp(const CrewForYouApp());
}

class CrewForYouApp extends StatelessWidget {
  const CrewForYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crew 4U',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AppColors.navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const CrewForYouHomePage(),
    );
  }
}

class AppColors {
  static const navy = Color(0xFF061329);
  static const navy2 = Color(0xFF0A1C38);
  static const blue = Color(0xFF128DFF);
  static const cyan = Color(0xFF18C8FF);
  static const bg = Color(0xFFF3F7FC);
  static const panel = Color(0xFFFFFFFF);
  static const line = Color(0xFFD8E2EE);
  static const softBlue = Color(0xFFEAF5FF);
  static const cell = Color(0xFFD9D9D9);
  static const inputCell = Color(0xFFE8E8E8);
  static const green = Color(0xFF19A65A);
}

class CrewForYouHomePage extends StatefulWidget {
  const CrewForYouHomePage({super.key});

  @override
  State<CrewForYouHomePage> createState() => _CrewForYouHomePageState();
}

class _CrewForYouHomePageState extends State<CrewForYouHomePage> {
  String esc(Object? value) {
    final text = value?.toString() ?? '';
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  int selectedIndex = 0;
  String escalaPeriodo = 'Mês';
  bool resumoEscalaAberto = false;
  final Map<String, GlobalKey> escalaDiaKeys = {};
  String? ultimaDataAutoScrollEscala;
  String? escalaMesResumoKey;
  final ScrollController escalaScrollController = ScrollController();
  final ScrollController salarioScrollController = ScrollController();
  final ScrollController jornadaScrollController = ScrollController();
  final ScrollController tabelaHorizontalScrollController = ScrollController();
  final ScrollController tabelaVerticalScrollController = ScrollController();
  final PlatformStorage storage = const PlatformStorage();
  final PlatformDocumentService documentService =
      const PlatformDocumentService();

  bool jornadaAclimatado = true;
  String jornadaFusoApresentacao = 'Brasília (UTC-3)';
  String jornadaFusoUltimoDestino = 'Brasília (UTC-3)';
  String jornadaTripulacao = 'Simples';
  int jornadaEtapas = 2;
  TimeOfDay jornadaApresentacao = const TimeOfDay(hour: 8, minute: 0);
  bool jornadaHouveExtensao = false;
  double jornadaMinutosExcedidos = 0;

  String selectedCargo = 'COPILOTO';
  bool gratificacaoAtiva = false;

  String previdenciaPrivada = '0%';
  int assistenciaMedicaAmil = 1;
  bool servicoSaudeDasa = false;
  bool seguroBradescoFuneral = false;
  String seguroVidaComplementar = 'Não utilizo';
  String assistenciaOdontoFamilia = 'Não utilizo';
  String gympass = 'Não utilizo';

  double cotacaoDolar = 5.20;
  String cotacaoStatus = 'Cotação padrão';
  bool carregandoCotacao = false;

  String? selectedFileName;
  String? selectedSheetName;
  String? importStatus;
  bool isLoading = false;

  List<Map<String, String>> escalaEventos = [];
  List<Map<String, dynamic>> historicoImportacoes = [];
  List<Map<String, dynamic>> aeroportosLocais = [];
  Map<String, Map<String, dynamic>> escalaHistoricoMensal = {};
  String? selectedEscalaMesKey;
  String selectedEscalaTipo = 'executada';
  Map<String, Map<String, dynamic>> meteoCache = {};
  Set<String> meteoLoadingKeys = {};
  bool mostrarUploadSuccess = false;

  Map<String, dynamic> resumo = resumoVazio();

  Map<String, Map<String, double>> cargoConfigs = {
    'COMANDANTE': {
      'salario_base': 16727.06,
      'km_diurno': 0.216027,
      'km_noturno': 0.432054,
      'km_fim_semana': 0.432054,
      'km_fim_semana_noturno': 0.432054,
      'hora_reserva': 183.61,
      'hora_sobreaviso': 61.20,
      'hora_simulador': 753.61,
      'gratificacao': 5018.12,
    },
    'COPILOTO': {
      'salario_base': 9732.85,
      'km_diurno': 0.143193,
      'km_noturno': 0.286386,
      'km_fim_semana': 0.286386,
      'km_fim_semana_noturno': 0.286386,
      'hora_reserva': 121.71,
      'hora_sobreaviso': 40.57,
      'hora_simulador': 508.45,
      'gratificacao': 0.00,
    },
    'COMISSARIO': {
      'salario_base': 3013.65,
      'km_diurno': 0.057349,
      'km_noturno': 0.114698,
      'km_fim_semana': 0.114698,
      'km_fim_semana_noturno': 0.114698,
      'hora_reserva': 48.75,
      'hora_sobreaviso': 16.25,
      'hora_simulador': 0.00,
      'gratificacao': 0.00,
    },
  };

  static Map<String, dynamic> resumoVazio() {
    return {
      'total_eventos': 0,
      'total_voos': 0,
      'total_reservas': 0,
      'total_sobreavisos': 0,
      'horas_reserva': 0,
      'horas_sobreaviso': 0,
      'km_total': 0,
      'km_diurno': 0,
      'km_noturno': 0,
      'km_fim_semana': 0,
      'km_fim_semana_noturno': 0,
      'voos_sem_distancia': [],
      'diarias': {},
      'total_diarias_brl': 0,
      'total_diarias_usd': 0,
    };
  }

  @override
  void dispose() {
    escalaScrollController.dispose();
    salarioScrollController.dispose();
    jornadaScrollController.dispose();
    tabelaHorizontalScrollController.dispose();
    tabelaVerticalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(inicializarDadosLocais());
    carregarCotacaoDolar();
  }

  Future<void> inicializarDadosLocais() async {
    await carregarConfiguracoesLocais();
    await carregarHistoricoEscalasLocal();
    await carregarUltimaEscalaLocal();
    selectedIndex = 0;
    escalaPeriodo = 'Mês';
    ultimaDataAutoScrollEscala = null;
    if (mounted) setState(() {});
  }

  Future<void> carregarConfiguracoesLocais() async {
    final raw = await storage.read('crew4u_config');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cargos = toStringDynamicMap(decoded['cargoConfigs']);
      final loaded = <String, Map<String, double>>{};

      for (final entry in cargos.entries) {
        final values = toStringDynamicMap(entry.value);
        loaded[entry.key] = values.map(
          (key, value) => MapEntry(key, toDouble(value)),
        );
      }

      if (loaded.isNotEmpty) cargoConfigs = loaded;

      final dolar = toDouble(decoded['cotacaoDolar']);
      if (dolar > 0) cotacaoDolar = dolar;

      aeroportosLocais = (decoded['aeroportosLocais'] as List<dynamic>? ?? [])
          .map((item) => toStringDynamicMap(item))
          .toList();
    } catch (_) {}
  }

  void salvarConfiguracoesLocais() {
    final payload = {
      'cargoConfigs': cargoConfigs,
      'cotacaoDolar': cotacaoDolar,
      'aeroportosLocais': aeroportosLocais,
    };

    unawaited(storage.write('crew4u_config', jsonEncode(payload)));
    showSnack('Configurações salvas no navegador.');
  }

  Future<void> carregarUltimaEscalaLocal() async {
    final raw = await storage.read('crew4u_last_roster');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final eventosRaw = decoded['escalaEventos'] as List<dynamic>? ?? [];
      final eventos = eventosRaw.map<Map<String, String>>((item) {
        final map = toStringDynamicMap(item);
        return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
      }).toList();

      selectedFileName = decoded['selectedFileName']?.toString();
      selectedSheetName = decoded['selectedSheetName']?.toString();
      selectedCargo = decoded['selectedCargo']?.toString() ?? selectedCargo;
      selectedEscalaMesKey = decoded['selectedEscalaMesKey']?.toString();
      selectedEscalaTipo =
          decoded['selectedEscalaTipo']?.toString() ?? selectedEscalaTipo;
      resumo = toStringDynamicMap(decoded['resumo']);
      if (resumo.isEmpty) resumo = resumoVazio();
      escalaEventos = eventos;
      if (eventos.isNotEmpty) {
        importStatus = 'Última escala restaurada do navegador.';
      }
    } catch (_) {
      unawaited(storage.remove('crew4u_last_roster'));
    }
  }

  void salvarUltimaEscalaLocal() {
    final payload = {
      'selectedFileName': selectedFileName,
      'selectedSheetName': selectedSheetName,
      'selectedCargo': selectedCargo,
      'selectedEscalaMesKey': selectedEscalaMesKey,
      'selectedEscalaTipo': selectedEscalaTipo,
      'resumo': resumo,
      'escalaEventos': escalaEventos,
      'savedAt': DateTime.now().toIso8601String(),
    };

    unawaited(storage.write('crew4u_last_roster', jsonEncode(payload)));
  }

  Future<void> carregarHistoricoEscalasLocal() async {
    final raw = await storage.read('crew4u_roster_history_v1');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      escalaHistoricoMensal = decoded.map(
        (mes, value) => MapEntry(mes, toStringDynamicMap(value)),
      );
    } catch (_) {
      unawaited(storage.remove('crew4u_roster_history_v1'));
    }
  }

  void salvarHistoricoEscalasLocal() {
    unawaited(
      storage.write(
        'crew4u_roster_history_v1',
        jsonEncode(escalaHistoricoMensal),
      ),
    );
  }

  void salvarEscalaNoHistoricoMensal(
    String filename,
    String sheetName,
    List<Map<String, String>> eventos,
    Map<String, dynamic> resumoImportado,
  ) {
    final mesKey = mesKeyDosEventos(eventos);
    if (mesKey == null) return;

    final mes = Map<String, dynamic>.from(
      escalaHistoricoMensal[mesKey] ?? <String, dynamic>{},
    );
    final tipo = mes['planejada'] == null ? 'planejada' : 'executada';
    final eventosAtuais = escalaEventos;
    final resumoAtual = resumo;
    escalaEventos = eventos;
    resumo = resumoImportado;
    final holerite = calcularHoleriteLocal();
    escalaEventos = eventosAtuais;
    resumo = resumoAtual;
    final salario = toStringDynamicMap(holerite['salario']);

    mes[tipo] = {
      'selectedFileName': filename,
      'selectedSheetName': sheetName,
      'selectedCargo': selectedCargo,
      'resumo': resumoImportado,
      'escalaEventos': eventos,
      'salarioLiquido': salario['salario_liquido'],
      'savedAt': DateTime.now().toIso8601String(),
    };

    escalaHistoricoMensal[mesKey] = mes;
    limitarHistoricoEscalasASeisMeses();

    setState(() {
      selectedEscalaMesKey = mesKey;
      selectedEscalaTipo = tipo;
      importStatus = tipo == 'planejada'
          ? 'Escala salva como Planejada de ${labelMesKey(mesKey)}.'
          : 'Escala salva como Executada de ${labelMesKey(mesKey)}.';
    });

    salvarHistoricoEscalasLocal();
  }

  void limitarHistoricoEscalasASeisMeses() {
    final keys = escalaHistoricoMensal.keys.toList()..sort();
    while (keys.length > 6) {
      final removida = keys.removeAt(0);
      escalaHistoricoMensal.remove(removida);
    }
  }

  String? mesKeyDosEventos(List<Map<String, String>> eventos) {
    for (final event in eventos) {
      final data = parseDataPtBr(event['data'] ?? '');
      if (data != null) {
        return '${data.year}-${data.month.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }

  List<String> mesesHistoricoOrdenados() {
    final keys = escalaHistoricoMensal.keys.toList()..sort();
    return keys.reversed.toList();
  }

  String labelMesKey(String mesKey) {
    final parts = mesKey.split('-');
    if (parts.length != 2) return mesKey;
    final mes = int.tryParse(parts[1]);
    final ano = parts[0];
    if (mes == null) return mesKey;
    return '${nomeMesCurto(mes.toString().padLeft(2, '0'))}/$ano';
  }

  void selecionarEscalaHistorico(String mesKey, String tipo) {
    final mes = escalaHistoricoMensal[mesKey];
    final registro = toStringDynamicMap(mes?[tipo]);
    if (registro.isEmpty) return;

    final eventosRaw = registro['escalaEventos'] as List<dynamic>? ?? [];
    final eventos = eventosRaw.map<Map<String, String>>((item) {
      final map = toStringDynamicMap(item);
      return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    }).toList();

    setState(() {
      selectedEscalaMesKey = mesKey;
      selectedEscalaTipo = tipo;
      selectedFileName = registro['selectedFileName']?.toString();
      selectedSheetName = registro['selectedSheetName']?.toString();
      selectedCargo = registro['selectedCargo']?.toString() ?? selectedCargo;
      resumo = toStringDynamicMap(registro['resumo']);
      if (resumo.isEmpty) resumo = resumoVazio();
      escalaEventos = eventos;
      ultimaDataAutoScrollEscala = null;
      escalaDiaKeys.clear();
      importStatus =
          '${labelTipoEscala(tipo)} carregada de ${labelMesKey(mesKey)}.';
    });

    salvarUltimaEscalaLocal();
  }

  String labelTipoEscala(String tipo) {
    return tipo == 'planejada' ? 'Planejada' : 'Executada';
  }

  void preservarEscalaAtualAntesDeUpload() {
    if (escalaEventos.isEmpty) return;
    final mesKey = mesKeyDosEventos(escalaEventos);
    if (mesKey == null) return;

    final mes = Map<String, dynamic>.from(
      escalaHistoricoMensal[mesKey] ?? <String, dynamic>{},
    );
    final tipo = selectedEscalaTipo == 'executada' && mes['planejada'] != null
        ? 'executada'
        : 'planejada';

    if (mes[tipo] != null) return;

    final holerite = calcularHoleriteLocal();
    final salario = toStringDynamicMap(holerite['salario']);
    mes[tipo] = {
      'selectedFileName': selectedFileName,
      'selectedSheetName': selectedSheetName,
      'selectedCargo': selectedCargo,
      'resumo': resumo,
      'escalaEventos': escalaEventos,
      'salarioLiquido': salario['salario_liquido'],
      'savedAt': DateTime.now().toIso8601String(),
    };
    escalaHistoricoMensal[mesKey] = mes;
    limitarHistoricoEscalasASeisMeses();
    salvarHistoricoEscalasLocal();
  }

  Future<void> carregarCotacaoDolar() async {
    setState(() {
      carregandoCotacao = true;
      cotacaoStatus = 'Buscando cotação...';
    });

    try {
      final uri = Uri.parse(
        'https://economia.awesomeapi.com.br/json/last/USD-BRL',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final usdbrl = toStringDynamicMap(decoded['USDBRL']);
      final bid = double.tryParse(usdbrl['bid']?.toString() ?? '');

      if (bid == null || bid <= 0) {
        throw Exception('Cotação inválida');
      }

      setState(() {
        cotacaoDolar = bid;
        cotacaoStatus = 'Cotação automática USD/BRL';
        carregandoCotacao = false;
      });

      salvarConfiguracoesLocais();
    } catch (_) {
      setState(() {
        cotacaoStatus = 'Cotação automática indisponível';
        carregandoCotacao = false;
      });
    }
  }

  Future<void> pickExcelFile() async {
    const typeGroup = XTypeGroup(
      label: 'Planilhas Excel',
      extensions: ['xlsx', 'xls'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel',
      ],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    preservarEscalaAtualAntesDeUpload();

    setState(() {
      selectedFileName = file.name;
      selectedSheetName = null;
      importStatus = 'Enviando arquivo para análise...';
      escalaEventos = [];
      resumo = resumoVazio();
      isLoading = true;
    });

    try {
      final bytes = await file.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendBaseUrl/upload-escala'),
      );

      request.fields['cargo'] = selectedCargo;

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Backend retornou erro ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final filename = decoded['filename']?.toString() ?? file.name;
      final sheetName = decoded['sheet']?.toString() ?? '';
      final rawEvents = decoded['events'] as List<dynamic>? ?? [];
      final rawSummary = toStringDynamicMap(decoded['summary']);

      final eventos = rawEvents.map<Map<String, String>>((event) {
        final map = toStringDynamicMap(event);

        return {
          'data': map['data']?.toString() ?? '',
          'data_fim_iso': map['data_fim_iso']?.toString() ?? '',
          'tipo': map['tipo']?.toString() ?? '',
          'identificacao': map['identificacao']?.toString() ?? '',
          'pairing': map['pairing']?.toString() ?? '',
          'origem': map['origem']?.toString() ?? '',
          'origem_lat': map['origem_lat']?.toString() ?? '',
          'origem_lon': map['origem_lon']?.toString() ?? '',
          'saida': map['saida']?.toString() ?? '',
          'destino': map['destino']?.toString() ?? '',
          'destino_lat': map['destino_lat']?.toString() ?? '',
          'destino_lon': map['destino_lon']?.toString() ?? '',
          'chegada': map['chegada']?.toString() ?? '',
          'duty_report': map['duty_report']?.toString() ?? '',
          'duty_debrief': map['duty_debrief']?.toString() ?? '',
          'distancia_km': map['distancia_km']?.toString() ?? '',
          'km_diurno': map['km_diurno']?.toString() ?? '',
          'km_noturno': map['km_noturno']?.toString() ?? '',
          'km_fim_semana': map['km_fim_semana']?.toString() ?? '',
          'km_fim_semana_noturno':
              map['km_fim_semana_noturno']?.toString() ?? '',
          'cafe': map['cafe']?.toString() ?? '',
          'almoco': map['almoco']?.toString() ?? '',
          'jantar': map['jantar']?.toString() ?? '',
          'ceia': map['ceia']?.toString() ?? '',
          'grupo_diaria': map['grupo_diaria']?.toString() ?? '',
          'moeda_diaria': map['moeda_diaria']?.toString() ?? '',
          'status': map['status']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        selectedFileName = filename;
        selectedSheetName = sheetName;
        escalaEventos = eventos;
        resumo = rawSummary;
        importStatus =
            'Escala importada com sucesso. ${eventos.length} eventos tratados encontrados.';
        mostrarUploadSuccess = true;
        selectedIndex = 0;
        ultimaDataAutoScrollEscala = null;
        escalaDiaKeys.clear();
        isLoading = false;
      });

      salvarEscalaNoHistoricoMensal(filename, sheetName, eventos, rawSummary);
      salvarUltimaEscalaLocal();
      registrarHistorico(filename);
    } catch (error) {
      setState(() {
        importStatus = 'Erro ao enviar/ler o Excel: $error';
        mostrarUploadSuccess = false;
        escalaEventos = [];
        resumo = resumoVazio();
        isLoading = false;
      });
    }
  }

  void registrarHistorico(String filename) {
    final holerite = calcularHoleriteLocal();
    final salario = toStringDynamicMap(holerite['salario']);

    final registro = {
      'arquivo': filename,
      'cargo': selectedCargo,
      'data': DateTime.now().toIso8601String(),
      'proventos': salario['proventos'],
      'descontos': salario['descontos'],
      'liquido': salario['salario_liquido'],
      'eventos': resumo['total_eventos'],
      'voos': resumo['total_voos'],
    };

    setState(() {
      historicoImportacoes.insert(0, registro);
      if (historicoImportacoes.length > 12) historicoImportacoes.removeLast();
    });
  }

  static Map<String, dynamic> toStringDynamicMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  static double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  void selecionarAba(int pageIndex) {
    setState(() => selectedIndex = pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = switch (pageIndex) {
        1 => salarioScrollController,
        3 => jornadaScrollController,
        _ => null,
      };
      if (controller?.hasClients == true) {
        controller!.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      if (pageIndex == 0) {
        ultimaDataAutoScrollEscala = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildEscalaDashboardPage(),
      buildHoleritePage(),
      buildTabelaPage(),
      buildJornadaPage(),
      buildProfilePage(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: AppColors.navy,
          body: Stack(
            children: [
              pages[selectedIndex],
              buildMobileFloatingAction(
                alignment: Alignment.bottomLeft,
                icon: Icons.upload_file_outlined,
                tooltip: isLoading
                    ? 'Processando escala...'
                    : 'Importar escala',
                onTap: isLoading ? null : pickExcelFile,
              ),
              buildMobileFloatingAction(
                alignment: Alignment.bottomRight,
                icon: Icons.share_outlined,
                tooltip: 'Compartilhar escala em PDF',
                onTap: escalaEventos.isEmpty ? null : abrirOpcoesExportarEscala,
              ),
            ],
          ),
          bottomNavigationBar: buildBottomNavBar(),
        );
      },
    );
  }

  Widget buildMobileFloatingAction({
    required Alignment alignment,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isLeft = alignment == Alignment.bottomLeft;

    return Positioned(
      left: isLeft ? 18 : null,
      right: isLeft ? null : 18,
      bottom: 16,
      child: SafeArea(
        child: buildRoundActionButton(
          icon: icon,
          tooltip: tooltip,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return buildRoundActionButton(icon: icon, tooltip: label, onTap: onTap);
  }

  Widget buildRoundActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(colors: [AppColors.blue, AppColors.cyan])
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: 19,
          ),
        ),
      ),
    );
  }

  Widget buildBottomNavBar() {
    final items = navigationItems();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.navy : Colors.white;
    final inactive = isDark
        ? Colors.white54
        : AppColors.navy.withValues(alpha: 0.54);
    final activeBackground = AppColors.blue.withValues(
      alpha: isDark ? 0.16 : 0.12,
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(color: AppColors.blue.withValues(alpha: 0.18)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final pageIndex = item['index'] as int;
            final selected = selectedIndex == pageIndex;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => selecionarAba(pageIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? activeBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: selected ? AppColors.cyan : inactive,
                        size: 27,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: selected ? AppColors.cyan : inactive,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget buildSidebar() {
    final items = navigationItems();

    return Container(
      width: 106,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          buildMiniLogo(),
          const SizedBox(height: 20),
          ...items.map((item) {
            return buildNavButton(
              item['index'] as int,
              item['icon'] as IconData,
              item['label'] as String,
            );
          }),
          const Spacer(),
          buildSidebarActionButton(
            tooltip: 'Importar escala',
            icon: Icons.upload_file_outlined,
            onTap: isLoading ? null : pickExcelFile,
          ),
          const SizedBox(height: 8),
          buildSidebarActionButton(
            tooltip: 'Compartilhar escala em PDF',
            icon: Icons.share_outlined,
            onTap: escalaEventos.isEmpty ? null : abrirOpcoesExportarEscala,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: IconButton(
              tooltip: 'Atualizar cotação do dólar',
              onPressed: carregarCotacaoDolar,
              icon: Icon(
                carregandoCotacao ? Icons.sync : Icons.currency_exchange,
                color: AppColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, Object>> navigationItems() {
    return <Map<String, Object>>[
      {'index': 0, 'icon': Icons.flight_takeoff_outlined, 'label': 'Escala'},
      {'index': 1, 'icon': Icons.payments_outlined, 'label': 'Salário'},
      {'index': 3, 'icon': Icons.timer_outlined, 'label': 'Jornada'},
      {'index': 4, 'icon': Icons.person_outline, 'label': 'Perfil'},
    ];
  }

  Widget buildSidebarActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 42,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.blue.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? AppColors.blue.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.cyan : Colors.white30,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget buildMiniLogo() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              'assets/logo_crew4u.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return buildTextLogo(fontSize: 16, fourSize: 26, dark: false);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget buildNavButton(int index, IconData icon, String label) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blue.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: AppColors.blue.withValues(alpha: 0.45))
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.cyan : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPageShell({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final isEscala = title == 'Escala';
    final isSalary = title == 'Salário';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        final horizontalPadding = isMobile ? 14.0 : 28.0;
        final verticalPadding = isMobile ? 14.0 : 28.0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEscala
                  ? const [
                      Color(0xFF030B18),
                      Color(0xFF071A34),
                      Color(0xFF020713),
                    ]
                  : isSalary && isDark
                  ? const [
                      Color(0xFF030B18),
                      Color(0xFF071A34),
                      Color(0xFF020713),
                    ]
                  : const [Color(0xFFF7FBFF), Color(0xFFEAF2FB)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                isMobile ? 8 : verticalPadding,
              ),
              child: Column(
                children: [
                  if (!isEscala) ...[
                    buildPageHeader(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                    ),
                    SizedBox(height: isMobile ? 14 : 22),
                  ],
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;

        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navy2],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 24 : 24),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(icon, color: AppColors.cyan, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildHeaderTitleText(
                            title,
                            subtitle,
                            mobile: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 0),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(icon, color: AppColors.cyan, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: buildHeaderTitleText(title, subtitle)),
                    buildHeaderActions(),
                  ],
                ),
        );
      },
    );
  }

  Widget buildHeaderTitleText(
    String title,
    String subtitle, {
    bool mobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: mobile ? 24 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: mobile ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: mobile ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildHeaderActions({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Importando...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: pickExcelFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.blue, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Upload',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!compact) ...[const SizedBox(width: 16), buildTopBrand()],
      ],
    );
  }

  Widget buildTopBrand() {
    return SizedBox(
      height: 38,
      width: 126,
      child: Image.asset(
        'assets/logo_crew4u.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerRight,
        errorBuilder: (context, error, stackTrace) {
          return Align(
            alignment: Alignment.centerRight,
            child: buildTextLogo(fontSize: 25, fourSize: 39, dark: false),
          );
        },
      ),
    );
  }

  Widget buildUploadPage() {
    return buildPageShell(
      title: 'Crew 4U',
      subtitle: 'Simulador profissional de remuneração para tripulantes.',
      icon: Icons.flight_takeoff,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(38),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeroLogo(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        buildCargoSelectorLarge(),
                        const SizedBox(width: 16),
                        buildInfoPill(Icons.lock_outline, 'Cálculo local'),
                        const SizedBox(width: 10),
                        buildInfoPill(Icons.auto_graph, 'Análise automática'),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Importe sua escala em Excel para iniciar a análise de KM, jornada, diárias, descontos e salário líquido.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4E5B6D),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        PrimaryButton(
                          icon: isLoading
                              ? Icons.hourglass_top
                              : Icons.upload_file,
                          label: isLoading
                              ? 'Processando...'
                              : 'Importar escala Excel',
                          onTap: isLoading ? null : pickExcelFile,
                        ),
                        const SizedBox(width: 12),
                        SecondaryButton(
                          icon: Icons.settings_outlined,
                          label: 'Configurações',
                          onTap: () => setState(() => selectedIndex = 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (selectedFileName != null)
                      buildStatusBox()
                    else
                      buildEmptyUploadBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeroLogo() {
    return Row(
      children: [
        SizedBox(
          height: 92,
          width: 310,
          child: Image.asset(
            'assets/logo_crew4u.png',
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              return buildTextLogo(fontSize: 62, fourSize: 90, dark: true);
            },
          ),
        ),
        const SizedBox(width: 22),
        Container(width: 1, height: 56, color: AppColors.line),
        const SizedBox(width: 22),
        const Expanded(
          child: Text(
            'Crew 4U',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTextLogo({
    required double fontSize,
    required double fourSize,
    required bool dark,
  }) {
    final textColor = dark ? AppColors.navy : Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'crew',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            letterSpacing: -3,
            color: textColor,
          ),
        ),
        Text(
          '4',
          style: TextStyle(
            fontSize: fourSize,
            height: 0.8,
            fontWeight: FontWeight.w200,
            letterSpacing: -7,
            color: AppColors.blue,
            shadows: [
              Shadow(
                color: AppColors.blue.withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        Text(
          'u',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            letterSpacing: -3,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget buildCargoSelectorLarge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cargo:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 14),
        buildModernDropdown<String>(
          value: selectedCargo,
          width: 230,
          items: const [
            DropdownMenuItem(value: 'COMANDANTE', child: Text('COMANDANTE')),
            DropdownMenuItem(value: 'COPILOTO', child: Text('COPILOTO')),
            DropdownMenuItem(value: 'COMISSARIO', child: Text('COMISSÁRIO')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              selectedCargo = value;
              if (selectedCargo != 'COMANDANTE') gratificacaoAtiva = false;
            });
          },
        ),
      ],
    );
  }

  Widget buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blue),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyUploadBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.blue),
          SizedBox(width: 12),
          Text(
            'Nenhum arquivo selecionado.',
            style: TextStyle(color: Color(0xFF536273)),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBox() {
    final isError = importStatus != null && importStatus!.startsWith('Erro');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.06)
            : Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.25)
              : Colors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arquivo selecionado: $selectedFileName',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (selectedSheetName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Aba lida: $selectedSheetName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (importStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    importStatus!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHoleritePage() {
    final resumoFinanceiro = resumoFinanceiroPeriodoSelecionado();
    final diarias = toStringDynamicMap(resumoFinanceiro['diarias']);
    final holerite = calcularHoleriteLocal();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return buildPageShell(
      title: 'Salário',
      subtitle: selectedFileName == null
          ? 'Importe uma escala para começar.'
          : 'Cálculo do mês selecionado na escala.',
      icon: Icons.payments_outlined,
      child: ListView(
        controller: salarioScrollController,
        padding: const EdgeInsets.only(bottom: 56),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.navy : AppColors.panel,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.line,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: isDark ? 0.18 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTableToolbar(),
                  const SizedBox(height: 20),
                  buildSalaryModernPanel(holerite),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          buildDiariasResumoSection(diarias),
        ],
      ),
    );
  }

  Widget buildProfessionalHeader(Map<String, dynamic> salario) {
    final resumoFinanceiro = resumoFinanceiroPeriodoSelecionado();
    final diariasUsd = toDouble(resumoFinanceiro['total_diarias_usd']);
    final diariasUsdConvertidas = diariasUsd * cotacaoDolar;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isMobile ? 46 : 56,
              height: isMobile ? 46 : 56,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.40),
                ),
              ),
              child: Icon(
                Icons.payments_outlined,
                color: AppColors.cyan,
                size: isMobile ? 25 : 30,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simulação Crew 4U',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 24 : 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    selectedFileName == null
                        ? 'Importe uma escala para gerar a simulação.'
                        : 'Mês selecionado: ${contextoResumoSelecionado()}',
                    maxLines: isMobile ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: isMobile ? 12 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'USD/BRL:',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatarDecimal(cotacaoDolar, casas: 4),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      InkWell(
                        onTap: carregarCotacaoDolar,
                        child: Icon(
                          carregandoCotacao ? Icons.sync : Icons.refresh,
                          color: AppColors.cyan,
                          size: 17,
                        ),
                      ),
                      Text(
                        'Diárias no exterior: ${formatarMoeda(diariasUsdConvertidas, 'BRL')}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navy2],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: titleBlock,
        );
      },
    );
  }

  Widget buildHeaderMetric(
    String title,
    String value, {
    bool highlight = false,
    bool compact = false,
  }) {
    return Container(
      width: compact ? 112 : 172,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 15,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFE9FFF0)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? const Color(0xFF37A45B)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: highlight ? const Color(0xFF1F7A3F) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF1F7A3F) : Colors.white,
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTableToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Salário calculado',
              style: TextStyle(
                fontSize: isMobile ? 21 : 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMobile
                  ? 'Proventos, descontos e salário líquido.'
                  : 'Tabela operacional com proventos, base de IR, descontos e salário líquido.',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF617086),
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        final pdfButton = PrimaryButton(
          icon: Icons.picture_as_pdf_outlined,
          label: isMobile ? 'PDF' : 'Baixar PDF',
          onTap: imprimirPdfHolerite,
        );
        final monthButton = SecondaryButton(
          icon: Icons.calendar_month_outlined,
          label: contextoResumoSelecionado(),
          onTap: () => setState(() => selectedIndex = 0),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: pdfButton),
                  const SizedBox(width: 10),
                  Expanded(child: monthButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            pdfButton,
            const SizedBox(width: 10),
            monthButton,
          ],
        );
      },
    );
  }

  Map<String, dynamic> obterConfigCargo() {
    return cargoConfigs[selectedCargo] ?? cargoConfigs['COPILOTO']!;
  }

  Map<String, dynamic> calcularHoleriteLocal() {
    final config = obterConfigCargo();
    final resumoAtual = resumoFinanceiroPeriodoSelecionado();

    final kmDiurno = toDouble(resumoAtual['km_diurno']);
    final kmNoturno = toDouble(resumoAtual['km_noturno']);
    final kmFimSemana = toDouble(resumoAtual['km_fim_semana']);
    final kmFimSemanaNoturno = toDouble(resumoAtual['km_fim_semana_noturno']);
    final horasReserva = toDouble(resumoAtual['horas_reserva']);
    final horasSobreaviso = toDouble(resumoAtual['horas_sobreaviso']);

    final salarioBase = toDouble(config['salario_base']);
    final valorKmDiurno = kmDiurno * toDouble(config['km_diurno']);
    final valorKmNoturno = kmNoturno * toDouble(config['km_noturno']);
    final valorKmFimSemana = kmFimSemana * toDouble(config['km_fim_semana']);
    final valorKmFimSemanaNoturno =
        kmFimSemanaNoturno * toDouble(config['km_fim_semana_noturno']);
    final valorReserva = horasReserva * toDouble(config['hora_reserva']);
    final valorSobreaviso =
        horasSobreaviso * toDouble(config['hora_sobreaviso']);
    final valorSimulador = 0.0;

    final variaveisParaRepouso =
        valorKmDiurno +
        valorKmNoturno +
        valorKmFimSemana +
        valorKmFimSemanaNoturno +
        valorReserva +
        valorSobreaviso +
        valorSimulador;

    final repousoRemunerado = variaveisParaRepouso / 22 * 8;
    final gratificacao = gratificacaoAtiva
        ? toDouble(config['gratificacao'])
        : 0.0;

    final proventos = [
      criarProvento(
        'Salário base',
        1,
        toDouble(config['salario_base']),
        salarioBase,
      ),
      criarProvento(
        'KM Diurno',
        kmDiurno,
        toDouble(config['km_diurno']),
        valorKmDiurno,
      ),
      criarProvento(
        'KM Noturno',
        kmNoturno,
        toDouble(config['km_noturno']),
        valorKmNoturno,
      ),
      criarProvento(
        'KM Fim de Semana',
        kmFimSemana,
        toDouble(config['km_fim_semana']),
        valorKmFimSemana,
      ),
      criarProvento(
        'KM Fim de Semana NOT',
        kmFimSemanaNoturno,
        toDouble(config['km_fim_semana_noturno']),
        valorKmFimSemanaNoturno,
      ),
      criarProvento(
        'Horas Reserva',
        horasReserva,
        toDouble(config['hora_reserva']),
        valorReserva,
      ),
      criarProvento(
        'Sobreaviso',
        horasSobreaviso,
        toDouble(config['hora_sobreaviso']),
        valorSobreaviso,
      ),
      criarProvento(
        'Simulador',
        '',
        toDouble(config['hora_simulador']),
        valorSimulador,
      ),
      criarProvento('Repouso Remunerado', '', '', repousoRemunerado),
      criarProvento('Gratificação', gratificacaoAtiva, '', gratificacao),
    ];

    final totalProventos = proventos.fold<double>(
      0,
      (sum, item) => sum + toDouble(item['final']),
    );

    final inssRemuneracao = 988.07;
    final baseIr = totalProventos - inssRemuneracao;

    final descontoPrevidencia = calcularPrevidenciaPrivada(totalProventos);
    final descontoAmil = assistenciaMedicaAmil * 443.05;
    final descontoDasa = servicoSaudeDasa ? 14.90 : 0.0;
    final descontoBradesco = seguroBradescoFuneral ? 4.96 : 0.0;
    final descontoSeguroComplementar = calcularSeguroVidaComplementar(
      seguroVidaComplementar,
    );
    final descontoOdonto = calcularOdontoFamilia(assistenciaOdontoFamilia);
    final descontoGympass = calcularGympass(gympass);
    final irrfSalario = (baseIr * 0.275) - 908.73;

    final descontos = [
      criarDesconto(
        'Previdência privada',
        previdenciaPrivada,
        descontoPrevidencia,
      ),
      criarDesconto(
        'Assistência médica AMIL',
        assistenciaMedicaAmil,
        descontoAmil,
      ),
      criarDesconto('Serviço de saúde DASA', servicoSaudeDasa, descontoDasa),
      criarDesconto(
        'Seguro de Vida Bradesco Funeral',
        seguroBradescoFuneral,
        descontoBradesco,
      ),
      criarDesconto(
        'Seguro de Vida Complementar',
        seguroVidaComplementar,
        descontoSeguroComplementar,
      ),
      criarDesconto(
        'Assistência odontológica familiar',
        assistenciaOdontoFamilia,
        descontoOdonto,
      ),
      criarDesconto('Gympass', gympass, descontoGympass),
      criarDesconto('IRRF salário', '', irrfSalario),
    ];

    final descontoTotal = descontos.fold<double>(
      0,
      (sum, item) => sum + toDouble(item['valor']),
    );
    final salarioLiquido = totalProventos - descontoTotal;

    return {
      'proventos': proventos,
      'base_ir': {
        'total_proventos': totalProventos,
        'inss_remuneracao': inssRemuneracao,
        'base_ir': baseIr,
      },
      'descontos': descontos,
      'salario': {
        'proventos': totalProventos,
        'descontos': descontoTotal,
        'salario_liquido': salarioLiquido,
      },
    };
  }

  Map<String, dynamic> criarProvento(
    String descricao,
    dynamic quantidade,
    dynamic razao,
    double finalValue,
  ) {
    return {
      'descricao': descricao,
      'quantidade': quantidade,
      'razao': razao,
      'final': finalValue,
    };
  }

  Map<String, dynamic> criarDesconto(
    String descricao,
    dynamic opcao,
    double valor,
  ) {
    return {'descricao': descricao, 'opcao': opcao, 'valor': valor};
  }

  double calcularPrevidenciaPrivada(double totalProventos) {
    final percentual =
        double.tryParse(
          previdenciaPrivada.replaceAll('%', '').replaceAll(',', '.'),
        ) ??
        0;
    final config = obterConfigCargo();
    final gratificacao = gratificacaoAtiva
        ? toDouble(config['gratificacao'])
        : 0.0;
    final base = totalProventos - gratificacao;
    return base * percentual / 100;
  }

  double calcularSeguroVidaComplementar(String opcao) {
    if (opcao == 'Não utilizo' || opcao == 'Nao Utilizo') return 0;
    return double.tryParse(opcao.replaceAll(',', '.')) ?? 0;
  }

  double calcularOdontoFamilia(String opcao) {
    switch (opcao) {
      case 'Dependentes':
        return 17.63;
      case 'Dependentes + 1 Agregado':
        return 17.63 + 1 * 24.87;
      case 'Dependentes + 2 Agregados':
        return 17.63 + 2 * 24.87;
      case 'Dependentes + 3 Agregados':
        return 17.63 + 3 * 24.87;
      case 'Dependentes + 4 Agregados':
        return 17.63 + 4 * 24.87;
      case 'Dependentes + 5 Agregados':
        return 17.63 + 5 * 24.87;
      default:
        return 0;
    }
  }

  double calcularGympass(String plano) {
    switch (plano) {
      case 'Digital':
        return 0;
      case 'Starter':
        return 39.99;
      case 'Basic':
        return 69.99;
      case 'Basic+':
        return 99.99;
      case 'Silver':
        return 149.99;
      case 'Silver+':
        return 199.99;
      case 'Gold':
        return 319.99;
      case 'Gold+':
        return 439.99;
      case 'Platinum':
        return 599.99;
      case 'Diamond':
        return 699.99;
      case 'Diamond+':
        return 779.99;
      default:
        return 0;
    }
  }

  Widget buildSalaryExcelPanel(Map<String, dynamic> holerite) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy.withValues(alpha: 0.05),
                    AppColors.blue.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.swipe_outlined,
                    color: AppColors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMobile
                          ? 'Deslize a tabela para os lados.'
                          : 'Tabela no padrão operacional, com visual mais limpo.',
                      style: const TextStyle(
                        color: Color(0xFF536273),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: buildExcelHoleriteBox(holerite),
            ),
          ],
        );
      },
    );
  }

  Widget buildSalaryModernPanel(Map<String, dynamic> holerite) {
    final proventos = (holerite['proventos'] as List<dynamic>? ?? [])
        .map(toStringDynamicMap)
        .toList();
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = (holerite['descontos'] as List<dynamic>? ?? [])
        .map(toStringDynamicMap)
        .toList();
    final irrfSalario = descontos
        .where(
          (linha) => (linha['descricao']?.toString().toUpperCase() ?? '')
              .contains('IRRF SALÁRIO'),
        )
        .toList();
    final descontosSelecionaveis = descontos
        .where(
          (linha) => !(linha['descricao']?.toString().toUpperCase() ?? '')
              .contains('IRRF SALÁRIO'),
        )
        .toList();
    final salario = toStringDynamicMap(holerite['salario']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildEscalaHistoricoSelector(compactSalaryMode: true),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                buildSalarySummaryCard(
                  'Proventos',
                  formatarMoeda(salario['proventos'], 'BRL'),
                  Icons.trending_up_outlined,
                  AppColors.blue,
                  constraints.maxWidth,
                  isMobile,
                ),
                buildSalarySummaryCard(
                  'Descontos',
                  '-${formatarMoeda(salario['descontos'], 'BRL')}',
                  Icons.trending_down_outlined,
                  const Color(0xFFE53935),
                  constraints.maxWidth,
                  isMobile,
                ),
                buildSalarySummaryCard(
                  'Líquido',
                  formatarMoeda(salario['salario_liquido'], 'BRL'),
                  Icons.account_balance_wallet_outlined,
                  AppColors.green,
                  constraints.maxWidth,
                  isMobile,
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            buildModernSectionTitle(
              'Proventos',
              'Valores calculados a partir da escala importada.',
            ),
            const SizedBox(height: 8),
            ...proventos.map(
              (linha) => buildModernSalaryLine(
                title: linha['descricao']?.toString() ?? '',
                subtitle: buildProventoSubtitle(linha),
                value: formatarMoeda(linha['final'], 'BRL'),
                icon: iconForProvento(linha['descricao']?.toString() ?? ''),
                accent: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            buildModernSectionTitle(
              'Base de IR',
              'Base tributável usada para calcular o IRRF.',
            ),
            const SizedBox(height: 8),
            buildModernSalaryLine(
              title: 'Total de proventos',
              subtitle: 'Soma bruta calculada',
              value: formatarMoeda(baseIr['total_proventos'], 'BRL'),
              icon: Icons.add_chart_outlined,
              accent: AppColors.blue,
            ),
            buildModernSalaryLine(
              title: 'INSS remuneração',
              subtitle: 'Desconto previdenciário aplicado',
              value: '-${formatarMoeda(baseIr['inss_remuneracao'], 'BRL')}',
              icon: Icons.remove_circle_outline,
              accent: const Color(0xFFE53935),
            ),
            buildModernSalaryLine(
              title: 'Base de IR',
              subtitle: 'Total após INSS',
              value: formatarMoeda(baseIr['base_ir'], 'BRL'),
              icon: Icons.receipt_long_outlined,
              accent: AppColors.cyan,
            ),
            ...irrfSalario.map(
              (linha) => buildModernSalaryLine(
                title: linha['descricao']?.toString() ?? 'IRRF salário',
                subtitle: 'Calculado pela base de IR',
                value: '-${formatarMoeda(linha['valor'], 'BRL')}',
                icon: Icons.account_balance_outlined,
                accent: const Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 12),
            buildModernSectionTitle(
              'Descontos',
              'Ajuste os benefícios e confira o impacto no líquido.',
            ),
            const SizedBox(height: 8),
            ...descontosSelecionaveis.map(
              (linha) => buildModernDiscountLine(linha),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.green.withValues(alpha: isDark ? 0.18 : 0.14),
                        AppColors.cyan.withValues(alpha: isDark ? 0.12 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Salário líquido estimado',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        formatarMoeda(salario['salario_liquido'], 'BRL'),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildSalaryInsightStrip(
    List<Map<String, dynamic>> proventos,
    List<Map<String, dynamic>> descontos,
    Map<String, dynamic> salario,
  ) {
    Map<String, dynamic> maiorProvento = {};
    Map<String, dynamic> maiorDesconto = {};
    for (final item in proventos) {
      if (toDouble(item['final']) > toDouble(maiorProvento['final'])) {
        maiorProvento = item;
      }
    }
    for (final item in descontos) {
      if (toDouble(item['valor']) > toDouble(maiorDesconto['valor'])) {
        maiorDesconto = item;
      }
    }

    final proventosTotal = toDouble(salario['proventos']);
    final liquido = toDouble(salario['salario_liquido']);
    final percentualLiquido = proventosTotal <= 0
        ? 0.0
        : (liquido / proventosTotal * 100).clamp(0, 100).toDouble();

    Widget chip(IconData icon, String label, String value, Color accent) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF617086),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 760;
        final items = [
          chip(
            Icons.bolt_outlined,
            'Maior provento',
            maiorProvento['descricao']?.toString() ?? '-',
            AppColors.blue,
          ),
          chip(
            Icons.remove_circle_outline,
            'Maior desconto',
            maiorDesconto['descricao']?.toString() ?? '-',
            const Color(0xFFE53935),
          ),
          chip(
            Icons.percent_outlined,
            'Líquido sobre bruto',
            '${formatarDecimal(percentualLiquido, casas: 1)}%',
            AppColors.green,
          ),
        ];

        if (mobile) {
          return Column(
            children:
                items
                    .expand((item) => [item, const SizedBox(height: 8)])
                    .toList()
                  ..removeLast(),
          );
        }

        return Row(
          children:
              items
                  .expand(
                    (item) => [
                      Expanded(child: item),
                      const SizedBox(width: 10),
                    ],
                  )
                  .toList()
                ..removeLast(),
        );
      },
    );
  }

  Widget buildSalarySummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double maxWidth,
    bool isMobile, {
    bool highlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = isMobile
        ? maxWidth
        : ((maxWidth - 28) / 3).clamp(190.0, 330.0);
    final panelColor = isDark ? AppColors.navy2 : const Color(0xFFF7FAFE);
    final textColor = isDark ? Colors.white : AppColors.navy;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : AppColors.navy.withValues(alpha: 0.55);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: isDark ? 0.16 : 0.10)
            : panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.28 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: highlight ? color : textColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModernSectionTitle(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.58)
                : const Color(0xFF6A778A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildModernSalaryLine({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF8FBFF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE4ECF6);
    final textColor = isDark ? Colors.white : AppColors.navy;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : const Color(0xFF728096);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModernDiscountLine(Map<String, dynamic> linha) {
    final label = linha['descricao']?.toString() ?? '';
    final value = formatarMoeda(linha['valor'], 'BRL');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = const Color(0xFFE53935);
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFFFFBFB);
    final borderColor = isDark
        ? danger.withValues(alpha: 0.18)
        : const Color(0xFFF0E2E2);
    final textColor = isDark ? Colors.white : AppColors.navy;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          final controlWidth = mobile ? constraints.maxWidth : 220.0;
          final control = buildModernDiscountControl(label, controlWidth);
          final left = Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.payments_outlined, color: danger, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 4),
                control,
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 8),
              control,
              const SizedBox(width: 8),
              SizedBox(
                width: 105,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildModernDiscountControl(String label, double width) {
    if (label == 'Previdência privada') {
      return modernDropdownControl<String>(
        width: width,
        value: previdenciaPrivada,
        items: const [
          'Não utilizo',
          '0%',
          '1%',
          '2%',
          '3%',
          '4%',
          '5%',
          '6%',
          '7%',
          '8%',
          '9%',
          '10%',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => previdenciaPrivada = value);
        },
      );
    }

    if (label == 'Assistência médica AMIL') {
      return modernDropdownControl<int>(
        width: width,
        value: assistenciaMedicaAmil,
        items: const [0, 1, 2, 3, 4, 5],
        itemLabel: (value) => '$value vidas',
        onChanged: (value) {
          if (value == null) return;
          setState(() => assistenciaMedicaAmil = value);
        },
      );
    }

    if (label == 'Serviço de saúde DASA') {
      return modernSwitchControl(
        width: width,
        value: servicoSaudeDasa,
        onChanged: (value) => setState(() => servicoSaudeDasa = value),
      );
    }

    if (label == 'Seguro de Vida Bradesco Funeral') {
      return modernSwitchControl(
        width: width,
        value: seguroBradescoFuneral,
        onChanged: (value) => setState(() => seguroBradescoFuneral = value),
      );
    }

    if (label == 'Seguro de Vida Complementar') {
      return modernDropdownControl<String>(
        width: width,
        value: seguroVidaComplementar,
        items: const [
          'Não utilizo',
          '39.93',
          '79.86',
          '119.79',
          '159.72',
          '199.65',
          '239.58',
          '279.51',
          '319.44',
          '359.37',
          '399.30',
        ],
        itemLabel: (value) => value == 'Não utilizo'
            ? value
            : 'R\$ ${value.replaceAll('.', ',')}',
        onChanged: (value) {
          if (value == null) return;
          setState(() => seguroVidaComplementar = value);
        },
      );
    }

    if (label == 'Assistência odontológica familiar') {
      return modernDropdownControl<String>(
        width: width,
        value: assistenciaOdontoFamilia,
        items: const [
          'Não utilizo',
          'Dependentes',
          'Dependentes + 1 Agregado',
          'Dependentes + 2 Agregados',
          'Dependentes + 3 Agregados',
          'Dependentes + 4 Agregados',
          'Dependentes + 5 Agregados',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => assistenciaOdontoFamilia = value);
        },
      );
    }

    if (label == 'Gympass') {
      return modernDropdownControl<String>(
        width: width,
        value: gympass,
        items: const [
          'Não utilizo',
          'Digital',
          'Starter',
          'Basic',
          'Basic+',
          'Silver',
          'Silver+',
          'Gold',
          'Gold+',
          'Platinum',
          'Diamond',
          'Diamond+',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => gympass = value);
        },
      );
    }

    return SizedBox(
      width: width,
      child: Text(
        formatarOpcaoDesconto(''),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : AppColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget modernSwitchControl({
    required double width,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : AppColors.softBlue;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.blue.withValues(alpha: 0.16);

    return SizedBox(
      width: width,
      height: 34,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? AppColors.green : Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: value
                        ? AppColors.green
                        : Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: value
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                value ? 'Ativo' : 'Não uso',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget modernDropdownControl<T>({
    required double width,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    String Function(T value)? itemLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : AppColors.softBlue;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.blue.withValues(alpha: 0.16);
    final textColor = isDark ? Colors.white : AppColors.navy;

    return Container(
      width: width,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.navy2 : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: textColor, size: 17),
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel == null ? item.toString() : itemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String buildProventoSubtitle(Map<String, dynamic> linha) {
    final quantidade = formatarQuantidadeOuTexto(linha['quantidade']);
    final razao = formatarRazao(linha['razao']);
    if (quantidade.isEmpty && razao.isEmpty) return '';
    if (quantidade.isEmpty) return 'Razão $razao';
    if (razao.isEmpty) return 'Quantidade $quantidade';
    return 'Quantidade $quantidade • Razão $razao';
  }

  IconData iconForProvento(String descricao) {
    final text = descricao.toUpperCase();
    if (text.contains('SALÁRIO') || text.contains('SALARIO')) {
      return Icons.badge_outlined;
    }
    if (text.contains('KM')) return Icons.route_outlined;
    if (text.contains('RESERVA')) return Icons.event_available_outlined;
    if (text.contains('SOBREAVISO')) return Icons.notifications_none_outlined;
    if (text.contains('REPOUSO')) return Icons.hotel_outlined;
    if (text.contains('GRAT')) return Icons.star_outline;
    if (text.contains('SIMULADOR')) return Icons.flight_class_outlined;
    return Icons.add_circle_outline;
  }

  Widget buildExcelHoleriteBox(Map<String, dynamic> holerite) {
    final proventos = holerite['proventos'] as List<dynamic>;
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = holerite['descontos'] as List<dynamic>;
    final salario = toStringDynamicMap(holerite['salario']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: 850,
        child: Column(
          children: [
            excelTitleRow('SIMULAÇÃO CREW 4U'),
            excelSectionRow('PROVENTOS'),
            excelHeaderRow(['', 'QUANTIDADE', 'RAZAO', 'FINAL']),
            ...proventos.map((item) {
              final linha = toStringDynamicMap(item);

              return excelDataRow([
                linha['descricao']?.toString() ?? '',
                formatarQuantidadeOuTexto(linha['quantidade']),
                formatarRazao(linha['razao']),
                formatarMoeda(linha['final'], 'BRL'),
              ]);
            }),
            excelTotalRow(
              'TOTAL PROVENTOS',
              formatarMoeda(salario['proventos'], 'BRL'),
            ),
            excelBlankRow(),
            excelSectionRow('BASE DE IR'),
            excelTwoColumnRow(
              'Total Proventos',
              formatarMoeda(baseIr['total_proventos'], 'BRL'),
            ),
            excelTwoColumnRow(
              'INSS Remuneração',
              '-${formatarMoeda(baseIr['inss_remuneracao'], 'BRL')}',
            ),
            excelTotalRow(
              'Base de IR',
              formatarMoeda(baseIr['base_ir'], 'BRL'),
            ),
            excelBlankRow(),
            excelSectionRow('DESCONTOS'),
            ...descontos.map((item) {
              final linha = toStringDynamicMap(item);

              return excelDiscountRow(
                linha['descricao']?.toString() ?? '',
                linha['opcao'],
                formatarMoeda(linha['valor'], 'BRL'),
              );
            }),
            excelTotalRow(
              'DESCONTO TOTAL',
              formatarMoeda(salario['descontos'], 'BRL'),
            ),
            excelBlankRow(),
            excelSectionRow('SALARIO'),
            excelTwoColumnRow(
              'Proventos',
              formatarMoeda(salario['proventos'], 'BRL'),
            ),
            excelTwoColumnRow(
              'Descontos',
              '-${formatarMoeda(salario['descontos'], 'BRL')}',
            ),
            excelSalaryLiquidRow(
              formatarMoeda(salario['salario_liquido'], 'BRL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget excelTitleRow(String text) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.navy, AppColors.blue]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget excelSectionRow(String text) {
    return Container(
      height: 37,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        border: Border.all(color: AppColors.navy, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget excelHeaderRow(List<String> values) {
    return Row(
      children: [
        excelCell(values[0], width: 310, bold: true, center: true),
        excelCell(values[1], width: 185, bold: true, center: true),
        excelCell(values[2], width: 195, bold: true, center: true),
        excelCell(values[3], width: 160, bold: true, center: true),
      ],
    );
  }

  Widget excelDataRow(List<String> values) {
    final isGratificacao = values[0] == 'Gratificação';

    return Row(
      children: [
        excelCell(values[0], width: 310, bold: true, align: TextAlign.left),
        isGratificacao
            ? excelGratificacaoCell(width: 185)
            : excelCell(values[1], width: 185),
        excelCell(values[2], width: 195),
        excelCell(values[3], width: 160),
      ],
    );
  }

  Widget excelGratificacaoCell({required double width}) {
    final config = obterConfigCargo();
    final valorGratificacao = toDouble(config['gratificacao']);
    final valorTexto = formatarMoeda(valorGratificacao, 'BRL');

    return InkWell(
      onTap: () {
        setState(() {
          gratificacaoAtiva = !gratificacaoAtiva;
        });
      },
      child: Container(
        width: width,
        height: 35,
        decoration: BoxDecoration(
          color: gratificacaoAtiva ? AppColors.softBlue : AppColors.inputCell,
          border: Border.all(
            color: gratificacaoAtiva ? AppColors.blue : Colors.black26,
            width: gratificacaoAtiva ? 1.6 : 0.7,
          ),
        ),
        alignment: Alignment.center,
        child: Tooltip(
          message: valorGratificacao > 0
              ? 'Gratificação $valorTexto ${gratificacaoAtiva ? 'ativada' : 'desativada'}'
              : 'Gratificação sem valor para este cargo. O botão fica clicável apenas para simulação visual.',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: gratificacaoAtiva,
                activeColor: AppColors.blue,
                onChanged: (value) {
                  setState(() {
                    gratificacaoAtiva = value ?? false;
                  });
                },
              ),
              Text(
                gratificacaoAtiva ? 'SIM' : 'NÃO',
                style: TextStyle(
                  color: gratificacaoAtiva ? AppColors.blue : Colors.black54,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget excelTwoColumnRow(String label, String value) {
    return Row(
      children: [
        excelCell(label, width: 640, bold: false, align: TextAlign.left),
        excelCell(value, width: 210, bold: true),
      ],
    );
  }

  Widget excelDiscountRow(String label, dynamic option, String value) {
    return Row(
      children: [
        excelCell(label, width: 395, bold: true, align: TextAlign.left),
        excelDiscountOptionCell(label, option, width: 245),
        excelCell(value, width: 210, bold: true),
      ],
    );
  }

  Widget excelDiscountOptionCell(
    String label,
    dynamic option, {
    required double width,
  }) {
    if (label == 'Previdência privada') {
      return excelDropdownCell<String>(
        width: width,
        value: previdenciaPrivada,
        items: const [
          '0%',
          '1%',
          '2%',
          '3%',
          '4%',
          '5%',
          '6%',
          '7%',
          '8%',
          '9%',
          '10%',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => previdenciaPrivada = value);
        },
      );
    }

    if (label == 'Assistência médica AMIL') {
      return excelDropdownCell<int>(
        width: width,
        value: assistenciaMedicaAmil,
        items: const [0, 1, 2, 3, 4, 5],
        itemLabel: (value) => value.toString(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => assistenciaMedicaAmil = value);
        },
      );
    }

    if (label == 'Serviço de saúde DASA') {
      return excelCheckboxCell(
        width: width,
        value: servicoSaudeDasa,
        onChanged: (value) => setState(() => servicoSaudeDasa = value ?? false),
      );
    }

    if (label == 'Seguro de Vida Bradesco Funeral') {
      return excelCheckboxCell(
        width: width,
        value: seguroBradescoFuneral,
        onChanged: (value) =>
            setState(() => seguroBradescoFuneral = value ?? false),
      );
    }

    if (label == 'Seguro de Vida Complementar') {
      return excelDropdownCell<String>(
        width: width,
        value: seguroVidaComplementar,
        items: const [
          'Não utilizo',
          '39.93',
          '79.86',
          '119.79',
          '159.72',
          '199.65',
          '239.58',
          '279.51',
          '319.44',
          '359.37',
          '399.30',
        ],
        itemLabel: (value) => value == 'Não utilizo'
            ? value
            : 'R\$ ${value.replaceAll('.', ',')}',
        onChanged: (value) {
          if (value == null) return;
          setState(() => seguroVidaComplementar = value);
        },
      );
    }

    if (label == 'Assistência odontológica familiar') {
      return excelDropdownCell<String>(
        width: width,
        value: assistenciaOdontoFamilia,
        items: const [
          'Não utilizo',
          'Dependentes',
          'Dependentes + 1 Agregado',
          'Dependentes + 2 Agregados',
          'Dependentes + 3 Agregados',
          'Dependentes + 4 Agregados',
          'Dependentes + 5 Agregados',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => assistenciaOdontoFamilia = value);
        },
      );
    }

    if (label == 'Gympass') {
      return excelDropdownCell<String>(
        width: width,
        value: gympass,
        items: const [
          'Não utilizo',
          'Digital',
          'Starter',
          'Basic',
          'Basic+',
          'Silver',
          'Silver+',
          'Gold',
          'Gold+',
          'Platinum',
          'Diamond',
          'Diamond+',
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => gympass = value);
        },
      );
    }

    return excelCell(formatarOpcaoDesconto(option), width: width);
  }

  Widget excelDropdownCell<T>({
    required double width,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    String Function(T value)? itemLabel,
  }) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.inputCell,
        border: Border.all(color: Colors.black26, width: 0.7),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            iconSize: 16,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel == null ? item.toString() : itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget excelCheckboxCell({
    required double width,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.inputCell,
        border: Border.all(color: Colors.black26, width: 0.7),
      ),
      alignment: Alignment.center,
      child: Checkbox(
        value: value,
        activeColor: AppColors.blue,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: onChanged,
      ),
    );
  }

  Widget excelTotalRow(String label, String value) {
    return Row(
      children: [
        excelCell(label, width: 640, bold: true, center: true),
        excelCell(value, width: 210, bold: true),
      ],
    );
  }

  Widget excelBlankRow() {
    return Container(
      height: 29,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.navy, width: 1.2),
      ),
    );
  }

  Widget excelSalaryLiquidRow(String value) {
    return Row(
      children: [
        Container(
          width: 640,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F7ED),
            border: Border.all(color: AppColors.green, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text(
            'SALARIO LIQUIDO',
            style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          width: 210,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F7ED),
            border: Border.all(color: AppColors.green, width: 2),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget excelCell(
    String text, {
    required double width,
    bool bold = false,
    TextAlign align = TextAlign.right,
    bool center = false,
  }) {
    final effectiveAlignment = center
        ? Alignment.center
        : align == TextAlign.left
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      width: width,
      height: 35,
      decoration: BoxDecoration(
        color: AppColors.cell,
        border: Border.all(color: Colors.black26, width: 0.7),
      ),
      alignment: effectiveAlignment,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : align,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildModernDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required double width,
  }) {
    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppColors.navy,
          iconEnabledColor: Colors.white,
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String formatarQuantidadeOuTexto(dynamic valor) {
    if (valor == null) return '';
    if (valor is bool) return valor ? '☑' : '☐';
    if (valor is String) return valor;
    final numero = double.tryParse(valor.toString());
    if (numero == null) return valor.toString();
    if (numero == 0) return '0,00';
    if (numero % 1 == 0) return numero.toInt().toString();
    return numero.toStringAsFixed(2).replaceAll('.', ',');
  }

  String formatarRazao(dynamic valor) {
    if (valor == null) return '';
    if (valor is String) return valor;
    final numero = double.tryParse(valor.toString());
    if (numero == null) return valor.toString();
    if (numero == 0) return '0';
    if (numero >= 1) return numero.toStringAsFixed(2).replaceAll('.', ',');
    return numero.toStringAsFixed(6).replaceAll('.', ',');
  }

  String formatarOpcaoDesconto(dynamic value) {
    if (value == null) return '';
    if (value == true) return '☑';
    if (value == false) return '☐';
    return value.toString();
  }

  Widget buildValidatorSection() {
    final inconsistencias = coletarInconsistencias();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.navy;
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF536273);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navy : AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  inconsistencias.isEmpty
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  color: inconsistencias.isEmpty
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 10),
                Text(
                  'Validador da escala',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (inconsistencias.isEmpty)
              Text(
                'Nenhuma inconsistência crítica encontrada na importação atual.',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: inconsistencias.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: textColor)),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  List<String> coletarInconsistencias() {
    final problemas = <String>[];
    final voosSemDistancia =
        (resumo['voos_sem_distancia'] as List<dynamic>? ?? []);

    if (voosSemDistancia.isNotEmpty) {
      problemas.add(
        'Existem voos sem distância calculada: ${voosSemDistancia.join(', ')}.',
      );
    }

    if (escalaEventos.isEmpty && selectedFileName != null) {
      problemas.add('O arquivo foi importado, mas nenhum evento foi tratado.');
    }

    final eventosSemStatus = escalaEventos
        .where((event) => (event['status'] ?? '').trim().isEmpty)
        .length;
    if (eventosSemStatus > 0) {
      problemas.add('$eventosSemStatus eventos estão sem status.');
    }

    final semDutyReport = escalaEventos
        .where(
          (event) =>
              event['tipo'] == 'VOO' &&
              (event['duty_report'] ?? '').trim().isEmpty &&
              (event['cafe'] == 'SIM' ||
                  event['almoco'] == 'SIM' ||
                  event['jantar'] == 'SIM' ||
                  event['ceia'] == 'SIM'),
        )
        .length;

    if (semDutyReport > 0) {
      problemas.add(
        '$semDutyReport linhas possuem diária marcada sem Duty Report visível.',
      );
    }

    return problemas;
  }

  Widget buildHistorySection() {
    if (historicoImportacoes.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico da Sessão',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.softBlue),
                columns: const [
                  DataColumn(label: Text('Arquivo')),
                  DataColumn(label: Text('Cargo')),
                  DataColumn(label: Text('Voos')),
                  DataColumn(label: Text('Eventos')),
                  DataColumn(label: Text('Proventos')),
                  DataColumn(label: Text('Descontos')),
                  DataColumn(label: Text('Líquido')),
                ],
                rows: historicoImportacoes.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item['arquivo']?.toString() ?? '')),
                      DataCell(Text(item['cargo']?.toString() ?? '')),
                      DataCell(Text(item['voos']?.toString() ?? '0')),
                      DataCell(Text(item['eventos']?.toString() ?? '0')),
                      DataCell(Text(formatarMoeda(item['proventos'], 'BRL'))),
                      DataCell(Text(formatarMoeda(item['descontos'], 'BRL'))),
                      DataCell(Text(formatarMoeda(item['liquido'], 'BRL'))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDiariasResumoSection(Map<String, dynamic> diarias) {
    if (diarias.isEmpty) return const SizedBox.shrink();

    final grupos = ['NACIONAL', 'ARGENTINA', 'CHILE', 'AMERICA_DO_SUL'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(colors: [AppColors.navy, AppColors.navy2])
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFEAF5FF)],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.blue.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo de Diárias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mês: ${contextoResumoSelecionado()}. Conta refeições dentro da jornada, com café a 25% e almoço, jantar e ceia pelo valor integral.',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.58)
                    : const Color(0xFF617086),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 430
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: grupos.map((grupo) {
                    final dadosGrupo = toStringDynamicMap(diarias[grupo]);
                    final moeda =
                        dadosGrupo['moeda']?.toString() ??
                        obterMoedaPadraoDoGrupo(grupo);

                    return buildDiariaResumoCard(
                      grupo: grupo,
                      dadosGrupo: dadosGrupo,
                      moeda: moeda,
                      width: cardWidth,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDiariaResumoCard({
    required String grupo,
    required Map<String, dynamic> dadosGrupo,
    required String moeda,
    required double width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.navy;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : const Color(0xFF617086);
    final refeicoes = [
      ['Café', 'cafe'],
      ['Almoço', 'almoco'],
      ['Jantar', 'jantar'],
      ['Ceia', 'ceia'],
    ];

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0xFFE2ECF7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatarGrupo(grupo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatarMoeda(dadosGrupo['total'], moeda),
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...refeicoes.map((item) {
            final dados = toStringDynamicMap(dadosGrupo[item[1]]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item[0],
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${dados['quantidade'] ?? 0}x',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 66,
                    child: Text(
                      formatarMoeda(dados['valor_total'], moeda),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildTabelaGrupoDiaria({
    required String grupo,
    required Map<String, dynamic> dadosGrupo,
    required String moeda,
  }) {
    return SizedBox(
      width: 370,
      child: Table(
        border: TableBorder.all(color: AppColors.navy, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.4),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8F4FF)),
            children: [
              tableHeaderCell('Diárias de Voo ${formatarGrupo(grupo)}'),
              tableCell(''),
              tableCell(''),
            ],
          ),
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade300),
            children: [
              tableCell(''),
              tableHeaderCell('Quantidade'),
              tableHeaderCell('Valor'),
            ],
          ),
          diariaRow('Café da Manhã', dadosGrupo, 'cafe', moeda),
          diariaRow('Almoço', dadosGrupo, 'almoco', moeda),
          diariaRow('Jantar', dadosGrupo, 'jantar', moeda),
          diariaRow('Ceia', dadosGrupo, 'ceia', moeda),
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade300),
            children: [
              tableHeaderCell('TOTAL'),
              tableCell(''),
              tableHeaderCell(formatarMoeda(dadosGrupo['total'], moeda)),
            ],
          ),
        ],
      ),
    );
  }

  TableRow diariaRow(
    String titulo,
    Map<String, dynamic> grupo,
    String refeicao,
    String moeda,
  ) {
    final dados = toStringDynamicMap(grupo[refeicao]);

    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade300),
      children: [
        tableHeaderCell(titulo),
        tableCell(dados['quantidade']?.toString() ?? '0'),
        tableCell(formatarMoeda(dados['valor_total'], moeda)),
      ],
    );
  }

  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.navy,
        ),
      ),
    );
  }

  String obterMoedaPadraoDoGrupo(String grupo) {
    if (grupo == 'NACIONAL' || grupo == 'Nacional') return 'BRL';
    return 'USD';
  }

  String formatarMoedaNome(String moeda) {
    if (moeda == 'BRL') return 'R\$';
    if (moeda == 'USD') return 'US\$';
    return moeda;
  }

  String formatarMoeda(dynamic valor, String moeda) {
    if (valor == null) return moeda == 'BRL' ? 'R\$ 0,00' : 'US\$ 0,00';

    final numero = double.tryParse(valor.toString());
    if (numero == null) return valor.toString();

    final valorFormatado = numero.toStringAsFixed(2).replaceAll('.', ',');

    if (moeda == 'BRL') return 'R\$ $valorFormatado';
    return 'US\$ $valorFormatado';
  }

  String formatarDecimal(double valor, {int casas = 2}) {
    return valor.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String formatarGrupo(String grupo) {
    switch (grupo) {
      case 'NACIONAL':
        return 'Nacional';
      case 'ARGENTINA':
        return 'Argentina';
      case 'CHILE':
        return 'Chile';
      case 'AMERICA_DO_SUL':
        return 'América do Sul';
      default:
        return grupo;
    }
  }

  Widget buildEscalaDashboardPage() {
    final eventos = eventosPrincipaisDaEscala();
    agendarAutoScrollEscala(eventos);

    return buildPageShell(
      title: 'Escala',
      subtitle: selectedFileName == null
          ? 'Importe sua escala mensal para acompanhar seus voos.'
          : 'Última escala importada: $selectedFileName',
      icon: Icons.flight_takeoff_outlined,
      child: Column(
        children: [
          if (mostrarUploadSuccess) ...[
            buildUploadSuccessBanner(),
            const SizedBox(height: 10),
          ],
          buildEscalaFloatingSummaryBar(),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              controller: escalaScrollController,
              padding: const EdgeInsets.only(bottom: 56),
              children: [
                if (eventos.isEmpty)
                  buildEscalaEmptyState()
                else
                  buildEscalaTimeline(eventos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUploadSuccessBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF123A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.44)),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedFileName == null
                  ? 'Escala importada com sucesso.'
                  : 'Escala importada com sucesso: $selectedFileName',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Fechar aviso',
            onPressed: () => setState(() => mostrarUploadSuccess = false),
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget buildEscalaFloatingSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [buildEscalaResumoRapido()]),
    );
  }

  void atualizarMesResumoPeloScroll() {
    if (escalaDiaKeys.isEmpty) return;

    String? melhorData;
    var melhorDistancia = double.infinity;
    for (final entry in escalaDiaKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      final distancia = (y - 190).abs();
      if (distancia < melhorDistancia) {
        melhorDistancia = distancia;
        melhorData = entry.key;
      }
    }

    final data = melhorData == null ? null : parseDataPtBr(melhorData);
    if (data == null) return;
    final mesKey = '${data.year}-${data.month.toString().padLeft(2, '0')}';
    if (mesKey == escalaMesResumoKey) return;
    setState(() => escalaMesResumoKey = mesKey);
  }

  Widget buildEscalaWelcomeCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;

        final mainContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: isMobile ? 28 : 34,
              width: isMobile ? 112 : 132,
              child: Image.asset(
                'assets/logo_crew4u.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) {
                  return buildTextLogo(
                    fontSize: isMobile ? 23 : 25,
                    fourSize: isMobile ? 34 : 39,
                    dark: false,
                  );
                },
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Olá, ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 26 : 30,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Rafael',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: isMobile ? 26 : 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              selectedFileName == null
                  ? 'Importe sua escala para visualizar a rotina de voo.'
                  : 'Sua escala está pronta para consulta offline no navegador. A aba Salário usa estes dados para calcular o holerite.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        );

        final monthPill = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                mesReferenciaEscala(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        );

        return Container(
          padding: EdgeInsets.all(isMobile ? 18 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF020817), Color(0xFF071A34), Color(0xFF041126)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.13),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: isMobile ? -54 : -18,
                bottom: isMobile ? -48 : -52,
                child: Opacity(
                  opacity: 0.035,
                  child: SizedBox(
                    width: isMobile ? 190 : 280,
                    height: isMobile ? 120 : 176,
                    child: Image.asset(
                      'assets/logo_crew4u.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.flight_takeoff,
                          size: isMobile ? 110 : 155,
                          color: AppColors.cyan,
                        );
                      },
                    ),
                  ),
                ),
              ),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mainContent,
                        const SizedBox(height: 12),
                        monthPill,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: mainContent),
                        const SizedBox(width: 18),
                        monthPill,
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget buildEscalaMesCompactSelector() {
    final meses = mesesHistoricoOrdenados();
    final mesAtual = selectedEscalaMesKey ?? mesKeyDosEventos(escalaEventos);
    final temHistorico = meses.isNotEmpty;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.cyan,
            size: 14,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    temHistorico && mesAtual != null && meses.contains(mesAtual)
                    ? mesAtual
                    : null,
                hint: Text(
                  mesAtual == null ? 'Nenhum mês salvo' : labelMesKey(mesAtual),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                dropdownColor: AppColors.navy2,
                iconEnabledColor: Colors.white70,
                isDense: true,
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
                items: meses
                    .map(
                      (mes) => DropdownMenuItem(
                        value: mes,
                        child: Text(labelMesKey(mes)),
                      ),
                    )
                    .toList(),
                onChanged: temHistorico
                    ? (mes) {
                        if (mes == null) return;
                        final dados = escalaHistoricoMensal[mes] ?? {};
                        final tipo = dados[selectedEscalaTipo] != null
                            ? selectedEscalaTipo
                            : dados['executada'] != null
                            ? 'executada'
                            : 'planejada';
                        selecionarEscalaHistorico(mes, tipo);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            selectedEscalaTipo == 'planejada' ? 'Planejada' : 'Executada',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProximaAtividadeCard(List<Map<String, String>> eventos) {
    if (eventos.isEmpty) return const SizedBox.shrink();

    final agora = DateTime.now();
    final ordenados = [...eventos]
      ..sort((a, b) {
        final dataA =
            inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
        final dataB =
            inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
        return dataA.compareTo(dataB);
      });

    Map<String, String> alvo = ordenados.first;
    for (final event in ordenados) {
      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) continue;
      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;
      if (!fimEfetivo.isBefore(agora)) {
        alvo = event;
        break;
      }
    }

    final tipo = (alvo['tipo'] ?? '').toUpperCase();
    final isFolga = ehFolgaOuDayOff(alvo);
    final inicio = inicioEventoDateTime(alvo);
    final fim = fimEventoDateTime(alvo);
    final origem = alvo['origem'] ?? '';
    final destino = alvo['destino'] ?? '';
    final id = alvo['identificacao'] ?? '';
    final dutyReport = horarioLimpo(alvo['duty_report'] ?? '');
    final title = isFolga
        ? 'Dia livre'
        : tipo == 'VOO'
        ? '$origem → $destino'
        : tipo.contains('RESERVA')
        ? 'Reserva $id'
        : tipo.contains('SOBREAVISO')
        ? 'Sobreaviso $id'
        : id;
    final subtitle = isFolga
        ? 'Folga confirmada na escala'
        : dutyReport.isNotEmpty
        ? 'Apresentação $dutyReport'
        : formatarIntervaloEvento(
            limparHoraParaExibicao(alvo['saida'] ?? ''),
            limparHoraParaExibicao(alvo['chegada'] ?? ''),
          );
    final tempo = textoTempoAteAtividade(inicio, fim);
    final accent = isFolga
        ? AppColors.green
        : tipo == 'VOO'
        ? AppColors.blue
        : tipo.contains('RESERVA')
        ? const Color(0xFFE53935)
        : const Color(0xFFF6B21A);
    final icon = isFolga
        ? Icons.weekend_outlined
        : tipo == 'VOO'
        ? Icons.flight_takeoff_outlined
        : tipo.contains('RESERVA')
        ? Icons.event_available_outlined
        : Icons.notifications_active_outlined;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 44 : 50,
                height: isMobile ? 44 : 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Icon(icon, color: accent, size: isMobile ? 23 : 26),
              ),
              SizedBox(width: isMobile ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agora / Próxima atividade',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 18 : 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  tempo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildEscalaHistoricoSelector({bool compactSalaryMode = false}) {
    final meses = mesesHistoricoOrdenados();
    final mesAtual = selectedEscalaMesKey;
    final mesSelecionado = mesAtual != null && meses.contains(mesAtual)
        ? mesAtual
        : (meses.isNotEmpty ? meses.first : null);
    final dadosMes = escalaHistoricoMensal[mesSelecionado] ?? {};
    final temPlanejada = dadosMes['planejada'] != null;
    final temExecutada = dadosMes['executada'] != null;
    final comparativo = textoComparativoPlanejadaExecutada(dadosMes);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        return Container(
          padding: EdgeInsets.all(compactSalaryMode ? 7 : (isMobile ? 10 : 12)),
          decoration: BoxDecoration(
            color: compactSalaryMode
                ? const Color(0xFF071A34)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(compactSalaryMode ? 16 : 22),
            border: Border.all(
              color: compactSalaryMode
                  ? AppColors.cyan.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: compactSalaryMode
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  buildMesHistoricoDropdown(meses, mesSelecionado),
                  SizedBox(width: isMobile ? 0 : 8, height: isMobile ? 6 : 0),
                  buildTipoEscalaSlider(
                    temPlanejada: temPlanejada,
                    temExecutada: temExecutada,
                  ),
                ],
              ),
              if (comparativo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.compare_arrows_outlined,
                      color: AppColors.cyan,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comparativo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget buildMesHistoricoDropdown(List<String> meses, String? mesSelecionado) {
    final enabled = meses.isNotEmpty;
    final fallbackMes = selectedEscalaMesKey ?? mesKeyDosEventos(escalaEventos);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: enabled ? mesSelecionado : null,
          hint: Text(
            fallbackMes == null
                ? 'Nenhum mês salvo'
                : '${labelMesKey(fallbackMes)} não salvo',
          ),
          dropdownColor: AppColors.navy2,
          iconEnabledColor: Colors.white70,
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          items: meses.map((mes) {
            return DropdownMenuItem(value: mes, child: Text(labelMesKey(mes)));
          }).toList(),
          onChanged: enabled
              ? (mes) {
                  if (mes == null) return;
                  final dados = escalaHistoricoMensal[mes] ?? {};
                  final tipo = dados[selectedEscalaTipo] != null
                      ? selectedEscalaTipo
                      : dados['executada'] != null
                      ? 'executada'
                      : 'planejada';
                  selecionarEscalaHistorico(mes, tipo);
                }
              : null,
        ),
      ),
    );
  }

  Widget buildTipoEscalaSlider({
    required bool temPlanejada,
    required bool temExecutada,
  }) {
    final selectedExecutada = selectedEscalaTipo == 'executada';
    final enabled =
        selectedEscalaMesKey != null && (temPlanejada || temExecutada);

    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 188, maxWidth: 240),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: selectedExecutada
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: enabled
                      ? const LinearGradient(
                          colors: [Color(0xFF0F7DFF), Color(0xFF24D6FF)],
                        )
                      : null,
                  color: enabled ? null : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.34),
                            blurRadius: 12,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
          Row(
            children: [
              buildTipoEscalaSliderOption('planejada', temPlanejada),
              buildTipoEscalaSliderOption('executada', temExecutada),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTipoEscalaSliderOption(String tipo, bool enabled) {
    final selected = selectedEscalaTipo == tipo;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled && selectedEscalaMesKey != null
            ? () => selecionarEscalaHistorico(selectedEscalaMesKey!, tipo)
            : null,
        child: Center(
          child: Text(
            labelTipoEscala(tipo),
            style: TextStyle(
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.34),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  String textoComparativoPlanejadaExecutada(Map<String, dynamic> dadosMes) {
    final planejada = toStringDynamicMap(dadosMes['planejada']);
    final executada = toStringDynamicMap(dadosMes['executada']);
    if (planejada.isEmpty || executada.isEmpty) return '';

    final salarioPlanejado = toDouble(planejada['salarioLiquido']);
    final salarioExecutado = toDouble(executada['salarioLiquido']);
    if (salarioPlanejado <= 0 || salarioExecutado <= 0) return '';

    final maior = salarioPlanejado >= salarioExecutado
        ? salarioPlanejado
        : salarioExecutado;
    final origem = salarioPlanejado >= salarioExecutado
        ? 'planejada'
        : 'executada';
    final diferenca = (salarioExecutado - salarioPlanejado).abs();

    return 'Planejada x Executada: maior líquido ${formatarMoeda(maior, 'BRL')} (${labelTipoEscala(origem)}), diferença ${formatarMoeda(diferenca, 'BRL')}.';
  }

  String textoTempoAteAtividade(DateTime? inicio, DateTime? fim) {
    final agora = DateTime.now();
    if (inicio != null &&
        fim != null &&
        !agora.isBefore(inicio) &&
        !agora.isAfter(fim)) {
      return 'Em andamento';
    }
    if (inicio == null) return 'Na escala';
    final diff = inicio.difference(agora);
    if (diff.inMinutes.abs() < 1) return 'Agora';
    if (diff.isNegative) return 'Já passou';
    if (diff.inDays >= 1) return 'Em ${diff.inDays}d';
    final horas = diff.inHours;
    final minutos = diff.inMinutes % 60;
    if (horas <= 0) return 'Em ${minutos}min';
    return 'Em ${horas}h${minutos.toString().padLeft(2, '0')}';
  }

  Widget buildEscalaPeriodoSelector() {
    final periodos = ['Hoje', 'Semana', 'Mês'];

    return Container(
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: periodos.map((periodo) {
          final selected = escalaPeriodo == periodo;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => escalaPeriodo = periodo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [AppColors.blue, AppColors.cyan],
                        )
                      : null,
                  color: selected ? null : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: selected
                      ? null
                      : Border.all(color: Colors.white.withValues(alpha: 0.30)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.14),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  periodo,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildEscalaResumoRapido() {
    final resumoPeriodo = calcularResumoDoPeriodoSelecionado();
    final horasVoo = formatarMinutosComoHoras(
      resumoPeriodo['minutos_voo'] ?? 0,
    );
    final horasUltimos28Dias = formatarMinutosComoHoras(
      calcularMinutosVooUltimos28Dias(),
    );
    final reservas = resumoPeriodo['reservas'] ?? 0;
    final sobreavisos = resumoPeriodo['sobreavisos'] ?? 0;
    final folgas = resumoPeriodo['folgas'] ?? 0;
    final contexto = contextoResumoSelecionado();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final isCompact = constraints.maxWidth < 980;

        final metricCards = [
          buildEscalaMetricCard(
            icon: Icons.schedule_outlined,
            title: isMobile ? 'Horas de voo' : 'Horas',
            value: horasVoo,
            subtitle: contexto,
            compact: isCompact,
          ),
          buildEscalaMetricCard(
            icon: Icons.history_outlined,
            title: '28 dias',
            value: horasUltimos28Dias,
            subtitle: 'voadas',
            compact: isCompact,
          ),
          if (!isMobile) ...[
            buildEscalaMetricCard(
              icon: Icons.event_available_outlined,
              title: 'Reservas',
              value: reservas.toString(),
              subtitle: contexto,
              compact: isCompact,
            ),
            buildEscalaMetricCard(
              icon: Icons.notifications_active_outlined,
              title: 'Sobreav.',
              value: sobreavisos.toString(),
              subtitle: contexto,
              compact: isCompact,
            ),
          ],
          buildEscalaMetricCard(
            icon: Icons.weekend_outlined,
            title: 'Folgas',
            value: folgas.toString(),
            subtitle: contexto,
            compact: isCompact,
          ),
        ];

        final gap = isMobile ? 4.0 : 7.0;
        return Row(
          children: [
            for (var i = 0; i < metricCards.length; i++) ...[
              Expanded(child: metricCards[i]),
              if (i != metricCards.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }

  Widget buildEscalaMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navy2],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 21 : 22,
                height: compact ? 21 : 22,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: Colors.white, size: compact ? 12 : 13),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: compact ? 11 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: compact ? 10 : 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEscalaEmptyState() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                color: AppColors.blue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nenhuma escala importada ainda',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clique em “Importar escala” no canto superior direito para carregar o Excel e gerar sua linha do tempo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF617086),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              icon: Icons.upload_file_outlined,
              label: 'Importar escala Excel',
              onTap: pickExcelFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEscalaTimeline(List<Map<String, String>> eventos) {
    final grupos = agruparEventosPorData(eventos);

    return Column(
      children: grupos.entries.map((entry) {
        return buildDiaEscalaCard(entry.key, entry.value, eventos);
      }).toList(),
    );
  }

  Widget buildDiaEscalaCard(
    String data,
    List<Map<String, String>> eventos,
    List<Map<String, String>> todosEventos,
  ) {
    final partes = data.split('/');
    final dia = partes.isNotEmpty ? partes[0] : data;
    final mes = partes.length >= 2 ? nomeMesCurto(partes[1]) : '';
    final semana = diaSemanaCurto(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;

        final dateBox = SizedBox(
          width: isMobile ? 44 : 62,
          child: Column(
            children: [
              Text(
                semana,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: isMobile ? 9 : 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                dia,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 23 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Text(
                mes,
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

        return Container(
          key: escalaDiaKeys.putIfAbsent(data, () => GlobalKey()),
          margin: const EdgeInsets.only(bottom: 9),
          padding: EdgeInsets.all(isMobile ? 7 : 9),
          decoration: BoxDecoration(
            color: const Color(0xFF071A34).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dateBox,
              Container(
                width: 1,
                height: (eventos.length * (isMobile ? 48 : 46))
                    .clamp(46, isMobile ? 190 : 178)
                    .toDouble(),
                color: AppColors.blue.withValues(alpha: 0.24),
              ),
              SizedBox(width: isMobile ? 8 : 9),
              Expanded(
                child: Column(
                  children: buildEventosComApresentacao(
                    eventos,
                    todosEventos: todosEventos,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> buildEventosComApresentacao(
    List<Map<String, String>> eventos, {
    required List<Map<String, String>> todosEventos,
  }) {
    final widgets = <Widget>[];

    for (var i = 0; i < eventos.length; i++) {
      final event = eventos[i];
      final dutyReport = horarioLimpo(event['duty_report'] ?? '');
      final tipoAtual = (event['tipo'] ?? '').toUpperCase().trim();
      final globalIndex = indiceEventoNaEscala(todosEventos, event);
      final dutyAtivo = dutyReport.isNotEmpty
          ? dutyReport
          : dutyReportAtivoAntesDoEvento(todosEventos, globalIndex);
      final deveMostrarApresentacao =
          tipoAtual == 'VOO' && dutyReport.isNotEmpty;

      if (deveMostrarApresentacao) {
        widgets.add(buildDutyReportBanner(dutyReport));
      }

      widgets.add(buildEventoEscalaRow(event));

      final fimDaJornada =
          tipoAtual == 'VOO' &&
          dutyAtivo != null &&
          !existeVooPosteriorNaMesmaJornada(
            todosEventos,
            globalIndex,
            dutyAtivo,
          );

      if (fimDaJornada) {
        final indiceInicioJornada = indiceInicioJornadaPorDuty(
          todosEventos,
          globalIndex,
          dutyAtivo,
        );
        final analise = calcularLimiteJornadaDaEscala(
          todosEventos,
          indiceInicioJornada,
          dutyAtivo,
        );
        widgets.add(buildEncerramentoJornadaBanner(analise));
      }
    }

    return widgets;
  }

  int indiceEventoNaEscala(
    List<Map<String, String>> eventos,
    Map<String, String> alvo,
  ) {
    final chave = chaveEventoEscala(alvo);
    final index = eventos.indexWhere(
      (event) => chaveEventoEscala(event) == chave,
    );
    return index < 0 ? 0 : index;
  }

  String chaveEventoEscala(Map<String, String> event) {
    return [
      event['data'] ?? '',
      event['tipo'] ?? '',
      event['identificacao'] ?? '',
      event['origem'] ?? '',
      event['destino'] ?? '',
      event['saida'] ?? '',
      event['chegada'] ?? '',
    ].join('|');
  }

  String? dutyReportAtivoAntesDoEvento(
    List<Map<String, String>> eventos,
    int index,
  ) {
    if (index < 0 || index >= eventos.length) return null;
    for (var i = index; i >= 0; i--) {
      final duty = horarioLimpo(eventos[i]['duty_report'] ?? '');
      if (duty.isNotEmpty) return duty;
    }
    return null;
  }

  int indiceInicioJornadaPorDuty(
    List<Map<String, String>> eventos,
    int index,
    String dutyReport,
  ) {
    for (var i = index; i >= 0; i--) {
      final duty = horarioLimpo(eventos[i]['duty_report'] ?? '');
      if (duty.isNotEmpty) return i;
    }
    return index;
  }

  bool existeVooPosteriorNaMesmaJornada(
    List<Map<String, String>> eventos,
    int index,
    String dutyReport,
  ) {
    for (var i = index + 1; i < eventos.length; i++) {
      final event = eventos[i];
      final outroDuty = horarioLimpo(event['duty_report'] ?? '');
      if (outroDuty.isNotEmpty && outroDuty != dutyReport) return false;
      if ((event['tipo'] ?? '').toUpperCase().trim() == 'VOO') return true;
    }
    return false;
  }

  Map<String, dynamic> calcularLimiteJornadaDaEscala(
    List<Map<String, String>> eventos,
    int indexInicio,
    String dutyReport,
  ) {
    final eventoInicio = eventos[indexInicio];
    final dataBase = parseDataPtBr(eventoInicio['data'] ?? '');
    final minutosReport = parseHoraMinuto(dutyReport);

    if (dataBase == null || minutosReport == null) {
      return {'disponivel': false};
    }

    var etapas = 0;

    for (var i = indexInicio; i < eventos.length; i++) {
      final atual = eventos[i];
      final outroDuty = horarioLimpo(atual['duty_report'] ?? '');

      if (i > indexInicio && outroDuty.isNotEmpty) {
        break;
      }

      final tipo = (atual['tipo'] ?? '').toUpperCase().trim();
      if (tipo == 'VOO') {
        etapas += 1;
      }
    }

    if (etapas <= 0) etapas = 1;

    final faixa = linhaTabelaB1(minutosReport);
    final coluna = colunaTabelaB1(etapas);
    final valores = tabelaB1()[faixa]![coluna]!;

    final limiteJornadaMin = (valores[0] * 60).round();
    final limiteVooMin = (valores[1] * 60).round();

    final extraDiasReport = extrairOffsetDias(dutyReport);
    final inicio = DateTime(
      dataBase.year,
      dataBase.month,
      dataBase.day + extraDiasReport,
      minutosReport ~/ 60,
      minutosReport % 60,
    );

    final termino = inicio.add(Duration(minutes: limiteJornadaMin));
    final corteMotores = termino.subtract(const Duration(minutes: 30));

    return {
      'disponivel': true,
      'etapas': etapas,
      'faixa': faixa,
      'coluna': coluna,
      'limite_jornada_min': limiteJornadaMin,
      'limite_voo_min': limiteVooMin,
      'limite_jornada_texto': formatarMinutosComoDuracao(limiteJornadaMin),
      'limite_voo_texto': formatarMinutosComoDuracao(limiteVooMin),
      'termino_texto': formatarHoraDateTimeComBase(termino, dataBase),
      'corte_texto': formatarHoraDateTimeComBase(corteMotores, dataBase),
    };
  }

  Widget buildDutyReportBanner(String dutyReport) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D223D),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.login_outlined,
                      color: AppColors.cyan,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Apresentação',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dutyReport,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.login_outlined, color: AppColors.cyan, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Apresentação',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dutyReport,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildEncerramentoJornadaBanner(Map<String, dynamic> analise) {
    if (analise['disponivel'] != true) return const SizedBox.shrink();
    final termino = analise['termino_texto']?.toString() ?? '';
    if (termino.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 560;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4, top: 1),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: Colors.white.withValues(alpha: 0.62),
                size: isMobile ? 15 : 12,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isMobile
                      ? 'Limite da jornada: $termino local.'
                      : 'De acordo com sua apresentação, sua jornada deve encerrar às $termino local.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: isMobile ? 9 : 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildJornadaLimitChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.cyan.withValues(alpha: 0.90)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  bool ehFolgaOuDayOff(Map<String, String> event) {
    final tipo = (event['tipo'] ?? '').toUpperCase().trim();
    final id = (event['identificacao'] ?? '').toUpperCase().trim();
    final pairing = (event['pairing'] ?? '').toUpperCase().trim();
    final item = (event['item'] ?? '').toUpperCase().trim();

    return tipo == 'DO' ||
        tipo == 'OFF' ||
        tipo == 'FOLGA' ||
        tipo.contains('FOLGA') ||
        tipo.contains('OFF') ||
        id == 'DO' ||
        id == 'OFF' ||
        id == 'FOLGA' ||
        id.contains('FOLGA') ||
        pairing == 'DO' ||
        pairing == 'OFF' ||
        item == 'DO' ||
        item == 'OFF';
  }

  Widget buildEventoEscalaRow(Map<String, String> event) {
    final tipo = (event['tipo'] ?? '').toUpperCase();
    final idUpper = (event['identificacao'] ?? '').toUpperCase();
    final isVoo = tipo == 'VOO';
    final isSobreaviso =
        tipo.contains('SOBREAVISO') || idUpper.startsWith('HSB');
    final isReserva = tipo.contains('RESERVA') || idUpper.startsWith('ASB');
    final isFolga = ehFolgaOuDayOff(event);
    final isDescanso = tipo == 'DESCANSO';
    final origem = event['origem'] ?? '';
    final destino = event['destino'] ?? '';
    final saida = event['saida'] ?? '';
    final chegada = event['chegada'] ?? '';
    final id = event['identificacao'] ?? '';
    final duracaoTexto = duracaoAtividadeTexto(event);

    final Color color;
    final IconData icon;
    final String label;

    if (isVoo) {
      color = AppColors.blue;
      icon = Icons.flight_takeoff;
      label = 'Voo';
    } else if (isReserva) {
      color = const Color(0xFFE53935);
      icon = Icons.event_available_outlined;
      label = 'Reserva';
    } else if (isSobreaviso) {
      color = const Color(0xFFF6B21A);
      icon = Icons.notifications_none_outlined;
      label = 'Sobreaviso';
    } else if (isFolga) {
      color = AppColors.green;
      icon = Icons.weekend_outlined;
      label = 'Folga';
    } else if (isDescanso) {
      color = const Color(0xFF7C8AA5);
      icon = Icons.hotel_outlined;
      label = 'Descanso';
    } else {
      color = AppColors.green;
      icon = Icons.event_note_outlined;
      label = tipo.isEmpty ? 'Escala' : tipo;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;

        final tag = Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 8,
            vertical: isMobile ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSobreaviso ? 0.92 : 1),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isMobile ? 12 : 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 11 : 11,
                ),
              ),
            ],
          ),
        );

        final routeContent = isVoo
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildAirportTime(saida, origem, compact: isMobile),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 9),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.blue,
                      size: isMobile ? 18 : 18,
                    ),
                  ),
                  buildAirportTime(chegada, destino, compact: isMobile),
                ],
              )
            : Text(
                isFolga
                    ? 'Dia livre'
                    : isDescanso
                    ? (origem.isEmpty
                          ? 'Descanso fora da base'
                          : 'Descanso em $origem')
                    : formatarIntervaloEvento(saida, chegada),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 13 : 13,
                  fontWeight: FontWeight.w800,
                ),
              );

        final row = Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 9,
            vertical: isMobile ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: isMobile
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    tag,
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 62,
                      child: Text(
                        id,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (duracaoTexto.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      buildDurationChip(duracaoTexto, color, compact: true),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: routeContent,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    tag,
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 76,
                      child: Text(
                        id,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (duracaoTexto.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      buildDurationChip(duracaoTexto, color),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: routeContent,
                      ),
                    ),
                  ],
                ),
        );

        if (!isVoo) return row;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => abrirDetalheVoo(event),
            child: row,
          ),
        );
      },
    );
  }

  void abrirDetalheVoo(Map<String, String> event) {
    final origem = event['origem'] ?? '';
    final destino = event['destino'] ?? '';
    final id = event['identificacao'] ?? '';

    unawaited(atualizarMeteoVoo(event, origem: true));
    unawaited(atualizarMeteoVoo(event, origem: false));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void refreshMeteo({required bool origem}) {
              atualizarMeteoVoo(event, origem: origem).whenComplete(() {
                if (mounted) setModalState(() {});
              });
              setModalState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.42,
              maxChildSize: 0.92,
              builder: (context, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.blue, AppColors.cyan],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.flight_takeoff,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      id.isEmpty ? 'Voo' : id,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '$origem → $destino • ${event['data'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.64,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          labelColor: AppColors.cyan,
                          unselectedLabelColor: Colors.white54,
                          indicatorColor: AppColors.cyan,
                          tabs: const [
                            Tab(text: 'Tripulação'),
                            Tab(text: 'Meteorologia'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              ListView(
                                controller: controller,
                                padding: const EdgeInsets.all(18),
                                children: [buildTripulacaoVooTab(event)],
                              ),
                              ListView(
                                controller: controller,
                                padding: const EdgeInsets.all(18),
                                children: [
                                  buildMeteoVooTab(
                                    event,
                                    onRefreshOrigem: () =>
                                        refreshMeteo(origem: true),
                                    onRefreshDestino: () =>
                                        refreshMeteo(origem: false),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildTripulacaoVooTab(Map<String, String> event) {
    final nomes = [
      event['comandante'] ?? '',
      event['copiloto'] ?? '',
      event['chefe_cabine'] ?? '',
      event['comissarios'] ?? '',
      event['tripulacao'] ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();

    if (nomes.isEmpty) {
      return buildFlightDetailCard(
        icon: Icons.groups_2_outlined,
        title: 'Tripulação designada',
        child: Text(
          'A escala importada ainda não trouxe os nomes da tripulação para este voo. Quando essa informação vier no Excel, ela aparece aqui direto.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return buildFlightDetailCard(
      icon: Icons.groups_2_outlined,
      title: 'Tripulação designada',
      child: Column(
        children: nomes
            .map(
              (nome) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: AppColors.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget buildMeteoVooTab(
    Map<String, String> event, {
    required VoidCallback onRefreshOrigem,
    required VoidCallback onRefreshDestino,
  }) {
    return Column(
      children: [
        buildAirportMeteoCard(event, origem: true, onRefresh: onRefreshOrigem),
        const SizedBox(height: 12),
        buildAirportMeteoCard(
          event,
          origem: false,
          onRefresh: onRefreshDestino,
        ),
      ],
    );
  }

  Widget buildAirportMeteoCard(
    Map<String, String> event, {
    required bool origem,
    required VoidCallback onRefresh,
  }) {
    final codigo = origem ? event['origem'] ?? '' : event['destino'] ?? '';
    final cacheKey = meteoKey(event, origem: origem);
    final meteo = meteoCache[cacheKey];
    final loading = meteoLoadingKeys.contains(cacheKey);
    final temCoordenada =
        toDouble(event[origem ? 'origem_lat' : 'destino_lat']) != 0 &&
        toDouble(event[origem ? 'origem_lon' : 'destino_lon']) != 0;

    return buildFlightDetailCard(
      icon: origem ? Icons.flight_takeoff_outlined : Icons.flight_land_outlined,
      title: origem ? 'Origem • $codigo' : 'Destino • $codigo',
      trailing: IconButton(
        tooltip: 'Atualizar meteorologia',
        onPressed: loading || !temCoordenada ? null : onRefresh,
        icon: Icon(
          loading ? Icons.sync : Icons.refresh,
          color: loading || !temCoordenada ? Colors.white30 : AppColors.cyan,
        ),
      ),
      child: !temCoordenada
          ? Text(
              'Reimporte a escala para carregar coordenadas deste aeroporto e ativar a meteorologia.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w700,
              ),
            )
          : meteo == null
          ? Text(
              loading ? 'Atualizando condições...' : 'Toque em atualizar.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w700,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildMeteoChip(
                  Icons.thermostat_outlined,
                  '${formatarNumeroCurto(meteo['temperatura'])} °C',
                ),
                buildMeteoChip(
                  Icons.air_outlined,
                  '${formatarNumeroCurto(meteo['vento'])} km/h',
                ),
                buildMeteoChip(
                  Icons.cloud_outlined,
                  descricaoCodigoMeteo(toDouble(meteo['codigo']).round()),
                ),
                buildMeteoChip(
                  Icons.update_outlined,
                  meteo['atualizadoEm']?.toString() ?? '',
                ),
              ],
            ),
    );
  }

  Widget buildFlightDetailCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.cyan, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget buildMeteoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.cyan, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> atualizarMeteoVoo(
    Map<String, String> event, {
    required bool origem,
  }) async {
    final lat = toDouble(event[origem ? 'origem_lat' : 'destino_lat']);
    final lon = toDouble(event[origem ? 'origem_lon' : 'destino_lon']);
    if (lat == 0 || lon == 0) return;

    final cacheKey = meteoKey(event, origem: origem);
    if (meteoLoadingKeys.contains(cacheKey)) return;

    setState(() => meteoLoadingKeys.add(cacheKey));

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current': 'temperature_2m,wind_speed_10m,weather_code',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final current = toStringDynamicMap(decoded['current']);

      if (!mounted) return;
      setState(() {
        meteoCache[cacheKey] = {
          'temperatura': current['temperature_2m'],
          'vento': current['wind_speed_10m'],
          'codigo': current['weather_code'],
          'atualizadoEm': horaAgoraCurta(),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        meteoCache[cacheKey] = {
          'temperatura': '--',
          'vento': '--',
          'codigo': -1,
          'atualizadoEm': 'indisponível',
        };
      });
    } finally {
      if (mounted) setState(() => meteoLoadingKeys.remove(cacheKey));
    }
  }

  String meteoKey(Map<String, String> event, {required bool origem}) {
    final lado = origem ? 'origem' : 'destino';
    return '${event['data']}_${event['identificacao']}_$lado';
  }

  String horaAgoraCurta() {
    final agora = DateTime.now();
    return '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  }

  String formatarNumeroCurto(dynamic value) {
    final numero = toDouble(value);
    if (numero == 0 && value?.toString() != '0') return '--';
    if (numero == numero.roundToDouble()) return numero.round().toString();
    return numero.toStringAsFixed(1);
  }

  String descricaoCodigoMeteo(int codigo) {
    if (codigo < 0) return 'Indisponível';
    if (codigo == 0) return 'Céu limpo';
    if ([1, 2, 3].contains(codigo)) return 'Parcial';
    if ([45, 48].contains(codigo)) return 'Nevoeiro';
    if ([51, 53, 55, 56, 57].contains(codigo)) return 'Garoa';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(codigo)) return 'Chuva';
    if ([71, 73, 75, 77, 85, 86].contains(codigo)) return 'Neve';
    if ([95, 96, 99].contains(codigo)) return 'Temporal';
    return 'Condição $codigo';
  }

  Widget buildDurationChip(String text, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            color: color.withValues(alpha: 0.92),
            size: compact ? 11 : 11,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: compact ? 10 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  String duracaoAtividadeTexto(Map<String, String> event) {
    if (ehFolgaOuDayOff(event)) return '';

    final duracao = duracaoAtividade(event);
    if (duracao == null || duracao.inMinutes <= 0) return '';

    final totalMinutos = duracao.inMinutes;
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;

    if (horas <= 0) return '${minutos}min';
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos.toString().padLeft(2, '0')}';
  }

  Duration? duracaoAtividade(Map<String, String> event) {
    final inicio = inicioAtividadeDateTime(event);
    final fim = fimAtividadeDateTime(event);
    if (inicio == null || fim == null) return null;
    if (fim.isAtSameMomentAs(inicio)) return null;

    var fimAjustado = fim;
    if (fimAjustado.isBefore(inicio)) {
      fimAjustado = fimAjustado.add(const Duration(days: 1));
    }

    return fimAjustado.difference(inicio);
  }

  DateTime? inicioAtividadeDateTime(Map<String, String> event) {
    final dataBase = parseDataPtBr(event['data'] ?? '');
    if (dataBase == null) return null;

    final tipo = (event['tipo'] ?? '').toUpperCase();
    final isVoo = tipo == 'VOO';
    if (ehFolgaOuDayOff(event)) {
      return DateTime(dataBase.year, dataBase.month, dataBase.day, 0, 0);
    }

    final horaPreferida = primeiroHorarioValido([
      if (isVoo) event['saida'],
      if (!isVoo) event['saida'],
      if (!isVoo) event['duty_report'],
      event['saida'],
      event['duty_report'],
    ]);

    if (horaPreferida == null) return null;
    final minutos = parseHoraMinuto(horaPreferida);
    if (minutos == null) return null;

    final extraDias = extrairOffsetDias(horaPreferida);
    return DateTime(
      dataBase.year,
      dataBase.month,
      dataBase.day + extraDias,
      minutos ~/ 60,
      minutos % 60,
    );
  }

  DateTime? fimAtividadeDateTime(Map<String, String> event) {
    final dataBase = parseDataPtBr(event['data'] ?? '');
    if (dataBase == null) return null;

    final tipo = (event['tipo'] ?? '').toUpperCase();
    final isVoo = tipo == 'VOO';
    if (ehFolgaOuDayOff(event)) {
      return DateTime(dataBase.year, dataBase.month, dataBase.day, 23, 59);
    }

    final horaPreferida = primeiroHorarioValido([
      if (isVoo) event['chegada'],
      if (!isVoo) event['chegada'],
      if (!isVoo) event['duty_debrief'],
      event['chegada'],
      event['duty_debrief'],
      event['saida'],
    ]);

    if (horaPreferida == null) return null;
    final minutos = parseHoraMinuto(horaPreferida);
    if (minutos == null) return null;

    final extraDias = extrairOffsetDias(horaPreferida);
    return DateTime(
      dataBase.year,
      dataBase.month,
      dataBase.day + extraDias,
      minutos ~/ 60,
      minutos % 60,
    );
  }

  String limparHoraParaExibicao(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    return text.replaceAll('(+1)', '').trim();
  }

  String formatarIntervaloEvento(String inicio, String fim) {
    final i = inicio.trim();
    final f = fim.trim();
    if (i.isEmpty && f.isEmpty) return 'Atividade programada';
    if (i.isEmpty) return f;
    if (f.isEmpty) return i;
    return '$i – $f';
  }

  Widget buildAirportTime(String time, String airport, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          time,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: compact ? 10 : 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          airport,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> eventosPrincipaisDaEscala() {
    final eventosBase = eventosEscalaContinua();
    final referencia = referenciaPeriodoEscala();
    final inicioJanela = inicioDaJanelaEscala(referencia);
    final fimJanela = fimDaJanelaEscala(referencia);

    final base = eventosBase.where((event) {
      if (!ehEventoVisivelNaEscala(event)) return false;

      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) return false;

      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;

      if (escalaPeriodo == 'Hoje') {
        return mesmoDia(inicioEfetivo, referencia) ||
            mesmoDia(fimEfetivo, referencia);
      }

      if (escalaPeriodo == 'Semana') {
        return !fimEfetivo.isBefore(inicioJanela) &&
            (fimJanela == null || !inicioEfetivo.isAfter(fimJanela));
      }

      return true;
    }).toList();

    base.sort((a, b) {
      final dataA =
          inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
      final dataB =
          inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
      return dataA.compareTo(dataB);
    });

    return base;
  }

  List<Map<String, String>> eventosEscalaContinua() {
    if (escalaHistoricoMensal.isEmpty) return escalaEventos;

    final eventos = <Map<String, String>>[];
    final meses = escalaHistoricoMensal.keys.toList()..sort();
    for (final mesKey in meses) {
      final mes = escalaHistoricoMensal[mesKey] ?? {};
      final registro = toStringDynamicMap(mes['executada'] ?? mes['planejada']);
      final rawEventos = registro['escalaEventos'] as List<dynamic>? ?? [];
      for (final item in rawEventos) {
        final map = toStringDynamicMap(item);
        eventos.add(
          map.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        );
      }
    }

    if (eventos.isEmpty) return escalaEventos;
    eventos.sort((a, b) {
      final dataA =
          inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
      final dataB =
          inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
      return dataA.compareTo(dataB);
    });
    return eventos;
  }

  void agendarAutoScrollEscala(List<Map<String, String>> eventos) {
    if (selectedIndex != 0 || eventos.isEmpty) return;

    final alvo = dataAlvoScrollEscala(eventos);
    if (alvo == null || alvo == ultimaDataAutoScrollEscala) return;
    ultimaDataAutoScrollEscala = alvo;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = escalaDiaKeys[alvo];
      final contextAlvo = key?.currentContext;
      if (contextAlvo == null) return;

      Scrollable.ensureVisible(
        contextAlvo,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        final retryContext = key?.currentContext;
        if (retryContext == null) return;
        Scrollable.ensureVisible(
          retryContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
      });
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        final retryContext = key?.currentContext;
        if (retryContext == null) return;
        Scrollable.ensureVisible(
          retryContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
      });
    });
  }

  String? dataAlvoScrollEscala(List<Map<String, String>> eventos) {
    final hoje = DateTime.now();
    final agora = DateTime.now();
    final ordenados = [...eventos]
      ..sort((a, b) {
        final dataA =
            inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
        final dataB =
            inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
        return dataA.compareTo(dataB);
      });

    for (final event in ordenados) {
      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) continue;
      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;
      if (!agora.isBefore(inicioEfetivo) && !agora.isAfter(fimEfetivo)) {
        return event['data'];
      }
    }

    for (final event in ordenados) {
      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      final inicioEfetivo = inicio ?? fim;
      if (inicioEfetivo != null && !inicioEfetivo.isBefore(agora)) {
        return event['data'];
      }
    }

    final datas =
        eventos
            .map((event) => parseDataPtBr(event['data'] ?? ''))
            .whereType<DateTime>()
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort();

    if (datas.isEmpty) return null;

    final hojeDia = DateTime(hoje.year, hoje.month, hoje.day);
    final mesmaData = datas.where((d) => mesmoDia(d, hojeDia)).toList();
    if (mesmaData.isNotEmpty) return formatarDataPtBr(mesmaData.first);

    final proximas = datas.where((d) => !d.isBefore(hojeDia)).toList();
    if (proximas.isNotEmpty) return formatarDataPtBr(proximas.first);

    return formatarDataPtBr(datas.last);
  }

  bool ehEventoVisivelNaEscala(Map<String, String> event) {
    final tipo = (event['tipo'] ?? '').toUpperCase();
    final id = (event['identificacao'] ?? '').toUpperCase();

    return tipo == 'VOO' ||
        tipo.contains('SOBREAVISO') ||
        tipo.contains('RESERVA') ||
        tipo == 'DESCANSO' ||
        ehFolgaOuDayOff(event) ||
        id.startsWith('HSB') ||
        id.startsWith('ASB');
  }

  DateTime inicioDaJanelaEscala(DateTime referencia) {
    if (escalaPeriodo == 'Semana') {
      return DateTime(referencia.year, referencia.month, referencia.day);
    }
    return DateTime(referencia.year, referencia.month, 1);
  }

  DateTime? fimDaJanelaEscala(DateTime referencia) {
    if (escalaPeriodo == 'Hoje') {
      return DateTime(
        referencia.year,
        referencia.month,
        referencia.day,
        23,
        59,
        59,
      );
    }

    if (escalaPeriodo == 'Semana') {
      return DateTime(
        referencia.year,
        referencia.month,
        referencia.day + 6,
        23,
        59,
        59,
      );
    }

    return null;
  }

  DateTime inicioDoDia(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  String formatarDataPtBr(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  }

  DateTime referenciaPeriodoEscala() {
    final agora = DateTime.now();
    final eventosBase = eventosEscalaContinua();

    final datas =
        eventosBase
            .map(
              (event) =>
                  inicioEventoDateTime(event) ?? fimEventoDateTime(event),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();

    if (datas.isNotEmpty) {
      return datas.first;
    }

    return agora;
  }

  Map<String, int> calcularResumoDoPeriodoSelecionado() {
    final eventos = eventosParaResumoSelecionado();
    var minutosVoo = 0;
    var km = 0;
    var reservas = 0;
    var sobreavisos = 0;
    var folgas = 0;

    for (final event in eventos) {
      final tipo = (event['tipo'] ?? '').toUpperCase();
      final id = (event['identificacao'] ?? '').toUpperCase();
      final isVoo = tipo == 'VOO';
      final isReserva = tipo.contains('RESERVA') || id.startsWith('ASB');
      final isSobreaviso = tipo.contains('SOBREAVISO') || id.startsWith('HSB');
      final isFolga = ehFolgaOuDayOff(event);

      if (isVoo) {
        minutosVoo += diferencaMinutos(
          event['saida'] ?? '',
          event['chegada'] ?? '',
        );
        km += toDouble(event['distancia_km']).round();
      }

      if (isReserva) reservas++;
      if (isSobreaviso) sobreavisos++;
      if (isFolga) folgas++;
    }

    return {
      'minutos_voo': minutosVoo,
      'km': km,
      'reservas': reservas,
      'sobreavisos': sobreavisos,
      'folgas': folgas,
    };
  }

  Map<String, dynamic> resumoFinanceiroPeriodoSelecionado() {
    final eventos = eventosParaResumoSelecionado();
    var totalVoos = 0;
    var totalReservas = 0;
    var totalSobreavisos = 0;
    var horasReserva = 0.0;
    var horasSobreaviso = 0.0;
    var kmTotal = 0.0;
    var kmDiurno = 0.0;
    var kmNoturno = 0.0;
    var kmFimSemana = 0.0;
    var kmFimSemanaNoturno = 0.0;
    final voosSemDistancia = <String>{};
    final diarias = estruturaDiariasVazia();
    var totalDiariasBrl = 0.0;
    var totalDiariasUsd = 0.0;

    for (final event in eventos) {
      final tipo = (event['tipo'] ?? '').toUpperCase();
      final id = (event['identificacao'] ?? '').toUpperCase();
      final isVoo = tipo == 'VOO';
      final isReserva = tipo.contains('RESERVA') || id.startsWith('ASB');
      final isSobreaviso = tipo.contains('SOBREAVISO') || id.startsWith('HSB');
      final duracaoHoras = (duracaoAtividade(event)?.inMinutes ?? 0) / 60;

      if (isVoo) {
        totalVoos += 1;
        final distancia = toDouble(event['distancia_km']);
        kmTotal += distancia;
        kmDiurno += toDouble(event['km_diurno']);
        kmNoturno += toDouble(event['km_noturno']);
        kmFimSemana += toDouble(event['km_fim_semana']);
        kmFimSemanaNoturno += toDouble(event['km_fim_semana_noturno']);
        if (distancia <= 0) {
          voosSemDistancia.add(
            '${event['origem'] ?? ''}-${event['destino'] ?? ''}',
          );
        }
      }

      if (isReserva) {
        totalReservas += 1;
        horasReserva += duracaoHoras;
      }
      if (isSobreaviso) {
        totalSobreavisos += 1;
        horasSobreaviso += duracaoHoras;
      }

      final grupo = (event['grupo_diaria'] ?? '').isEmpty
          ? 'NACIONAL'
          : event['grupo_diaria']!;
      if (!diarias.containsKey(grupo)) continue;
      final moeda = (event['moeda_diaria'] ?? '').isEmpty
          ? obterMoedaPadraoDoGrupo(grupo)
          : event['moeda_diaria']!;

      for (final refeicao in ['cafe', 'almoco', 'jantar', 'ceia']) {
        if ((event[refeicao] ?? '').toUpperCase() != 'SIM') continue;
        final valor = valorUnitarioDiaria(grupo, refeicao);
        final dadosGrupo = toStringDynamicMap(diarias[grupo]);
        final dadosRefeicao = toStringDynamicMap(dadosGrupo[refeicao]);
        dadosRefeicao['quantidade'] = toDouble(dadosRefeicao['quantidade']) + 1;
        dadosRefeicao['valor_total'] =
            toDouble(dadosRefeicao['valor_total']) + valor;
        dadosGrupo[refeicao] = dadosRefeicao;
        dadosGrupo['moeda'] = moeda;
        dadosGrupo['total'] = toDouble(dadosGrupo['total']) + valor;
        diarias[grupo] = dadosGrupo;
        if (moeda == 'BRL') {
          totalDiariasBrl += valor;
        } else {
          totalDiariasUsd += valor;
        }
      }
    }

    arredondarDiarias(diarias);

    return {
      'total_eventos': eventos.length,
      'total_voos': totalVoos,
      'total_reservas': totalReservas,
      'total_sobreavisos': totalSobreavisos,
      'horas_reserva': horasReserva,
      'horas_sobreaviso': horasSobreaviso,
      'km_total': kmTotal.round(),
      'km_diurno': kmDiurno.round(),
      'km_noturno': kmNoturno.round(),
      'km_fim_semana': kmFimSemana.round(),
      'km_fim_semana_noturno': kmFimSemanaNoturno.round(),
      'voos_sem_distancia': voosSemDistancia.toList()..sort(),
      'diarias': diarias,
      'total_diarias_brl': arredondarMoeda(totalDiariasBrl),
      'total_diarias_usd': arredondarMoeda(totalDiariasUsd),
    };
  }

  Map<String, dynamic> estruturaDiariasVazia() {
    final resultado = <String, dynamic>{};
    for (final grupo in ['NACIONAL', 'ARGENTINA', 'CHILE', 'AMERICA_DO_SUL']) {
      resultado[grupo] = {
        'moeda': obterMoedaPadraoDoGrupo(grupo),
        'cafe': {
          'quantidade': 0,
          'valor_unitario': valorUnitarioDiaria(grupo, 'cafe'),
          'valor_total': 0,
        },
        'almoco': {
          'quantidade': 0,
          'valor_unitario': valorUnitarioDiaria(grupo, 'almoco'),
          'valor_total': 0,
        },
        'jantar': {
          'quantidade': 0,
          'valor_unitario': valorUnitarioDiaria(grupo, 'jantar'),
          'valor_total': 0,
        },
        'ceia': {
          'quantidade': 0,
          'valor_unitario': valorUnitarioDiaria(grupo, 'ceia'),
          'valor_total': 0,
        },
        'total': 0,
      };
    }
    return resultado;
  }

  double valorUnitarioDiaria(String grupo, String refeicao) {
    final principal = switch (grupo) {
      'ARGENTINA' => 22.05,
      'CHILE' => 25.15,
      'AMERICA_DO_SUL' => 21.00,
      _ => 105.04,
    };
    return refeicao == 'cafe' ? principal * 0.25 : principal;
  }

  void arredondarDiarias(Map<String, dynamic> diarias) {
    for (final grupo in ['NACIONAL', 'ARGENTINA', 'CHILE', 'AMERICA_DO_SUL']) {
      final dadosGrupo = toStringDynamicMap(diarias[grupo]);
      for (final refeicao in ['cafe', 'almoco', 'jantar', 'ceia']) {
        final dados = toStringDynamicMap(dadosGrupo[refeicao]);
        dados['valor_unitario'] = arredondarMoeda(dados['valor_unitario']);
        dados['valor_total'] = arredondarMoeda(dados['valor_total']);
        dadosGrupo[refeicao] = dados;
      }
      dadosGrupo['total'] = arredondarMoeda(dadosGrupo['total']);
      diarias[grupo] = dadosGrupo;
    }
  }

  double arredondarMoeda(dynamic valor) {
    return (toDouble(valor) * 100).round() / 100;
  }

  List<Map<String, String>> eventosParaResumoSelecionado() {
    final eventosBase = eventosEscalaContinua();
    final referencia = referenciaPeriodoEscala();
    final mesResumo = mesKeyResumoAtual(referencia);

    final eventos = eventosBase.where((event) {
      if (!ehEventoVisivelNaEscala(event)) return false;

      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) return false;

      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;

      final parts = mesResumo.split('-');
      final ano = int.tryParse(parts.first);
      final mes = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (ano != null && mes != null) {
        return (inicioEfetivo.year == ano && inicioEfetivo.month == mes) ||
            (fimEfetivo.year == ano && fimEfetivo.month == mes);
      }

      return true;
    }).toList();

    eventos.sort((a, b) {
      final dataA =
          inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
      final dataB =
          inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
      return dataA.compareTo(dataB);
    });

    return eventos;
  }

  String contextoResumoSelecionado() {
    return labelMesKey(mesKeyResumoAtual(referenciaPeriodoEscala()));
  }

  String mesKeyResumoAtual(DateTime referencia) {
    if (selectedEscalaMesKey != null) return selectedEscalaMesKey!;
    if (escalaMesResumoKey != null) return escalaMesResumoKey!;
    return '${referencia.year}-${referencia.month.toString().padLeft(2, '0')}';
  }

  int calcularMinutosVooUltimos28Dias() {
    final agora = DateTime.now();
    final inicioJanela = agora.subtract(const Duration(days: 28));
    var minutosVoo = 0;

    for (final event in eventosEscalaContinua()) {
      if (!ehEventoVisivelNaEscala(event)) continue;
      if ((event['tipo'] ?? '').toUpperCase() != 'VOO') continue;

      final inicio = inicioEventoDateTime(event);
      if (inicio == null) continue;
      if (inicio.isBefore(inicioJanela) || inicio.isAfter(agora)) continue;

      minutosVoo += diferencaMinutos(
        event['saida'] ?? '',
        event['chegada'] ?? '',
      );
    }

    return minutosVoo;
  }

  String formatarMinutosComoHoras(int totalMinutos) {
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;
    return '$horas:${minutos.toString().padLeft(2, '0')}';
  }

  bool mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? mesAnoReferenciaEscala() {
    for (final event in escalaEventos) {
      final data = parseDataPtBr(event['data'] ?? '');
      if (data != null) return DateTime(data.year, data.month);
    }
    return null;
  }

  String horarioLimpo(String value) {
    return value.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  }

  DateTime? inicioEventoDateTime(Map<String, String> event) {
    final dataBase = parseDataPtBr(event['data'] ?? '');
    if (dataBase == null) return null;
    if (ehFolgaOuDayOff(event)) {
      return DateTime(dataBase.year, dataBase.month, dataBase.day, 0, 0);
    }

    final horaPreferida = primeiroHorarioValido([
      event['duty_report'],
      event['saida'],
    ]);

    if (horaPreferida == null) return dataBase;

    final minutos = parseHoraMinuto(horaPreferida);
    if (minutos == null) return dataBase;

    final extraDias = extrairOffsetDias(horaPreferida);
    return DateTime(
      dataBase.year,
      dataBase.month,
      dataBase.day + extraDias,
      minutos ~/ 60,
      minutos % 60,
    );
  }

  DateTime? fimEventoDateTime(Map<String, String> event) {
    final dataBase = parseDataPtBr(event['data'] ?? '');
    if (dataBase == null) return null;
    if (ehFolgaOuDayOff(event)) {
      return DateTime(dataBase.year, dataBase.month, dataBase.day, 23, 59);
    }

    final horaPreferida = primeiroHorarioValido([
      event['duty_debrief'],
      event['chegada'],
      event['saida'],
      event['duty_report'],
    ]);

    if (horaPreferida == null) return dataBase;

    final minutosFim = parseHoraMinuto(horaPreferida);
    if (minutosFim == null) return dataBase;

    var extraDias = extrairOffsetDias(horaPreferida);
    final inicio = inicioEventoDateTime(event);

    final dataFim = parseDataIso(event['data_fim_iso'] ?? '');
    final dataReferencia =
        dataFim != null && dataFim.isAfter(dataBase) ? dataFim : dataBase;
    if (dataFim != null && dataFim.isAfter(dataBase)) {
      extraDias = 0;
    }

    var fim = DateTime(
      dataReferencia.year,
      dataReferencia.month,
      dataReferencia.day + extraDias,
      minutosFim ~/ 60,
      minutosFim % 60,
    );

    if (inicio != null && fim.isBefore(inicio)) {
      fim = fim.add(const Duration(days: 1));
    }

    return fim;
  }

  DateTime? parseDataIso(String data) {
    final parts = data.trim().split('-');
    if (parts.length < 3) return null;

    final ano = int.tryParse(parts[0]);
    final mes = int.tryParse(parts[1]);
    final dia = int.tryParse(parts[2]);

    if (dia == null || mes == null || ano == null) return null;
    return DateTime(ano, mes, dia);
  }

  DateTime? parseDataPtBr(String data) {
    final parts = data.trim().split('/');
    if (parts.length < 3) return null;

    final dia = int.tryParse(parts[0]);
    final mes = int.tryParse(parts[1]);
    final ano = int.tryParse(parts[2]);

    if (dia == null || mes == null || ano == null) return null;
    return DateTime(ano, mes, dia);
  }

  String? primeiroHorarioValido(List<String?> valores) {
    for (final valor in valores) {
      final texto = (valor ?? '').trim();
      if (texto.isEmpty) continue;
      if (parseHoraMinuto(texto) != null) return texto;
    }
    return null;
  }

  int extrairOffsetDias(String horario) {
    final match = RegExp(r'\+\s*(\d+)').firstMatch(horario);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }

  Map<String, List<Map<String, String>>> agruparEventosPorData(
    List<Map<String, String>> eventos,
  ) {
    final grupos = <String, List<Map<String, String>>>{};

    for (final event in eventos) {
      final data = (event['data'] ?? '').isEmpty ? 'Sem data' : event['data']!;
      grupos.putIfAbsent(data, () => []);
      grupos[data]!.add(event);
    }

    return grupos;
  }

  String calcularHorasVooFormatadas() {
    int totalMinutos = 0;

    for (final event in escalaEventos) {
      if ((event['tipo'] ?? '').toUpperCase() != 'VOO') continue;
      final saida = event['saida'] ?? '';
      final chegada = event['chegada'] ?? '';
      totalMinutos += diferencaMinutos(saida, chegada);
    }

    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;
    return '$horas:${minutos.toString().padLeft(2, '0')}';
  }

  int diferencaMinutos(String inicio, String fim) {
    final a = parseHoraMinuto(inicio);
    final b = parseHoraMinuto(fim);
    if (a == null || b == null) return 0;

    var diff = b - a;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  int? parseHoraMinuto(String text) {
    final clean = text.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final parts = clean.split(':');
    if (parts.length < 2) return null;

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String mesReferenciaEscala() {
    for (final event in escalaEventos) {
      final data = event['data'] ?? '';
      final parts = data.split('/');
      if (parts.length >= 3) {
        return '${nomeMesLongo(parts[1])} ${parts[2]}';
      }
    }
    return 'Escala mensal';
  }

  String formatarNumeroInteiro(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  String nomeMesCurto(String mes) {
    switch (mes.padLeft(2, '0')) {
      case '01':
        return 'JAN';
      case '02':
        return 'FEV';
      case '03':
        return 'MAR';
      case '04':
        return 'ABR';
      case '05':
        return 'MAI';
      case '06':
        return 'JUN';
      case '07':
        return 'JUL';
      case '08':
        return 'AGO';
      case '09':
        return 'SET';
      case '10':
        return 'OUT';
      case '11':
        return 'NOV';
      case '12':
        return 'DEZ';
      default:
        return mes.toUpperCase();
    }
  }

  String nomeMesLongo(String mes) {
    switch (mes.padLeft(2, '0')) {
      case '01':
        return 'Janeiro';
      case '02':
        return 'Fevereiro';
      case '03':
        return 'Março';
      case '04':
        return 'Abril';
      case '05':
        return 'Maio';
      case '06':
        return 'Junho';
      case '07':
        return 'Julho';
      case '08':
        return 'Agosto';
      case '09':
        return 'Setembro';
      case '10':
        return 'Outubro';
      case '11':
        return 'Novembro';
      case '12':
        return 'Dezembro';
      default:
        return mes;
    }
  }

  String diaSemanaCurto(String data) {
    final parts = data.split('/');
    if (parts.length < 3) return '';
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return '';

    final weekDay = DateTime(year, month, day).weekday;
    switch (weekDay) {
      case 1:
        return 'SEG';
      case 2:
        return 'TER';
      case 3:
        return 'QUA';
      case 4:
        return 'QUI';
      case 5:
        return 'SEX';
      case 6:
        return 'SÁB';
      case 7:
        return 'DOM';
      default:
        return '';
    }
  }

  Widget buildJornadaPage() {
    final calc = calcularJornadaManual();
    final aviso = !jornadaAclimatado
        ? 'Cálculo exibido com base aclimatada por enquanto. A opção não aclimatado ficará preparada para uma etapa futura.'
        : jornadaTripulacao != 'Simples'
        ? 'Cálculo exibido para tripulação simples por enquanto. Composta e revezamento ficarão preparadas para a próxima fase.'
        : 'Cálculo dos limites da jornada pela apresentação e quantidade de etapas.';

    return buildPageShell(
      title: 'Jornada',
      subtitle:
          'Calcule limite de jornada, horário de término e corte dos motores.',
      icon: Icons.timer_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 760;
          final jornadaFieldWidth = isMobile ? double.infinity : 238.0;
          final jornadaSmallFieldWidth = isMobile ? double.infinity : 190.0;
          return ListView(
            controller: jornadaScrollController,
            padding: const EdgeInsets.only(bottom: 56),
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF020817),
                      Color(0xFF071A34),
                      Color(0xFF031024),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.cyan.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: AppColors.cyan,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculadora de Jornada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 19 : 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                aviso,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  fontSize: isMobile ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: jornadaFieldWidth,
                          child: buildJornadaSwitchCard(),
                        ),
                        SizedBox(
                          width: jornadaFieldWidth,
                          child: buildJornadaDropdown<String>(
                            label: 'Tipo de tripulação',
                            icon: Icons.groups_2_outlined,
                            value: jornadaTripulacao,
                            items: const ['Simples', 'Composta', 'Revezamento'],
                            formatter: (value) => 'Tripulação: $value',
                            onChanged: (value) => setState(
                              () => jornadaTripulacao =
                                  value ?? jornadaTripulacao,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: jornadaSmallFieldWidth,
                          child: buildHorarioApresentacaoCard(),
                        ),
                        SizedBox(
                          width: jornadaFieldWidth,
                          child: buildJornadaDropdown<String>(
                            label: 'Fuso de saída',
                            icon: Icons.flight_takeoff_outlined,
                            value: jornadaFusoApresentacao,
                            items: fusosBrasil.keys.toList(),
                            formatter: (value) => 'Saída: ${fusoCurto(value)}',
                            onChanged: (value) => setState(
                              () => jornadaFusoApresentacao =
                                  value ?? jornadaFusoApresentacao,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: jornadaFieldWidth,
                          child: buildJornadaDropdown<String>(
                            label: 'Fuso de chegada',
                            icon: Icons.flight_land_outlined,
                            value: jornadaFusoUltimoDestino,
                            items: fusosBrasil.keys.toList(),
                            formatter: (value) =>
                                'Chegada: ${fusoCurto(value)}',
                            onChanged: (value) => setState(
                              () => jornadaFusoUltimoDestino =
                                  value ?? jornadaFusoUltimoDestino,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: jornadaSmallFieldWidth,
                          child: buildJornadaDropdown<int>(
                            label: 'Etapas / voos',
                            icon: Icons.flight_takeoff_outlined,
                            value: jornadaEtapas,
                            items: const [1, 2, 3, 4, 5, 6, 7, 8],
                            formatter: (value) =>
                                value >= 7 ? 'Etapas: 7+' : 'Etapas: $value',
                            onChanged: (value) => setState(
                              () => jornadaEtapas = value ?? jornadaEtapas,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 310,
                          child: buildExtensaoJornadaCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    buildJornadaResultado(calc, isMobile: isMobile),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, int> get fusosBrasil => const {
    'Fernando de Noronha (UTC-2)': -2,
    'Brasília (UTC-3)': -3,
    'Amazonas (UTC-4)': -4,
    'Acre (UTC-5)': -5,
  };

  String fusoCurto(String value) {
    final idx = value.indexOf(' (');
    return idx > 0 ? value.substring(0, idx) : value;
  }

  Widget buildJornadaSwitchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: jornadaInputDecoration(),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.access_time_filled_outlined,
              color: AppColors.cyan,
              size: 16,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Aclimatado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: jornadaAclimatado,
              activeThumbColor: AppColors.cyan,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => setState(() => jornadaAclimatado = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHorarioApresentacaoCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: escolherHorarioApresentacao,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: jornadaInputDecoration(),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.schedule_outlined,
                color: AppColors.cyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apresentação',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatarTimeOfDay(jornadaApresentacao),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget buildExtensaoJornadaCard() {
    final minutos = jornadaMinutosExcedidos.round();
    final descanso = calcularDescansoMinimoMinutos();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: jornadaInputDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6B21A).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.more_time_outlined,
                  color: Color(0xFFF6B21A),
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Extensão de jornada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: jornadaHouveExtensao,
                  activeThumbColor: const Color(0xFFF6B21A),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() {
                    jornadaHouveExtensao = value;
                    if (!value) jornadaMinutosExcedidos = 0;
                  }),
                ),
              ),
            ],
          ),
          if (jornadaHouveExtensao) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Minutos excedidos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$minutos min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: jornadaMinutosExcedidos,
              min: 0,
              max: 60,
              divisions: 60,
              activeColor: const Color(0xFFF6B21A),
              inactiveColor: Colors.white.withValues(alpha: 0.18),
              label: '$minutos min',
              onChanged: (value) =>
                  setState(() => jornadaMinutosExcedidos = value),
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hotel_outlined,
                    color: Colors.white.withValues(alpha: 0.70),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Descanso mínimo: ${formatarMinutosComoDuracao(descanso)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 5),
            Text(
              'Sem extensão de jornada.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> escolherHorarioApresentacao() async {
    final horario = await showTimePicker(
      context: context,
      initialTime: jornadaApresentacao,
      helpText: 'Horário de apresentação',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyan,
              onPrimary: AppColors.navy,
              surface: AppColors.navy2,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (horario != null) {
      setState(() => jornadaApresentacao = horario);
    }
  }

  Widget buildJornadaDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T value)? formatter,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: jornadaInputDecoration(),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.cyan, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                dropdownColor: AppColors.navy2,
                iconEnabledColor: Colors.white70,
                iconSize: 18,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      formatter?.call(item) ?? item.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return items.map((item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatter?.call(item) ?? item.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }).toList();
                },
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration jornadaInputDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    );
  }

  Widget buildJornadaResultado(
    Map<String, dynamic> calc, {
    required bool isMobile,
  }) {
    final limiteJornada = calc['limite_jornada_texto'] as String;
    final limiteVoo = calc['limite_voo_texto'] as String;
    final termino = calc['termino_texto'] as String;
    final corte = calc['corte_texto'] as String;
    final fusoDestino = calc['fuso_destino'] as String;
    final descansoMinimo = calc['descanso_minimo_texto'] as String;

    final cards = [
      buildResultadoJornadaCard(
        Icons.flight_outlined,
        'Limite de voo',
        limiteVoo,
        '',
        AppColors.cyan,
      ),
      buildResultadoJornadaCard(
        Icons.timelapse_outlined,
        'Limite de jornada',
        limiteJornada,
        '',
        AppColors.blue,
      ),
      buildResultadoJornadaCard(
        Icons.flight_land_outlined,
        'Corte dos motores',
        corte,
        '',
        const Color(0xFFF6B21A),
      ),
      buildResultadoJornadaCard(
        Icons.flag_outlined,
        'Término da jornada',
        termino,
        'Hora local: $fusoDestino',
        AppColors.green,
      ),
      buildResultadoJornadaCard(
        Icons.hotel_outlined,
        'Descanso mínimo',
        descansoMinimo,
        '',
        const Color(0xFF9AA7FF),
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards.map((card) {
        return SizedBox(width: isMobile ? double.infinity : 220, child: card);
      }).toList(),
    );
  }

  Widget buildResultadoJornadaCard(
    IconData icon,
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildTabelaB1Visual() {
    final linhas = [
      ['06:00–06:59', '11 (9)', '11 (9)', '10 (8)', '9 (8)', '9 (8)'],
      ['07:00–07:59', '13 (9,5)', '12 (9)', '11 (9)', '10 (8)', '9 (8)'],
      ['08:00–11:59', '13 (10)', '13 (9,5)', '12 (9)', '11 (9)', '10 (8)'],
      ['12:00–13:59', '12 (9,5)', '12 (9)', '11 (9)', '10 (8)', '9 (8)'],
      ['14:00–15:59', '11 (9)', '11 (9)', '10 (8)', '9 (8)', '9 (8)'],
      ['16:00–17:59', '10 (8)', '10 (8)', '9 (8)', '9 (8)', '9 (8)'],
      ['18:00–05:59', '9 (8)', '9 (8)', '9 (7)', '9 (7)', '9 (7)'],
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tabela B.1 usada no cálculo',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'O número fora dos parênteses é jornada máxima. O número entre parênteses é tempo máximo de voo.',
            style: TextStyle(
              color: Color(0xFF607086),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF5FF)),
              columns: const [
                DataColumn(label: Text('Início')),
                DataColumn(label: Text('1-2')),
                DataColumn(label: Text('3-4')),
                DataColumn(label: Text('5')),
                DataColumn(label: Text('6')),
                DataColumn(label: Text('7+')),
              ],
              rows: linhas.map((linha) {
                return DataRow(
                  cells: linha
                      .map(
                        (cell) => DataCell(
                          Text(
                            cell,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int calcularDescansoMinimoMinutos() {
    final excedidos = jornadaHouveExtensao
        ? jornadaMinutosExcedidos.round()
        : 0;
    return (12 * 60) + (2 * excedidos);
  }

  Map<String, dynamic> calcularJornadaManual() {
    final reportMin =
        jornadaApresentacao.hour * 60 + jornadaApresentacao.minute;
    final row = linhaTabelaB1(reportMin);
    final col = colunaTabelaB1(jornadaEtapas);
    final valores = tabelaB1()[row]![col]!;

    final limiteJornadaMin = (valores[0] * 60).round();
    final limiteVooMin = (valores[1] * 60).round();

    final offsetOrigem = fusosBrasil[jornadaFusoApresentacao] ?? -3;
    final offsetDestino = fusosBrasil[jornadaFusoUltimoDestino] ?? -3;

    final base = DateTime(
      2026,
      1,
      1,
      jornadaApresentacao.hour,
      jornadaApresentacao.minute,
    );
    final utcInicio = base.subtract(Duration(hours: offsetOrigem));
    final utcTermino = utcInicio.add(Duration(minutes: limiteJornadaMin));
    final terminoDestino = utcTermino.add(Duration(hours: offsetDestino));
    final corteMotores = terminoDestino.subtract(const Duration(minutes: 30));

    final descansoMinimoMin = calcularDescansoMinimoMinutos();

    return {
      'limite_jornada_min': limiteJornadaMin,
      'limite_voo_min': limiteVooMin,
      'limite_jornada_texto': formatarMinutosComoDuracao(limiteJornadaMin),
      'limite_voo_texto': formatarMinutosComoDuracao(limiteVooMin),
      'termino_texto': formatarHoraDateTime(terminoDestino),
      'corte_texto': formatarHoraDateTime(corteMotores),
      'faixa': row,
      'coluna': col,
      'fuso_destino': jornadaFusoUltimoDestino,
      'descanso_minimo_min': descansoMinimoMin,
      'descanso_minimo_texto': formatarMinutosComoDuracao(descansoMinimoMin),
      'minutos_excedidos': jornadaHouveExtensao
          ? jornadaMinutosExcedidos.round()
          : 0,
    };
  }

  String linhaTabelaB1(int minutoDia) {
    if (minutoDia >= 6 * 60 && minutoDia <= 6 * 60 + 59) return '06:00–06:59';
    if (minutoDia >= 7 * 60 && minutoDia <= 7 * 60 + 59) return '07:00–07:59';
    if (minutoDia >= 8 * 60 && minutoDia <= 11 * 60 + 59) return '08:00–11:59';
    if (minutoDia >= 12 * 60 && minutoDia <= 13 * 60 + 59) return '12:00–13:59';
    if (minutoDia >= 14 * 60 && minutoDia <= 15 * 60 + 59) return '14:00–15:59';
    if (minutoDia >= 16 * 60 && minutoDia <= 17 * 60 + 59) return '16:00–17:59';
    return '18:00–05:59';
  }

  String colunaTabelaB1(int etapas) {
    if (etapas <= 2) return '1-2';
    if (etapas <= 4) return '3-4';
    if (etapas == 5) return '5';
    if (etapas == 6) return '6';
    return '7+';
  }

  Map<String, Map<String, List<double>>> tabelaB1() {
    return {
      '06:00–06:59': {
        '1-2': [11, 9],
        '3-4': [11, 9],
        '5': [10, 8],
        '6': [9, 8],
        '7+': [9, 8],
      },
      '07:00–07:59': {
        '1-2': [13, 9.5],
        '3-4': [12, 9],
        '5': [11, 9],
        '6': [10, 8],
        '7+': [9, 8],
      },
      '08:00–11:59': {
        '1-2': [13, 10],
        '3-4': [13, 9.5],
        '5': [12, 9],
        '6': [11, 9],
        '7+': [10, 8],
      },
      '12:00–13:59': {
        '1-2': [12, 9.5],
        '3-4': [12, 9],
        '5': [11, 9],
        '6': [10, 8],
        '7+': [9, 8],
      },
      '14:00–15:59': {
        '1-2': [11, 9],
        '3-4': [11, 9],
        '5': [10, 8],
        '6': [9, 8],
        '7+': [9, 8],
      },
      '16:00–17:59': {
        '1-2': [10, 8],
        '3-4': [10, 8],
        '5': [9, 8],
        '6': [9, 8],
        '7+': [9, 8],
      },
      '18:00–05:59': {
        '1-2': [9, 8],
        '3-4': [9, 8],
        '5': [9, 7],
        '6': [9, 7],
        '7+': [9, 7],
      },
    };
  }

  String formatarTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String formatarHoraDateTime(DateTime dt) {
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final diaOffset = dt.day - 1;
    if (diaOffset <= 0) return hora;
    return '$hora +$diaOffset';
  }

  String formatarHoraDateTimeComBase(DateTime dt, DateTime dataBase) {
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final base = DateTime(dataBase.year, dataBase.month, dataBase.day);
    final atual = DateTime(dt.year, dt.month, dt.day);
    final diaOffset = atual.difference(base).inDays;
    if (diaOffset <= 0) return hora;
    return '$hora +$diaOffset';
  }

  String formatarMinutosComoDuracao(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  Widget buildTabelaPage() {
    return buildPageShell(
      title: 'Tabela',
      subtitle: selectedFileName == null
          ? 'Nenhuma escala importada.'
          : 'Visão técnica tipo Excel: $selectedFileName',
      icon: Icons.table_chart_outlined,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: escalaEventos.isEmpty
              ? const Center(
                  child: Text(
                    'Importe uma escala Excel para visualizar a tabela técnica.',
                    style: TextStyle(
                      color: Color(0xFF536273),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : buildEventosTable(),
        ),
      ),
    );
  }

  Widget buildEventosTable() {
    return SingleChildScrollView(
      controller: tabelaHorizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: tabelaVerticalScrollController,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.softBlue),
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Identificação')),
            DataColumn(label: Text('Origem')),
            DataColumn(label: Text('Saída')),
            DataColumn(label: Text('Destino')),
            DataColumn(label: Text('Chegada')),
            DataColumn(label: Text('Distância KM')),
            DataColumn(label: Text('KM Diurno')),
            DataColumn(label: Text('KM Noturno')),
            DataColumn(label: Text('KM FDS')),
            DataColumn(label: Text('KM FDS Not')),
            DataColumn(label: Text('Duty Report')),
            DataColumn(label: Text('Duty Debrief')),
            DataColumn(label: Text('Café')),
            DataColumn(label: Text('Almoço')),
            DataColumn(label: Text('Jantar')),
            DataColumn(label: Text('Ceia')),
            DataColumn(label: Text('Grupo Diária')),
            DataColumn(label: Text('Moeda')),
            DataColumn(label: Text('Status')),
          ],
          rows: escalaEventos.map((event) {
            return DataRow(
              cells: [
                DataCell(Text(event['data'] ?? '')),
                DataCell(Text(event['tipo'] ?? '')),
                DataCell(Text(event['identificacao'] ?? '')),
                DataCell(Text(event['origem'] ?? '')),
                DataCell(Text(event['saida'] ?? '')),
                DataCell(Text(event['destino'] ?? '')),
                DataCell(Text(event['chegada'] ?? '')),
                DataCell(Text(event['distancia_km'] ?? '')),
                DataCell(Text(event['km_diurno'] ?? '')),
                DataCell(Text(event['km_noturno'] ?? '')),
                DataCell(Text(event['km_fim_semana'] ?? '')),
                DataCell(Text(event['km_fim_semana_noturno'] ?? '')),
                DataCell(Text(event['duty_report'] ?? '')),
                DataCell(Text(event['duty_debrief'] ?? '')),
                DataCell(Text(event['cafe'] ?? '')),
                DataCell(Text(event['almoco'] ?? '')),
                DataCell(Text(event['jantar'] ?? '')),
                DataCell(Text(event['ceia'] ?? '')),
                DataCell(Text(formatarGrupo(event['grupo_diaria'] ?? ''))),
                DataCell(Text(formatarMoedaNome(event['moeda_diaria'] ?? ''))),
                DataCell(Text(event['status'] ?? '')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildProfilePage() {
    return buildPageShell(
      title: 'Perfil',
      subtitle: 'Cadastro, assinatura, pagamento e preferências do cliente.',
      icon: Icons.person_outline,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 56),
        children: [
          buildCustomerProfileHeader(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 760;
              final cards = [
                buildProfileInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Assinatura',
                  primary: 'Crew 4U Pro',
                  secondary: 'Ativa • renovação em 12/07/2026',
                  action: 'Gerenciar plano',
                ),
                buildProfileInfoCard(
                  icon: Icons.credit_card_outlined,
                  title: 'Pagamento',
                  primary: 'Visa final 4242',
                  secondary: 'Próxima cobrança: R\$ 29,90',
                  action: 'Atualizar cartão',
                ),
                buildProfileInfoCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Faturamento',
                  primary: 'Notas e recibos',
                  secondary: 'Histórico disponível para download',
                  action: 'Ver histórico',
                ),
              ];

              if (mobile) {
                return Column(
                  children:
                      cards
                          .expand((card) => [card, const SizedBox(height: 10)])
                          .toList()
                        ..removeLast(),
                );
              }

              return Row(
                children:
                    cards
                        .expand(
                          (card) => [
                            Expanded(child: card),
                            const SizedBox(width: 12),
                          ],
                        )
                        .toList()
                      ..removeLast(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildCustomerProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navy2],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 680;
          final avatar = Stack(
            children: [
              Container(
                width: mobile ? 72 : 86,
                height: mobile ? 72 : 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.blue, AppColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.28),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'R',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.cyan,
                    size: 15,
                  ),
                ),
              ),
            ],
          );

          final details = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rafael Steffens',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'rafael@email.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildProfilePill(
                      Icons.flight_takeoff_outlined,
                      selectedCargo,
                    ),
                    buildProfilePill(
                      Icons.workspace_premium_outlined,
                      'Cliente Pro',
                    ),
                    buildProfilePill(Icons.lock_outline, 'Dados seguros'),
                  ],
                ),
              ],
            ),
          );

          final editButton = SecondaryButton(
            icon: Icons.edit_outlined,
            label: 'Editar perfil',
            onTap: () => showSnack('Edição de perfil em preparação.'),
          );

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(height: 14),
                Row(children: [details]),
                const SizedBox(height: 14),
                editButton,
              ],
            );
          }

          return Row(
            children: [
              avatar,
              const SizedBox(width: 18),
              details,
              const SizedBox(width: 18),
              editButton,
            ],
          );
        },
      ),
    );
  }

  Widget buildProfilePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.cyan, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileInfoCard({
    required IconData icon,
    required String title,
    required String primary,
    required String secondary,
    required String action,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.blue, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.navy.withValues(alpha: 0.35),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.52),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              primary,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              secondary,
              style: const TextStyle(
                color: Color(0xFF617086),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              action,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCargoConfigEditor() {
    final campos = [
      'salario_base',
      'km_diurno',
      'km_noturno',
      'km_fim_semana',
      'km_fim_semana_noturno',
      'hora_reserva',
      'hora_sobreaviso',
      'hora_simulador',
      'gratificacao',
    ];

    return Wrap(
      spacing: 22,
      runSpacing: 22,
      children: cargoConfigs.keys.map((cargo) {
        final config = cargoConfigs[cargo]!;

        return SizedBox(
          width: 380,
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cargo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...campos.map((campo) {
                    return buildConfigField(
                      cargo: cargo,
                      campo: campo,
                      valor: config[campo] ?? 0,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildConfigField({
    required String cargo,
    required String campo,
    required double valor,
  }) {
    final controller = TextEditingController(
      text: valor
          .toStringAsFixed(campo.startsWith('km') ? 6 : 2)
          .replaceAll('.', ','),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatarCampoConfig(campo),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          SizedBox(
            width: 126,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.softBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed == null) return;

                setState(() {
                  cargoConfigs[cargo]![campo] = parsed;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  String formatarCampoConfig(String campo) {
    switch (campo) {
      case 'salario_base':
        return 'Salário base';
      case 'km_diurno':
        return 'KM diurno';
      case 'km_noturno':
        return 'KM noturno';
      case 'km_fim_semana':
        return 'KM fim semana';
      case 'km_fim_semana_noturno':
        return 'KM FDS noturno';
      case 'hora_reserva':
        return 'Hora reserva';
      case 'hora_sobreaviso':
        return 'Hora sobreaviso';
      case 'hora_simulador':
        return 'Hora simulador';
      case 'gratificacao':
        return 'Gratificação';
      default:
        return campo;
    }
  }

  Widget buildAeroportosPage() {
    final voosSemDistancia =
        (resumo['voos_sem_distancia'] as List<dynamic>? ?? []);

    return buildPageShell(
      title: 'Aeroportos',
      subtitle:
          'Corrija rotas sem distância e mantenha uma lista local de aeroportos pendentes.',
      icon: Icons.place_outlined,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 56),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      voosSemDistancia.isEmpty
                          ? 'Nenhum voo sem distância identificado na importação atual.'
                          : 'Voos sem distância: ${voosSemDistancia.join(', ')}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF536273),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PrimaryButton(
                    icon: Icons.add_location_alt_outlined,
                    label: 'Adicionar aeroporto',
                    onTap: abrirDialogAdicionarAeroporto,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: aeroportosLocais.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Nenhum aeroporto local adicionado ainda.'),
                      ),
                    )
                  : DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.softBlue,
                      ),
                      columns: const [
                        DataColumn(label: Text('IATA')),
                        DataColumn(label: Text('ICAO')),
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('Latitude')),
                        DataColumn(label: Text('Longitude')),
                      ],
                      rows: aeroportosLocais.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item['iata']?.toString() ?? '')),
                            DataCell(Text(item['icao']?.toString() ?? '')),
                            DataCell(Text(item['nome']?.toString() ?? '')),
                            DataCell(Text(item['lat']?.toString() ?? '')),
                            DataCell(Text(item['lon']?.toString() ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void abrirDialogAdicionarAeroporto() {
    final iata = TextEditingController();
    final icao = TextEditingController();
    final nome = TextEditingController();
    final lat = TextEditingController();
    final lon = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar aeroporto local'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                dialogField(iata, 'IATA'),
                dialogField(icao, 'ICAO'),
                dialogField(nome, 'Nome'),
                dialogField(lat, 'Latitude'),
                dialogField(lon, 'Longitude'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  aeroportosLocais.add({
                    'iata': iata.text.trim().toUpperCase(),
                    'icao': icao.text.trim().toUpperCase(),
                    'nome': nome.text.trim(),
                    'lat': lat.text.trim(),
                    'lon': lon.text.trim(),
                  });
                });

                salvarConfiguracoesLocais();
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Widget dialogField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void abrirOpcoesExportarEscala() {
    if (escalaEventos.isEmpty) {
      showSnack('Importe uma escala antes de gerar o PDF.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blue, AppColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exportar escala',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha o estilo do material.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                option(
                  icon: Icons.slideshow_outlined,
                  title: 'Apresentação 16:9',
                  subtitle:
                      'Formato horizontal, mais bonito para visualizar e compartilhar.',
                  onTap: () {
                    Navigator.pop(context);
                    imprimirPdfEscala(compacto: false, widescreen: true);
                  },
                ),
                const SizedBox(height: 10),
                option(
                  icon: Icons.fit_screen_outlined,
                  title: 'Celular 9:16',
                  subtitle:
                      'Lista vertical bonita, no formato que cabe melhor na tela.',
                  onTap: () {
                    Navigator.pop(context);
                    imprimirPdfEscala(compacto: true);
                  },
                ),
                const SizedBox(height: 10),
                option(
                  icon: Icons.article_outlined,
                  title: 'A4 completo',
                  subtitle: 'Versão elegante para imprimir ou guardar em PDF.',
                  onTap: () {
                    Navigator.pop(context);
                    imprimirPdfEscala(compacto: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> imprimirPdfEscala({
    required bool compacto,
    bool widescreen = false,
  }) async {
    final eventos = eventosPrincipaisDaEscala();
    final grouped = <String, List<Map<String, String>>>{};
    for (final event in eventos) {
      final data = event['data'] ?? '';
      if (data.isEmpty) continue;
      grouped.putIfAbsent(data, () => []).add(event);
    }

    String eventHtml(Map<String, String> event) {
      final tipo = (event['tipo'] ?? '').toUpperCase();
      final id = event['identificacao'] ?? '';
      final origem = event['origem'] ?? '';
      final destino = event['destino'] ?? '';
      final saida = limparHoraParaExibicao(event['saida'] ?? '');
      final chegada = limparHoraParaExibicao(event['chegada'] ?? '');
      final isFolga = ehFolgaOuDayOff(event);
      final cls = tipo == 'VOO'
          ? 'voo'
          : tipo.contains('RESERVA')
          ? 'reserva'
          : tipo.contains('SOBREAVISO')
          ? 'sobreaviso'
          : 'folga';
      final detalhe = tipo == 'VOO'
          ? '$origem → $destino'
          : (isFolga ? 'Dia livre' : formatarIntervaloEvento(saida, chegada));
      final horario = isFolga
          ? ''
          : (tipo == 'VOO'
                ? '$saida – $chegada'
                : formatarIntervaloEvento(saida, chegada));
      return '<div class="event $cls"><div><b>${esc(isFolga ? 'FOLGA' : tipo)}</b> ${esc(id)}</div><div>${esc(detalhe)}</div><div>${esc(horario)}</div></div>';
    }

    String jornadaHtml(List<Map<String, String>> eventosDoDia) {
      final parts = <String>[];

      for (var i = 0; i < eventosDoDia.length; i++) {
        final event = eventosDoDia[i];
        final tipo = (event['tipo'] ?? '').toUpperCase();
        final dutyReport = horarioLimpo(event['duty_report'] ?? '');
        final globalIndex = indiceEventoNaEscala(eventos, event);
        final dutyAtivo = dutyReport.isNotEmpty
            ? dutyReport
            : dutyReportAtivoAntesDoEvento(eventos, globalIndex);

        if (tipo == 'VOO' && dutyReport.isNotEmpty) {
          final analise = calcularLimiteJornadaDaEscala(
            eventos,
            globalIndex,
            dutyReport,
          );
          final limite = analise['termino_texto']?.toString() ?? '';
          parts.add(
            '<div class="report"><b>Apresentação</b> <span>${esc(dutyReport)}</span>${limite.isNotEmpty ? ' · Fim limite ${esc(limite)}' : ''}</div>',
          );
        }

        parts.add(eventHtml(event));

        final fimDaJornada =
            tipo == 'VOO' &&
            dutyAtivo != null &&
            !existeVooPosteriorNaMesmaJornada(eventos, globalIndex, dutyAtivo);
        if (fimDaJornada) {
          final analise = calcularLimiteJornadaDaEscala(
            eventos,
            indiceInicioJornadaPorDuty(eventos, globalIndex, dutyAtivo),
            dutyAtivo,
          );
          final termino = analise['termino_texto']?.toString() ?? '';
          if (termino.isNotEmpty) {
            parts.add(
              '<div class="report end"><b>Fim limite de jornada</b> <span>${esc(termino)}</span></div>',
            );
          }
        }
      }

      return parts.join();
    }

    String dayHtml(MapEntry<String, List<Map<String, String>>> entry) {
      final data = entry.key;
      final eventosHtml = jornadaHtml(entry.value);
      return '<section class="day"><h2>${esc(data)}</h2>$eventosHtml</section>';
    }

    final dias = grouped.entries.map(dayHtml).join();
    final resumoPeriodo = calcularResumoDoPeriodoSelecionado();
    final horasVoo = formatarMinutosComoHoras(
      resumoPeriodo['minutos_voo'] ?? 0,
    );
    final kmTotal = formatarNumeroInteiro(resumoPeriodo['km'] ?? 0);
    final reservas = (resumoPeriodo['reservas'] ?? 0).toString();
    final sobreavisos = (resumoPeriodo['sobreavisos'] ?? 0).toString();
    final folgas = (resumoPeriodo['folgas'] ?? 0).toString();

    final contentCompacto =
        """
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Crew 4U - Escala celular</title>
<style>
  @page { size: 90mm 160mm; margin: 0; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: Arial, sans-serif; background: #020817; color: white; }
  .canvas { width: 100%; min-height: 100vh; padding: 12px; background:
    radial-gradient(circle at 88% 3%, rgba(24,200,255,.18), transparent 24%),
    linear-gradient(160deg, #020817 0%, #071a34 58%, #031021 100%); }
  .top { border: 1px solid rgba(255,255,255,.10); background: rgba(255,255,255,.065); border-radius: 18px; padding: 13px; margin-bottom: 10px; }
  .logo { font-size: 26px; line-height: .9; letter-spacing: -1.6px; font-weight: 300; }
  .logo span { color: #128DFF; font-size: 39px; font-weight: 200; margin: 0 -3px; text-shadow: 0 0 14px rgba(24,200,255,.50); }
  .title { margin-top: 8px; }
  .title h1 { margin: 0; font-size: 20px; letter-spacing: -.3px; }
  .title p { margin: 4px 0 0; color: rgba(255,255,255,.64); font-size: 11px; font-weight: 800; }
  .days { display: block; }
  .day { border: 1px solid rgba(255,255,255,.10); background: rgba(255,255,255,.070); border-radius: 16px; overflow: hidden; margin-bottom: 10px; break-inside: avoid; }
  h2 { margin: 0; padding: 9px 11px; background: rgba(18,141,255,.18); font-size: 12px; letter-spacing: .4px; }
  .report { margin: 8px 9px 0; padding: 8px 9px; border-radius: 10px; color: #8ce4ff; background: rgba(24,200,255,.10); border: 1px solid rgba(24,200,255,.20); font-size: 10.5px; font-weight: 800; }
  .event { display: grid; grid-template-columns: 1fr 1fr .82fr; gap: 6px; align-items: center; padding: 10px 9px; border-top: 1px solid rgba(255,255,255,.08); font-size: 11.4px; line-height: 1.2; }
  .event b { font-size: 10.5px; }
  .voo { border-left: 4px solid #128DFF; }
  .reserva { border-left: 4px solid #F05252; }
  .sobreaviso { border-left: 4px solid #F6B21A; }
  .folga { border-left: 4px solid #19A65A; }
  .foot { color: rgba(255,255,255,.42); font-size: 9px; font-weight: 800; text-align: center; padding: 5px 0 0; }
</style>
<script>window.onload = function() { setTimeout(function(){ window.print(); }, 300); };</script>
</head>
<body>
  <main class="canvas">
    <div class="top">
      <div class="logo">crew<span>4</span>u</div>
      <div class="title"><h1>Minha escala</h1><p>${esc(mesReferenciaEscala())} • ${esc(selectedCargo)}</p></div>
    </div>
    <section class="days">$dias</section>
    <div class="foot">Crew 4U • escala para celular</div>
  </main>
</body>
</html>
""";

    final contentA4 =
        """
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Crew 4U - Escala</title>
<style>
  @page { size: A4; margin: 12mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, sans-serif; margin: 0; color: #061329; background: #F4F8FC; }
  .header { background: linear-gradient(135deg, #061329, #0A1C38); color: white; border-radius: 22px; padding: 20px; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 14px 30px rgba(6,19,41,.16); }
  .logo { font-size: 30px; font-weight: 300; letter-spacing: -2px; }
  .logo span { color: #128DFF; font-size: 46px; font-weight: 200; margin: 0 -3px; text-shadow: 0 0 12px rgba(24,200,255,.45); }
  .sub { color: rgba(255,255,255,.70); font-size: 11px; margin-top: 4px; font-weight: 700; }
  .month { padding: 10px 14px; border-radius: 999px; background: rgba(255,255,255,.10); border: 1px solid rgba(255,255,255,.12); font-size: 13px; font-weight: 900; }
  .stats { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; margin-bottom: 12px; }
  .stat { background: white; border: 1px solid #DDE7F2; border-radius: 14px; padding: 10px; }
  .stat span { color: #64748B; font-size: 9px; font-weight: 900; text-transform: uppercase; }
  .stat b { display: block; margin-top: 5px; color: #061329; font-size: 15px; }
  .day { background: white; border: 1px solid #D8E2EE; border-radius: 16px; overflow: hidden; margin-bottom: 9px; page-break-inside: avoid; }
  h2 { margin: 0; padding: 9px 12px; background: #EAF5FF; font-size: 13px; color: #061329; }
  .report { margin: 8px 10px 0; padding: 8px 10px; border-radius: 11px; background: #E8F4FF; color: #075CA8; font-size: 10.5px; font-weight: 800; border: 1px solid #B9DAFF; }
  .event { display: grid; grid-template-columns: 1.1fr 1.2fr .9fr; gap: 8px; padding: 9px 12px; border-top: 1px solid #E6EEF7; font-size: 11px; align-items: center; }
  .voo { border-left: 5px solid #128DFF; }
  .reserva { border-left: 5px solid #E53935; }
  .sobreaviso { border-left: 5px solid #F5B31A; }
  .folga { border-left: 5px solid #19A65A; }
</style>
<script>window.onload = function() { setTimeout(function(){ window.print(); }, 300); };</script>
</head>
<body>
  <div class="header">
    <div><div class="logo">crew<span>4</span>u</div><div class="sub">${esc(selectedFileName ?? '')}</div></div>
    <div class="month">${esc(mesReferenciaEscala())}</div>
  </div>
  <section class="stats">
    <div class="stat"><span>Horas de voo</span><b>${esc(horasVoo)}</b></div>
    <div class="stat"><span>KM voados</span><b>${esc(kmTotal)}</b></div>
    <div class="stat"><span>Reservas</span><b>${esc(reservas)}</b></div>
    <div class="stat"><span>Sobreavisos</span><b>${esc(sobreavisos)}</b></div>
    <div class="stat"><span>Folgas</span><b>${esc(folgas)}</b></div>
  </section>
  $dias
</body>
</html>
""";

    final contentWidescreen =
        """
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Crew 4U - Escala 16:9</title>
<style>
  @page { size: 192mm 108mm; margin: 0; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: Arial, sans-serif; background: #020817; color: white; }
  .deck { min-height: 100vh; padding: 16px; background:
    radial-gradient(circle at 88% 0%, rgba(24,200,255,.24), transparent 28%),
    linear-gradient(135deg, #020817 0%, #071A34 58%, #031021 100%); }
  .hero { display: grid; grid-template-columns: 1.15fr 1fr; gap: 14px; margin-bottom: 12px; }
  .brand, .stats, .day { border: 1px solid rgba(255,255,255,.12); background: rgba(255,255,255,.07); border-radius: 18px; box-shadow: 0 18px 40px rgba(0,0,0,.22); }
  .brand { padding: 18px; min-height: 126px; display: flex; flex-direction: column; justify-content: space-between; }
  .logo { font-size: 31px; font-weight: 300; letter-spacing: -2px; }
  .logo span { color: #128DFF; font-size: 48px; font-weight: 200; margin: 0 -4px; text-shadow: 0 0 18px rgba(24,200,255,.65); }
  h1 { margin: 0; font-size: 30px; letter-spacing: -.5px; }
  .brand p { margin: 6px 0 0; color: rgba(255,255,255,.68); font-size: 12px; font-weight: 800; }
  .stats { padding: 14px; display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; align-content: stretch; }
  .stat { border-radius: 14px; background: rgba(255,255,255,.08); padding: 10px; border: 1px solid rgba(255,255,255,.08); }
  .stat span { display: block; color: rgba(255,255,255,.58); font-size: 9px; font-weight: 900; text-transform: uppercase; }
  .stat b { display: block; margin-top: 6px; font-size: 17px; }
  .days { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 9px; }
  .day { overflow: hidden; page-break-inside: avoid; }
  h2 { margin: 0; padding: 8px 11px; background: rgba(18,141,255,.18); color: #BFEAFF; font-size: 12px; letter-spacing: .4px; }
  .report { margin: 7px 8px 0; padding: 7px 9px; border-radius: 10px; color: #8CE4FF; background: rgba(24,200,255,.12); border: 1px solid rgba(24,200,255,.23); font-size: 10px; font-weight: 900; }
  .report span { color: white; font-size: 12px; }
  .event { display: grid; grid-template-columns: .95fr 1.1fr .72fr; gap: 7px; align-items: center; padding: 8px 9px; border-top: 1px solid rgba(255,255,255,.08); font-size: 10.5px; line-height: 1.18; }
  .event b { display: inline-block; min-width: 42px; font-size: 9.5px; color: rgba(255,255,255,.74); }
  .voo { border-left: 4px solid #128DFF; }
  .reserva { border-left: 4px solid #F05252; }
  .sobreaviso { border-left: 4px solid #F6B21A; }
  .folga { border-left: 4px solid #19A65A; }
</style>
<script>window.onload = function() { setTimeout(function(){ window.print(); }, 300); };</script>
</head>
<body>
  <main class="deck">
    <section class="hero">
      <div class="brand">
        <div class="logo">crew<span>4</span>u</div>
        <div>
          <h1>Escala ${esc(mesReferenciaEscala())}</h1>
          <p>Apresentações, voos, reservas, sobreavisos e folgas em visão horizontal.</p>
        </div>
      </div>
      <div class="stats">
        <div class="stat"><span>Horas</span><b>${esc(horasVoo)}</b></div>
        <div class="stat"><span>KM</span><b>${esc(kmTotal)}</b></div>
        <div class="stat"><span>Reservas</span><b>${esc(reservas)}</b></div>
        <div class="stat"><span>Sobreav.</span><b>${esc(sobreavisos)}</b></div>
        <div class="stat"><span>Folgas</span><b>${esc(folgas)}</b></div>
      </div>
    </section>
    <section class="days">$dias</section>
  </main>
</body>
</html>
""";

    final result = await documentService.openPrintableHtml(
      filename: widescreen
          ? 'crew4u_escala_16x9.html'
          : compacto
          ? 'crew4u_escala_celular.html'
          : 'crew4u_escala_a4.html',
      content: widescreen
          ? contentWidescreen
          : compacto
          ? contentCompacto
          : contentA4,
    );
    showSnack(result.message);
  }

  Future<void> imprimirPdfHolerite() async {
    final holerite = calcularHoleriteLocal();
    final proventos = holerite['proventos'] as List<dynamic>;
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = holerite['descontos'] as List<dynamic>;
    final salario = toStringDynamicMap(holerite['salario']);
    final diarias = toStringDynamicMap(
      resumoFinanceiroPeriodoSelecionado()['diarias'],
    );

    String esc(dynamic value) {
      return value
          .toString()
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');
    }

    String proventoRows = proventos.map((item) {
      final linha = toStringDynamicMap(item);
      return '''
        <tr>
          <td class="left"><b>${esc(linha['descricao'] ?? '')}</b></td>
          <td>${esc(formatarQuantidadeOuTexto(linha['quantidade']))}</td>
          <td>${esc(formatarRazao(linha['razao']))}</td>
          <td><b>${esc(formatarMoeda(linha['final'], 'BRL'))}</b></td>
        </tr>
      ''';
    }).join();

    String descontoRows = descontos.map((item) {
      final linha = toStringDynamicMap(item);
      return '''
        <tr>
          <td class="left"><b>${esc(linha['descricao'] ?? '')}</b></td>
          <td>${esc(formatarOpcaoDesconto(linha['opcao']))}</td>
          <td><b>${esc(formatarMoeda(linha['valor'], 'BRL'))}</b></td>
        </tr>
      ''';
    }).join();

    String diariaTabela(String grupo) {
      final dados = toStringDynamicMap(diarias[grupo]);
      final moeda =
          dados['moeda']?.toString() ?? obterMoedaPadraoDoGrupo(grupo);

      String row(String titulo, String key) {
        final refeicao = toStringDynamicMap(dados[key]);
        return '''
          <tr>
            <td class="left"><b>${esc(titulo)}</b></td>
            <td>${esc(refeicao['quantidade'] ?? '0')}</td>
            <td>${esc(formatarMoeda(refeicao['valor_total'], moeda))}</td>
          </tr>
        ''';
      }

      return '''
        <table class="smallTable">
          <tr><th colspan="3">Diárias de Voo ${esc(formatarGrupo(grupo))}</th></tr>
          <tr><th></th><th>Quantidade</th><th>Valor</th></tr>
          ${row('Café da Manhã', 'cafe')}
          ${row('Almoço', 'almoco')}
          ${row('Jantar', 'jantar')}
          ${row('Ceia', 'ceia')}
          <tr><td class="left"><b>TOTAL</b></td><td></td><td><b>${esc(formatarMoeda(dados['total'], moeda))}</b></td></tr>
        </table>
      ''';
    }

    final content =
        '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Crew 4U - Salário</title>
<style>
  @page { size: A4; margin: 14mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, sans-serif; color: #061329; margin: 0; background: white; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #128DFF; padding-bottom: 16px; margin-bottom: 18px; }
  .logo { display: flex; align-items: baseline; letter-spacing: -2px; line-height: 1; }
  .logo .crew, .logo .u { font-size: 38px; font-weight: 300; color: #061329; }
  .logo .four { font-size: 60px; font-weight: 200; color: #128DFF; text-shadow: 0 0 8px rgba(24,200,255,.35); margin: 0 -3px; }
  .title { text-align: right; }
  .title h1 { margin: 0; font-size: 22px; }
  .title p { margin: 4px 0 0; color: #536273; font-size: 12px; }
  .summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 18px; }
  .card { border: 1px solid #D8E2EE; border-radius: 12px; padding: 12px; background: #F7FBFF; }
  .card .label { color: #536273; font-size: 11px; font-weight: 700; text-transform: uppercase; }
  .card .value { font-size: 18px; font-weight: 900; margin-top: 5px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 14px; page-break-inside: avoid; }
  th, td { border: 1px solid #9CA3AF; padding: 7px 8px; text-align: right; font-size: 11px; }
  th { background: #E8F4FF; color: #061329; font-weight: 900; text-align: center; }
  .section { background: #061329; color: white; text-align: center; font-weight: 900; }
  .left { text-align: left; }
  .total td { font-weight: 900; background: #EEF6FF; }
  .liquido td { font-weight: 900; background: #E9F7ED; color: #138A46; border-color: #19A65A; font-size: 13px; }
  .diarias { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
  .smallTable th, .smallTable td { font-size: 10px; padding: 5px; }
  .footer { margin-top: 14px; color: #6B7280; font-size: 10px; text-align: center; }
</style>
<script>
  window.onload = function() { setTimeout(function(){ window.print(); }, 300); };
</script>
</head>
<body>
  <div class="header">
    <div class="logo"><span class="crew">crew</span><span class="four">4</span><span class="u">u</span></div>
    <div class="title">
      <h1>Simulação de Salário</h1>
      <p>${esc(selectedCargo)} • ${esc(selectedFileName ?? '')}</p>
      <p>USD/BRL: ${esc(formatarDecimal(cotacaoDolar, casas: 4))}</p>
    </div>
  </div>

  <div class="summary">
    <div class="card"><div class="label">Proventos</div><div class="value">${esc(formatarMoeda(salario['proventos'], 'BRL'))}</div></div>
    <div class="card"><div class="label">Descontos</div><div class="value">-${esc(formatarMoeda(salario['descontos'], 'BRL'))}</div></div>
    <div class="card"><div class="label">Salário líquido</div><div class="value">${esc(formatarMoeda(salario['salario_liquido'], 'BRL'))}</div></div>
  </div>

  <table>
    <tr><th colspan="4" class="section">PROVENTOS</th></tr>
    <tr><th class="left">Descrição</th><th>Quantidade</th><th>Razão</th><th>Final</th></tr>
    $proventoRows
    <tr class="total"><td colspan="3" class="left">TOTAL PROVENTOS</td><td>${esc(formatarMoeda(salario['proventos'], 'BRL'))}</td></tr>
  </table>

  <table>
    <tr><th colspan="2" class="section">BASE DE IR</th></tr>
    <tr><td class="left">Total Proventos</td><td>${esc(formatarMoeda(baseIr['total_proventos'], 'BRL'))}</td></tr>
    <tr><td class="left">INSS Remuneração</td><td>-${esc(formatarMoeda(baseIr['inss_remuneracao'], 'BRL'))}</td></tr>
    <tr class="total"><td class="left">Base de IR</td><td>${esc(formatarMoeda(baseIr['base_ir'], 'BRL'))}</td></tr>
  </table>

  <table>
    <tr><th colspan="3" class="section">DESCONTOS</th></tr>
    <tr><th class="left">Descrição</th><th>Opção</th><th>Valor</th></tr>
    $descontoRows
    <tr class="total"><td colspan="2" class="left">DESCONTO TOTAL</td><td>${esc(formatarMoeda(salario['descontos'], 'BRL'))}</td></tr>
  </table>

  <table>
    <tr><th colspan="2" class="section">SALÁRIO</th></tr>
    <tr><td class="left">Proventos</td><td>${esc(formatarMoeda(salario['proventos'], 'BRL'))}</td></tr>
    <tr><td class="left">Descontos</td><td>-${esc(formatarMoeda(salario['descontos'], 'BRL'))}</td></tr>
    <tr class="liquido"><td class="left">SALÁRIO LÍQUIDO</td><td>${esc(formatarMoeda(salario['salario_liquido'], 'BRL'))}</td></tr>
  </table>

  <div class="diarias">
    ${diariaTabela('NACIONAL')}
    ${diariaTabela('ARGENTINA')}
    ${diariaTabela('CHILE')}
    ${diariaTabela('AMERICA_DO_SUL')}
  </div>

  <div class="footer">Crew 4U • Documento gerado automaticamente pelo simulador.</div>
</body>
</html>
''';

    final result = await documentService.openPrintableHtml(
      filename: 'crew4u_holerite.html',
      content: content,
    );
    showSnack(result.message);
  }

  Future<void> exportarCsvHolerite() async {
    final holerite = calcularHoleriteLocal();
    final proventos = holerite['proventos'] as List<dynamic>;
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = holerite['descontos'] as List<dynamic>;
    final salario = toStringDynamicMap(holerite['salario']);

    final rows = <List<String>>[];

    rows.add(['SIMULACAO CREW 4U']);
    rows.add(['Cargo', selectedCargo]);
    rows.add(['Arquivo', selectedFileName ?? '']);
    rows.add(['Cotacao USD/BRL', cotacaoDolar.toStringAsFixed(4)]);
    rows.add([]);

    rows.add(['PROVENTOS']);
    rows.add(['Descricao', 'Quantidade', 'Razao', 'Final']);
    for (final item in proventos) {
      final linha = toStringDynamicMap(item);
      rows.add([
        linha['descricao']?.toString() ?? '',
        formatarQuantidadeOuTexto(linha['quantidade']),
        formatarRazao(linha['razao']),
        formatarMoeda(linha['final'], 'BRL'),
      ]);
    }

    rows.add([
      'TOTAL PROVENTOS',
      '',
      '',
      formatarMoeda(salario['proventos'], 'BRL'),
    ]);
    rows.add([]);

    rows.add(['BASE DE IR']);
    rows.add([
      'Total Proventos',
      formatarMoeda(baseIr['total_proventos'], 'BRL'),
    ]);
    rows.add([
      'INSS Remuneracao',
      '-${formatarMoeda(baseIr['inss_remuneracao'], 'BRL')}',
    ]);
    rows.add(['Base de IR', formatarMoeda(baseIr['base_ir'], 'BRL')]);
    rows.add([]);

    rows.add(['DESCONTOS']);
    rows.add(['Descricao', 'Opcao', 'Valor']);
    for (final item in descontos) {
      final linha = toStringDynamicMap(item);
      rows.add([
        linha['descricao']?.toString() ?? '',
        formatarOpcaoDesconto(linha['opcao']),
        formatarMoeda(linha['valor'], 'BRL'),
      ]);
    }

    rows.add([
      'DESCONTO TOTAL',
      '',
      formatarMoeda(salario['descontos'], 'BRL'),
    ]);
    rows.add([]);

    rows.add(['SALARIO']);
    rows.add(['Proventos', formatarMoeda(salario['proventos'], 'BRL')]);
    rows.add(['Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}']);
    rows.add([
      'SALARIO LIQUIDO',
      formatarMoeda(salario['salario_liquido'], 'BRL'),
    ]);

    final csv = rows
        .map((row) {
          return row
              .map((cell) {
                final safe = cell.replaceAll('"', '""');
                return '"$safe"';
              })
              .join(';');
        })
        .join('\n');

    final filename = 'crew4u_holerite_${selectedCargo.toLowerCase()}.csv';
    final result = await documentService.saveTextFile(
      filename: filename,
      content: csv,
      mimeType: 'text/csv',
    );
    showSnack(result.message);
  }

  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;

  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(colors: [AppColors.blue, AppColors.cyan]),
          color: disabled ? Colors.grey.shade400 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.softBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.blue, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
