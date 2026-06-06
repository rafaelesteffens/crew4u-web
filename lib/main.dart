
import 'dart:convert';
import 'dart:html' as html;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
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
  String seguroVidaComplementar = 'Nao Utilizo';
  String assistenciaOdontoFamilia = 'Nao Utilizo';
  String gympass = 'Nao Utilizo';

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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    carregarConfiguracoesLocais();
    carregarUltimaEscalaLocal();
    carregarCotacaoDolar();
  }

  void carregarConfiguracoesLocais() {
    final raw = html.window.localStorage['crew4u_config'];
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

    html.window.localStorage['crew4u_config'] = jsonEncode(payload);
    showSnack('Configurações salvas no navegador.');
  }



  void carregarUltimaEscalaLocal() {
    final raw = html.window.localStorage['crew4u_last_roster'];
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
      resumo = toStringDynamicMap(decoded['resumo']);
      if (resumo.isEmpty) resumo = resumoVazio();
      escalaEventos = eventos;
      if (eventos.isNotEmpty) {
        importStatus = 'Última escala restaurada do navegador.';
      }
    } catch (_) {
      html.window.localStorage.remove('crew4u_last_roster');
    }
  }

  void salvarUltimaEscalaLocal() {
    final payload = {
      'selectedFileName': selectedFileName,
      'selectedSheetName': selectedSheetName,
      'selectedCargo': selectedCargo,
      'resumo': resumo,
      'escalaEventos': escalaEventos,
      'savedAt': DateTime.now().toIso8601String(),
    };

    html.window.localStorage['crew4u_last_roster'] = jsonEncode(payload);
  }

  Future<void> carregarCotacaoDolar() async {
    setState(() {
      carregandoCotacao = true;
      cotacaoStatus = 'Buscando cotação...';
    });

    try {
      final uri = Uri.parse('https://economia.awesomeapi.com.br/json/last/USD-BRL');
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
        Uri.parse('https://crew4u-api.onrender.com/upload-escala'),
      );

      request.fields['cargo'] = selectedCargo;

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Backend retornou erro ${response.statusCode}: ${response.body}');
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
          'tipo': map['tipo']?.toString() ?? '',
          'identificacao': map['identificacao']?.toString() ?? '',
          'pairing': map['pairing']?.toString() ?? '',
          'origem': map['origem']?.toString() ?? '',
          'saida': map['saida']?.toString() ?? '',
          'destino': map['destino']?.toString() ?? '',
          'chegada': map['chegada']?.toString() ?? '',
          'duty_report': map['duty_report']?.toString() ?? '',
          'duty_debrief': map['duty_debrief']?.toString() ?? '',
          'distancia_km': map['distancia_km']?.toString() ?? '',
          'km_diurno': map['km_diurno']?.toString() ?? '',
          'km_noturno': map['km_noturno']?.toString() ?? '',
          'km_fim_semana': map['km_fim_semana']?.toString() ?? '',
          'km_fim_semana_noturno': map['km_fim_semana_noturno']?.toString() ?? '',
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
        importStatus = 'Arquivo lido com sucesso. ${eventos.length} eventos tratados encontrados.';
        selectedIndex = 0;
        ultimaDataAutoScrollEscala = null;
        escalaDiaKeys.clear();
        isLoading = false;
      });

      salvarUltimaEscalaLocal();
      registrarHistorico(filename);
    } catch (error) {
      setState(() {
        importStatus = 'Erro ao enviar/ler o Excel: $error';
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildEscalaDashboardPage(),
      buildHoleritePage(),
      buildTabelaPage(),
      buildJornadaPage(),
      buildConfigPage(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.navy,
            body: pages[selectedIndex],
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildMobileQuickActions(),
                buildBottomNavBar(),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              buildSidebar(),
              Expanded(child: pages[selectedIndex]),
            ],
          ),
        );
      },
    );
  }



  Widget buildMobileQuickActions() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildRoundActionButton(
            icon: Icons.upload_file_outlined,
            tooltip: isLoading ? 'Processando escala...' : 'Importar escala',
            onTap: isLoading ? null : pickExcelFile,
          ),
          const SizedBox(width: 12),
          buildRoundActionButton(
            icon: Icons.share_outlined,
            tooltip: 'Compartilhar escala em PDF',
            onTap: escalaEventos.isEmpty ? null : imprimirPdfEscala,
          ),
        ],
      ),
    );
  }

  Widget buildBottomActionButton({required IconData icon, required String label, required VoidCallback? onTap}) {
    return buildRoundActionButton(icon: icon, tooltip: label, onTap: onTap);
  }

  Widget buildRoundActionButton({required IconData icon, required String tooltip, required VoidCallback? onTap}) {
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
            gradient: enabled ? const LinearGradient(colors: [AppColors.blue, AppColors.cyan]) : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: enabled ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.14)),
            boxShadow: enabled ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 6))] : [],
          ),
          child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 19),
        ),
      ),
    );
  }

  Widget buildBottomNavBar() {
    final items = [
      {'icon': Icons.flight_takeoff_outlined, 'label': 'Escala'},
      {'icon': Icons.payments_outlined, 'label': 'Salário'},
      {'icon': Icons.table_chart_outlined, 'label': 'Tabela'},
      {'icon': Icons.timer_outlined, 'label': 'Jornada'},
      {'icon': Icons.person_outline, 'label': 'Perfil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        border: Border(top: BorderSide(color: AppColors.blue.withValues(alpha: 0.25))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
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
            final selected = selectedIndex == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blue.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[index]['icon'] as IconData,
                        color: selected ? AppColors.cyan : Colors.white54,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index]['label'] as String,
                        style: TextStyle(
                          color: selected ? AppColors.cyan : Colors.white54,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
          buildNavButton(0, Icons.flight_takeoff_outlined, 'Escala'),
          buildNavButton(1, Icons.payments_outlined, 'Salário'),
          buildNavButton(2, Icons.table_chart_outlined, 'Tabela'),
          buildNavButton(3, Icons.timer_outlined, 'Jornada'),
          buildNavButton(4, Icons.person_outline, 'Perfil'),
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
            onTap: escalaEventos.isEmpty ? null : imprimirPdfEscala,
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

  Widget buildSidebarActionButton({required String tooltip, required IconData icon, required VoidCallback? onTap}) {
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
            color: enabled ? AppColors.blue.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: enabled ? AppColors.blue.withValues(alpha: 0.42) : Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: enabled ? AppColors.cyan : Colors.white30, size: 21),
        ),
      ),
    );
  }

  Widget buildMiniLogo() {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.navy2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.20),
                blurRadius: 24,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '4',
              style: TextStyle(
                fontSize: 40,
                height: 1,
                color: AppColors.blue,
                fontWeight: FontWeight.w300,
                shadows: [
                  Shadow(
                    color: AppColors.cyan.withValues(alpha: 0.65),
                    blurRadius: 14,
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'crew4u',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
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
          color: selected ? AppColors.blue.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: selected ? Border.all(color: AppColors.blue.withValues(alpha: 0.45)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.cyan : Colors.white70, size: 24),
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
                  ? const [Color(0xFF030B18), Color(0xFF071A34), Color(0xFF020713)]
                  : const [Color(0xFFF7FBFF), Color(0xFFEAF2FB)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding, horizontalPadding, isMobile ? 8 : verticalPadding),
              child: Column(
                children: [
                  if (!(isMobile && isEscala)) ...[
                    buildPageHeader(title: title, subtitle: subtitle, icon: icon),
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
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navy2]),
            borderRadius: BorderRadius.circular(isMobile ? 24 : 24),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
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
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
                          ),
                          child: Icon(icon, color: AppColors.cyan, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: buildHeaderTitleText(title, subtitle, mobile: true)),
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
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
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

  Widget buildHeaderTitleText(String title, String subtitle, {bool mobile = false}) {
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                ),
                SizedBox(width: 8),
                Text(
                  'Importando...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
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
                gradient: const LinearGradient(colors: [AppColors.blue, AppColors.cyan]),
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
                  Icon(Icons.upload_file_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Upload',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        if (!compact) ...[
          const SizedBox(width: 16),
          buildTopBrand(),
        ],
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
                    style: TextStyle(fontSize: 16, color: Color(0xFF4E5B6D), height: 1.4),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      PrimaryButton(
                        icon: isLoading ? Icons.hourglass_top : Icons.upload_file,
                        label: isLoading ? 'Processando...' : 'Importar escala Excel',
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
                  if (selectedFileName != null) buildStatusBox() else buildEmptyUploadBox(),
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
              Shadow(color: AppColors.blue.withValues(alpha: 0.55), blurRadius: 18),
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
        const Text('Cargo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
          Text('Nenhum arquivo selecionado.', style: TextStyle(color: Color(0xFF536273))),
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
        color: isError ? Colors.red.withValues(alpha: 0.06) : Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError ? Colors.red.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arquivo selecionado: $selectedFileName', style: const TextStyle(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (selectedSheetName != null) ...[
                const SizedBox(height: 8),
                Text('Aba lida: $selectedSheetName', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (importStatus != null) ...[
                const SizedBox(height: 8),
                Text(importStatus!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget buildHoleritePage() {
    final diarias = toStringDynamicMap(resumo['diarias']);
    final holerite = calcularHoleriteLocal();
    final salario = toStringDynamicMap(holerite['salario']);

    return buildPageShell(
      title: 'Salário',
      subtitle: selectedFileName == null ? 'Importe uma escala para começar.' : '$selectedCargo • $selectedFileName',
      icon: Icons.payments_outlined,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          buildProfessionalHeader(salario),
          const SizedBox(height: 22),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(26),
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
          buildValidatorSection(),
          const SizedBox(height: 22),
          buildHistorySection(),
          const SizedBox(height: 22),
          buildDiariasResumoSection(diarias),
        ],
      ),
    );
  }

  Widget buildProfessionalHeader(Map<String, dynamic> salario) {
    final diariasUsd = toDouble(resumo['total_diarias_usd']);
    final diariasUsdConvertidas = diariasUsd * cotacaoDolar;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        final metrics = [
          buildHeaderMetric('Proventos', formatarMoeda(salario['proventos'], 'BRL'), compact: isMobile),
          buildHeaderMetric('Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}', compact: isMobile),
          buildHeaderMetric('Líquido', formatarMoeda(salario['salario_liquido'], 'BRL'), highlight: true, compact: isMobile),
        ];

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isMobile ? 46 : 56,
              height: isMobile ? 46 : 56,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.40)),
              ),
              child: Icon(Icons.payments_outlined, color: AppColors.cyan, size: isMobile ? 25 : 30),
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
                    selectedFileName == null ? 'Importe uma escala para gerar a simulação.' : '$selectedCargo • $selectedFileName',
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
                      Text('USD/BRL:', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(formatarDecimal(cotacaoDolar, casas: 4), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                      InkWell(
                        onTap: carregarCotacaoDolar,
                        child: Icon(carregandoCotacao ? Icons.sync : Icons.refresh, color: AppColors.cyan, size: 17),
                      ),
                      Text('Diárias exterior: ${formatarMoeda(diariasUsdConvertidas, 'BRL')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.bold)),
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
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navy2]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: metrics),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 18),
                    ...metrics.expand((w) => [w, const SizedBox(width: 10)]).toList()..removeLast(),
                  ],
                ),
        );
      },
    );
  }

  Widget buildHeaderMetric(String title, String value, {bool highlight = false, bool compact = false}) {
    return Container(
      width: compact ? 112 : 172,
      padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 15, vertical: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFE9FFF0) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? const Color(0xFF37A45B) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
    );
  }

  Widget buildTableToolbar() {
    return Row(children: [
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Salário Calculado',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: AppColors.navy),
          ),
          SizedBox(height: 6),
          Text(
            'Tabela operacional com proventos, base de IR, descontos e salário líquido.',
            style: TextStyle(color: Color(0xFF617086), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ]),
      ),
      PrimaryButton(icon: Icons.picture_as_pdf_outlined, label: 'Baixar PDF', onTap: imprimirPdfHolerite),
      const SizedBox(width: 10),
      SecondaryButton(
        icon: Icons.badge_outlined,
        label: selectedCargo,
        onTap: () => setState(() => selectedIndex = 0),
      ),
    ]);
  }

  Map<String, dynamic> obterConfigCargo() {
    return cargoConfigs[selectedCargo] ?? cargoConfigs['COPILOTO']!;
  }

  Map<String, dynamic> calcularHoleriteLocal() {
    final config = obterConfigCargo();

    final kmDiurno = toDouble(resumo['km_diurno']);
    final kmNoturno = toDouble(resumo['km_noturno']);
    final kmFimSemana = toDouble(resumo['km_fim_semana']);
    final kmFimSemanaNoturno = toDouble(resumo['km_fim_semana_noturno']);
    final horasReserva = toDouble(resumo['horas_reserva']);
    final horasSobreaviso = toDouble(resumo['horas_sobreaviso']);

    final salarioBase = toDouble(config['salario_base']);
    final valorKmDiurno = kmDiurno * toDouble(config['km_diurno']);
    final valorKmNoturno = kmNoturno * toDouble(config['km_noturno']);
    final valorKmFimSemana = kmFimSemana * toDouble(config['km_fim_semana']);
    final valorKmFimSemanaNoturno = kmFimSemanaNoturno * toDouble(config['km_fim_semana_noturno']);
    final valorReserva = horasReserva * toDouble(config['hora_reserva']);
    final valorSobreaviso = horasSobreaviso * toDouble(config['hora_sobreaviso']);
    final valorSimulador = 0.0;

    final variaveisParaRepouso =
        valorKmDiurno + valorKmNoturno + valorKmFimSemana + valorKmFimSemanaNoturno + valorReserva + valorSobreaviso + valorSimulador;

    final repousoRemunerado = variaveisParaRepouso / 22 * 8;
    final gratificacao = gratificacaoAtiva ? toDouble(config['gratificacao']) : 0.0;

    final proventos = [
      criarProvento('Salario Base', 1, toDouble(config['salario_base']), salarioBase),
      criarProvento('KM Diurno', kmDiurno, toDouble(config['km_diurno']), valorKmDiurno),
      criarProvento('KM Noturno', kmNoturno, toDouble(config['km_noturno']), valorKmNoturno),
      criarProvento('KM Fim de Semana', kmFimSemana, toDouble(config['km_fim_semana']), valorKmFimSemana),
      criarProvento('KM Fim de Semana NOT', kmFimSemanaNoturno, toDouble(config['km_fim_semana_noturno']), valorKmFimSemanaNoturno),
      criarProvento('Horas Reserva', horasReserva, toDouble(config['hora_reserva']), valorReserva),
      criarProvento('Sobreaviso', horasSobreaviso, toDouble(config['hora_sobreaviso']), valorSobreaviso),
      criarProvento('Simulador', '', toDouble(config['hora_simulador']), valorSimulador),
      criarProvento('Repouso Remunerado', '', '', repousoRemunerado),
      criarProvento('Gratificação', gratificacaoAtiva, '', gratificacao),
    ];

    final totalProventos = proventos.fold<double>(0, (sum, item) => sum + toDouble(item['final']));

    final inssRemuneracao = 988.07;
    final baseIr = totalProventos - inssRemuneracao;

    final descontoPrevidencia = calcularPrevidenciaPrivada(totalProventos);
    final descontoAmil = assistenciaMedicaAmil * 443.05;
    final descontoDasa = servicoSaudeDasa ? 14.90 : 0.0;
    final descontoBradesco = seguroBradescoFuneral ? 4.96 : 0.0;
    final descontoSeguroComplementar = calcularSeguroVidaComplementar(seguroVidaComplementar);
    final descontoOdonto = calcularOdontoFamilia(assistenciaOdontoFamilia);
    final descontoGympass = calcularGympass(gympass);
    final irrfSalario = (baseIr * 0.275) - 908.73;

    final descontos = [
      criarDesconto('Previdencia Privada', previdenciaPrivada, descontoPrevidencia),
      criarDesconto('Assistencia Medica AMIL', assistenciaMedicaAmil, descontoAmil),
      criarDesconto('Servico de Saude DASA', servicoSaudeDasa, descontoDasa),
      criarDesconto('Seguro de Vida Bradesco Funeral', seguroBradescoFuneral, descontoBradesco),
      criarDesconto('Seguro de Vida Complementar', seguroVidaComplementar, descontoSeguroComplementar),
      criarDesconto('Assistencia Odonto Familia', assistenciaOdontoFamilia, descontoOdonto),
      criarDesconto('Gympass', gympass, descontoGympass),
      criarDesconto('IRRF salario', '', irrfSalario),
    ];

    final descontoTotal = descontos.fold<double>(0, (sum, item) => sum + toDouble(item['valor']));
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

  Map<String, dynamic> criarProvento(String descricao, dynamic quantidade, dynamic razao, double finalValue) {
    return {
      'descricao': descricao,
      'quantidade': quantidade,
      'razao': razao,
      'final': finalValue,
    };
  }

  Map<String, dynamic> criarDesconto(String descricao, dynamic opcao, double valor) {
    return {
      'descricao': descricao,
      'opcao': opcao,
      'valor': valor,
    };
  }

  double calcularPrevidenciaPrivada(double totalProventos) {
    final percentual = double.tryParse(previdenciaPrivada.replaceAll('%', '').replaceAll(',', '.')) ?? 0;
    final config = obterConfigCargo();
    final gratificacao = gratificacaoAtiva ? toDouble(config['gratificacao']) : 0.0;
    final base = totalProventos - gratificacao;
    return base * percentual / 100;
  }

  double calcularSeguroVidaComplementar(String opcao) {
    if (opcao == 'Nao Utilizo') return 0;
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
                gradient: LinearGradient(colors: [AppColors.navy.withValues(alpha: 0.05), AppColors.blue.withValues(alpha: 0.06)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swipe_outlined, color: AppColors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMobile ? 'Deslize a tabela para os lados.' : 'Tabela no padrão operacional, com visual mais limpo.',
                      style: const TextStyle(color: Color(0xFF536273), fontSize: 13, fontWeight: FontWeight.w700),
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
    final proventos = (holerite['proventos'] as List<dynamic>? ?? []).map(toStringDynamicMap).toList();
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = (holerite['descontos'] as List<dynamic>? ?? []).map(toStringDynamicMap).toList();
    final salario = toStringDynamicMap(holerite['salario']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                buildSalarySummaryCard('Proventos', formatarMoeda(salario['proventos'], 'BRL'), Icons.trending_up_outlined, AppColors.blue, constraints.maxWidth, isMobile),
                buildSalarySummaryCard('Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}', Icons.trending_down_outlined, const Color(0xFFE53935), constraints.maxWidth, isMobile),
                buildSalarySummaryCard('Líquido', formatarMoeda(salario['salario_liquido'], 'BRL'), Icons.account_balance_wallet_outlined, AppColors.green, constraints.maxWidth, isMobile, highlight: true),
              ],
            ),
            const SizedBox(height: 22),
            buildModernSectionTitle('Proventos', 'Valores calculados a partir da escala importada.'),
            const SizedBox(height: 12),
            ...proventos.map((linha) => buildModernSalaryLine(
                  title: linha['descricao']?.toString() ?? '',
                  subtitle: buildProventoSubtitle(linha),
                  value: formatarMoeda(linha['final'], 'BRL'),
                  icon: iconForProvento(linha['descricao']?.toString() ?? ''),
                  accent: AppColors.blue,
                )),
            const SizedBox(height: 18),
            buildModernSectionTitle('Base de IR', 'Base tributável usada para calcular o IRRF.'),
            const SizedBox(height: 12),
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
            const SizedBox(height: 18),
            buildModernSectionTitle('Descontos', 'Ajuste os benefícios e confira o impacto no líquido.'),
            const SizedBox(height: 12),
            ...descontos.map((linha) => buildModernDiscountLine(linha)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.green.withValues(alpha: 0.14), AppColors.cyan.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.check_circle_outline, color: AppColors.green),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Salário líquido estimado', style: TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                  Text(
                    formatarMoeda(salario['salario_liquido'], 'BRL'),
                    style: const TextStyle(color: AppColors.green, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildSalarySummaryCard(String title, String value, IconData icon, Color color, double maxWidth, bool isMobile, {bool highlight = false}) {
    final width = isMobile ? maxWidth : ((maxWidth - 28) / 3).clamp(190.0, 330.0);
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.10) : const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: highlight ? 0.28 : 0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(title.toUpperCase(), style: TextStyle(color: AppColors.navy.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 14),
        Text(value, style: TextStyle(color: highlight ? color : AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ]),
    );
  }

  Widget buildModernSectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF6A778A), fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget buildModernSalaryLine({required String title, required String subtitle, required String value, required IconData icon, required Color accent}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF6)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w900)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF728096), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        Text(value, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget buildModernDiscountLine(Map<String, dynamic> linha) {
    final label = linha['descricao']?.toString() ?? '';
    final value = formatarMoeda(linha['valor'], 'BRL');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E2E2)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final control = SizedBox(width: mobile ? double.infinity : 250, child: excelDiscountOptionCell(label, linha['opcao'], width: mobile ? constraints.maxWidth : 250));
        final left = Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.payments_outlined, color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w900))),
        ]);

        if (mobile) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            left,
            const SizedBox(height: 10),
            control,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text(value, style: const TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900))),
          ]);
        }

        return Row(children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          control,
          const SizedBox(width: 12),
          SizedBox(width: 120, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900))),
        ]);
      }),
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
    if (text.contains('SALARIO')) return Icons.badge_outlined;
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 850,
        child: Column(children: [
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
          excelTotalRow('TOTAL PROVENTOS', formatarMoeda(salario['proventos'], 'BRL')),
          excelBlankRow(),
          excelSectionRow('BASE DE IR'),
          excelTwoColumnRow('Total Proventos', formatarMoeda(baseIr['total_proventos'], 'BRL')),
          excelTwoColumnRow('INSS Remuneração', '-${formatarMoeda(baseIr['inss_remuneracao'], 'BRL')}'),
          excelTotalRow('Base de IR', formatarMoeda(baseIr['base_ir'], 'BRL')),
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
          excelTotalRow('DESCONTO TOTAL', formatarMoeda(salario['descontos'], 'BRL')),
          excelBlankRow(),
          excelSectionRow('SALARIO'),
          excelTwoColumnRow('Proventos', formatarMoeda(salario['proventos'], 'BRL')),
          excelTwoColumnRow('Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}'),
          excelSalaryLiquidRow(formatarMoeda(salario['salario_liquido'], 'BRL')),
        ]),
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.2),
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
        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  Widget excelHeaderRow(List<String> values) {
    return Row(children: [
      excelCell(values[0], width: 310, bold: true, center: true),
      excelCell(values[1], width: 185, bold: true, center: true),
      excelCell(values[2], width: 195, bold: true, center: true),
      excelCell(values[3], width: 160, bold: true, center: true),
    ]);
  }

  Widget excelDataRow(List<String> values) {
    final isGratificacao = values[0] == 'Gratificação';

    return Row(children: [
      excelCell(values[0], width: 310, bold: true, align: TextAlign.left),
      isGratificacao ? excelGratificacaoCell(width: 185) : excelCell(values[1], width: 185),
      excelCell(values[2], width: 195),
      excelCell(values[3], width: 160),
    ]);
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
    return Row(children: [
      excelCell(label, width: 640, bold: false, align: TextAlign.left),
      excelCell(value, width: 210, bold: true),
    ]);
  }

  Widget excelDiscountRow(String label, dynamic option, String value) {
    return Row(children: [
      excelCell(label, width: 395, bold: true, align: TextAlign.left),
      excelDiscountOptionCell(label, option, width: 245),
      excelCell(value, width: 210, bold: true),
    ]);
  }

  Widget excelDiscountOptionCell(String label, dynamic option, {required double width}) {
    if (label == 'Previdencia Privada') {
      return excelDropdownCell<String>(
        width: width,
        value: previdenciaPrivada,
        items: const ['0%', '1%', '2%', '3%', '4%', '5%', '6%', '7%', '8%', '9%', '10%'],
        onChanged: (value) {
          if (value == null) return;
          setState(() => previdenciaPrivada = value);
        },
      );
    }

    if (label == 'Assistencia Medica AMIL') {
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

    if (label == 'Servico de Saude DASA') {
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
        onChanged: (value) => setState(() => seguroBradescoFuneral = value ?? false),
      );
    }

    if (label == 'Seguro de Vida Complementar') {
      return excelDropdownCell<String>(
        width: width,
        value: seguroVidaComplementar,
        items: const [
          'Nao Utilizo',
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
        itemLabel: (value) => value == 'Nao Utilizo' ? value : 'R\$ ${value.replaceAll('.', ',')}',
        onChanged: (value) {
          if (value == null) return;
          setState(() => seguroVidaComplementar = value);
        },
      );
    }

    if (label == 'Assistencia Odonto Familia') {
      return excelDropdownCell<String>(
        width: width,
        value: assistenciaOdontoFamilia,
        items: const [
          'Nao Utilizo',
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
          'Nao Utilizo',
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
      height: 35,
      decoration: BoxDecoration(
        color: AppColors.inputCell,
        border: Border.all(color: Colors.black26, width: 0.7),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            iconSize: 18,
            style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700),
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
      height: 35,
      decoration: BoxDecoration(
        color: AppColors.inputCell,
        border: Border.all(color: Colors.black26, width: 0.7),
      ),
      alignment: Alignment.center,
      child: Checkbox(
        value: value,
        activeColor: AppColors.blue,
        onChanged: onChanged,
      ),
    );
  }

  Widget excelTotalRow(String label, String value) {
    return Row(children: [
      excelCell(label, width: 640, bold: true, center: true),
      excelCell(value, width: 210, bold: true),
    ]);
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
    return Row(children: [
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
          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w900, fontSize: 16),
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
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    ]);
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              inconsistencias.isEmpty ? Icons.verified_outlined : Icons.warning_amber_rounded,
              color: inconsistencias.isEmpty ? Colors.green.shade700 : Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            const Text(
              'Validador da Escala',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.navy),
            ),
          ]),
          const SizedBox(height: 14),
          if (inconsistencias.isEmpty)
            const Text(
              'Nenhuma inconsistência crítica encontrada na importação atual.',
              style: TextStyle(color: Color(0xFF536273), fontWeight: FontWeight.w600),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: inconsistencias.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  List<String> coletarInconsistencias() {
    final problemas = <String>[];
    final voosSemDistancia = (resumo['voos_sem_distancia'] as List<dynamic>? ?? []);

    if (voosSemDistancia.isNotEmpty) {
      problemas.add('Existem voos sem distância calculada: ${voosSemDistancia.join(', ')}.');
    }

    if (escalaEventos.isEmpty && selectedFileName != null) {
      problemas.add('O arquivo foi importado, mas nenhum evento foi tratado.');
    }

    final eventosSemStatus = escalaEventos.where((event) => (event['status'] ?? '').trim().isEmpty).length;
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
      problemas.add('$semDutyReport linhas possuem diária marcada sem Duty Report visível.');
    }

    return problemas;
  }

  Widget buildHistorySection() {
    if (historicoImportacoes.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Histórico da Sessão',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.navy),
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
                return DataRow(cells: [
                  DataCell(Text(item['arquivo']?.toString() ?? '')),
                  DataCell(Text(item['cargo']?.toString() ?? '')),
                  DataCell(Text(item['voos']?.toString() ?? '0')),
                  DataCell(Text(item['eventos']?.toString() ?? '0')),
                  DataCell(Text(formatarMoeda(item['proventos'], 'BRL'))),
                  DataCell(Text(formatarMoeda(item['descontos'], 'BRL'))),
                  DataCell(Text(formatarMoeda(item['liquido'], 'BRL'))),
                ]);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget buildDiariasResumoSection(Map<String, dynamic> diarias) {
    if (diarias.isEmpty) return const SizedBox.shrink();

    final grupos = ['NACIONAL', 'ARGENTINA', 'CHILE', 'AMERICA_DO_SUL'];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Resumo de Diárias',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nacional em R\$ e internacional em US\$. Exterior convertido no topo pela cotação automática.',
            style: TextStyle(color: Color(0xFF617086), fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: grupos.map((grupo) {
              final dadosGrupo = toStringDynamicMap(diarias[grupo]);
              final moeda = dadosGrupo['moeda']?.toString() ?? obterMoedaPadraoDoGrupo(grupo);

              return buildTabelaGrupoDiaria(
                grupo: grupo,
                dadosGrupo: dadosGrupo,
                moeda: moeda,
              );
            }).toList(),
          ),
        ]),
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
          diariaRow('Janta', dadosGrupo, 'jantar', moeda),
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

  TableRow diariaRow(String titulo, Map<String, dynamic> grupo, String refeicao, String moeda) {
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
      child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          buildEscalaWelcomeCard(),
          const SizedBox(height: 22),
          buildEscalaPeriodoSelector(),
          const SizedBox(height: 22),
          buildEscalaResumoRapido(),
          const SizedBox(height: 22),
          if (eventos.isEmpty)
            buildEscalaEmptyState()
          else
            buildEscalaTimeline(eventos),
        ],
      ),
    );
  }

  Widget buildEscalaWelcomeCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;

        final mainContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: isMobile ? 38 : 44,
              width: isMobile ? 132 : 150,
              child: Image.asset(
                'assets/logo_crew4u.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (context, error, stackTrace) {
                  return buildTextLogo(fontSize: isMobile ? 23 : 25, fourSize: isMobile ? 34 : 39, dark: false);
                },
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Olá, ',
                    style: TextStyle(color: Colors.white, fontSize: isMobile ? 30 : 34, fontWeight: FontWeight.w400),
                  ),
                  TextSpan(
                    text: 'Rafael',
                    style: TextStyle(color: AppColors.blue, fontSize: isMobile ? 30 : 34, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              selectedFileName == null
                  ? 'Importe sua escala para visualizar a rotina de voo.'
                  : 'Sua escala está pronta para consulta offline no navegador. A aba Salário usa estes dados para calcular o holerite.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: isMobile ? 13 : 15,
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
              const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                mesReferenciaEscala(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
            ],
          ),
        );

        return Container(
          padding: EdgeInsets.all(isMobile ? 22 : 26),
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
                right: isMobile ? -16 : 18,
                bottom: isMobile ? -18 : -12,
                child: Opacity(
                  opacity: 0.09,
                  child: Icon(Icons.flight_takeoff, size: isMobile ? 110 : 155, color: AppColors.cyan),
                ),
              ),
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mainContent,
                        const SizedBox(height: 16),
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

  Widget buildEscalaPeriodoSelector() {
    final periodos = ['Hoje', 'Semana', 'Mês'];

    return Container(
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: periodos.map((periodo) {
          final selected = escalaPeriodo == periodo;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => escalaPeriodo = periodo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? const LinearGradient(colors: [AppColors.blue, AppColors.cyan]) : null,
                  color: selected ? null : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.30)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  periodo,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.navy,
                    fontSize: 15,
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
    final horasVoo = formatarMinutosComoHoras(resumoPeriodo['minutos_voo'] ?? 0);
    final kmTotal = resumoPeriodo['km'] ?? 0;
    final reservas = resumoPeriodo['reservas'] ?? 0;
    final sobreavisos = resumoPeriodo['sobreavisos'] ?? 0;
    final folgas = resumoPeriodo['folgas'] ?? 0;
    final contexto = contextoResumoSelecionado();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final cardWidth = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 48) / 5;

        final cards = Wrap(
          spacing: isMobile ? 8 : 12,
          runSpacing: isMobile ? 8 : 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: buildEscalaMetricCard(
                icon: Icons.schedule_outlined,
                title: 'Horas de voo',
                value: horasVoo,
                subtitle: contexto,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: buildEscalaMetricCard(
                icon: Icons.route_outlined,
                title: 'Km voados',
                value: formatarNumeroInteiro(kmTotal),
                subtitle: contexto,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: buildEscalaMetricCard(
                icon: Icons.event_available_outlined,
                title: 'Reservas',
                value: reservas.toString(),
                subtitle: contexto,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: buildEscalaMetricCard(
                icon: Icons.notifications_active_outlined,
                title: 'Sobreavisos',
                value: sobreavisos.toString(),
                subtitle: contexto,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: buildEscalaMetricCard(
                icon: Icons.weekend_outlined,
                title: 'Folgas',
                value: folgas.toString(),
                subtitle: contexto,
              ),
            ),
          ],
        );

        if (!isMobile) return cards;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => resumoEscalaAberto = !resumoEscalaAberto),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.dashboard_customize_outlined, color: AppColors.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Resumo da escala • $contexto',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        resumoEscalaAberto ? 'Ocultar' : 'Ver',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Icon(resumoEscalaAberto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: cards,
                ),
                crossFadeState: resumoEscalaAberto ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildEscalaMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navy2]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.w600),
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
              child: const Icon(Icons.upload_file_outlined, color: AppColors.blue, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nenhuma escala importada ainda',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clique em “Importar escala” no canto superior direito para carregar o Excel e gerar sua linha do tempo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF617086), fontSize: 15, fontWeight: FontWeight.w600),
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
        return buildDiaEscalaCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget buildDiaEscalaCard(String data, List<Map<String, String>> eventos) {
    final partes = data.split('/');
    final dia = partes.isNotEmpty ? partes[0] : data;
    final mes = partes.length >= 2 ? nomeMesCurto(partes[1]) : '';
    final semana = diaSemanaCurto(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;

        final dateBox = SizedBox(
          width: isMobile ? 58 : 76,
          child: Column(
            children: [
              Text(
                semana,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: isMobile ? 11 : 13, fontWeight: FontWeight.w900),
              ),
              Text(
                dia,
                style: TextStyle(color: Colors.white, fontSize: isMobile ? 29 : 34, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              Text(
                mes,
                style: TextStyle(color: AppColors.blue, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );

        return Container(
          key: escalaDiaKeys.putIfAbsent(data, () => GlobalKey()),
          margin: const EdgeInsets.only(bottom: 14),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF071A34).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dateBox,
              Container(width: 1, height: (eventos.length * 88).clamp(88, 300).toDouble(), color: AppColors.blue.withValues(alpha: 0.24)),
              SizedBox(width: isMobile ? 10 : 16),
              Expanded(
                child: Column(
                  children: buildEventosComApresentacao(eventos),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> buildEventosComApresentacao(List<Map<String, String>> eventos) {
    final widgets = <Widget>[];
    String? ultimoDutyReport;

    for (var i = 0; i < eventos.length; i++) {
      final event = eventos[i];
      final dutyReport = horarioLimpo(event['duty_report'] ?? '');
      final tipoAtual = (event['tipo'] ?? '').toUpperCase().trim();
      final deveMostrarApresentacao = tipoAtual == 'VOO' && dutyReport.isNotEmpty && dutyReport != ultimoDutyReport;

      if (deveMostrarApresentacao) {
        final analise = calcularLimiteJornadaDaEscala(eventos, i, dutyReport);
        widgets.add(buildDutyReportBanner(dutyReport, analise));
        ultimoDutyReport = dutyReport;
      }

      widgets.add(buildEventoEscalaRow(event));
    }

    return widgets;
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
      return {
        'disponivel': false,
      };
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

  Widget buildDutyReportBanner(String dutyReport, Map<String, dynamic> analise) {
    final disponivel = analise['disponivel'] == true;
    final terminoTexto = disponivel ? analise['termino_texto'].toString() : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D223D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final limiteChip = disponivel
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 6),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.28)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timelapse_outlined, size: compact ? 12 : 13, color: AppColors.cyan),
                  const SizedBox(width: 5),
                  Text(
                    'Limite de jornada $terminoTexto',
                    style: TextStyle(color: AppColors.cyan, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w900),
                  ),
                ]),
              )
            : const SizedBox.shrink();

        if (compact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.login_outlined, color: AppColors.cyan, size: 16),
              const SizedBox(width: 7),
              const Text('Apresentação', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(dutyReport, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            ]),
            if (disponivel) ...[
              const SizedBox(height: 7),
              limiteChip,
            ],
          ]);
        }

        return Row(children: [
          const Icon(Icons.login_outlined, color: AppColors.cyan, size: 17),
          const SizedBox(width: 8),
          const Text('Apresentação', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Text(dutyReport, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          if (disponivel) ...[
            const SizedBox(width: 12),
            limiteChip,
          ],
        ]);
      }),
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
    final isSobreaviso = tipo.contains('SOBREAVISO') || idUpper.startsWith('HSB');
    final isReserva = tipo.contains('RESERVA') || idUpper.startsWith('ASB');
    final isFolga = ehFolgaOuDayOff(event);
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
    } else {
      color = AppColors.green;
      icon = Icons.event_note_outlined;
      label = tipo.isEmpty ? 'Escala' : tipo;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;

        final tag = Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSobreaviso ? 0.92 : 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isMobile ? 16 : 18),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 13)),
            ],
          ),
        );

        final routeContent = isVoo
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildAirportTime(saida, origem, compact: isMobile),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
                    child: const Icon(Icons.arrow_forward, color: AppColors.blue, size: 24),
                  ),
                  buildAirportTime(chegada, destino, compact: isMobile),
                ],
              )
            : Text(
                isFolga ? 'Dia livre' : formatarIntervaloEvento(saida, chegada),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w800),
              );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        tag,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            id,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (duracaoTexto.isNotEmpty) buildDurationChip(duracaoTexto, color, compact: true),
                        const Spacer(),
                        Flexible(child: Align(alignment: Alignment.centerRight, child: routeContent)),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    tag,
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 92,
                      child: Text(
                        id,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (duracaoTexto.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      buildDurationChip(duracaoTexto, color),
                    ],
                    Expanded(child: Align(alignment: Alignment.centerRight, child: routeContent)),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
        );
      },
    );
  }

  Widget buildDurationChip(String text, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, color: color.withValues(alpha: 0.92), size: compact ? 12 : 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
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
    if (ehFolgaOuDayOff(event)) return DateTime(dataBase.year, dataBase.month, dataBase.day, 0, 0);

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
    return DateTime(dataBase.year, dataBase.month, dataBase.day + extraDias, minutos ~/ 60, minutos % 60);
  }

  DateTime? fimAtividadeDateTime(Map<String, String> event) {
    final dataBase = parseDataPtBr(event['data'] ?? '');
    if (dataBase == null) return null;

    final tipo = (event['tipo'] ?? '').toUpperCase();
    final isVoo = tipo == 'VOO';
    if (ehFolgaOuDayOff(event)) return DateTime(dataBase.year, dataBase.month, dataBase.day, 23, 59);

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
    return DateTime(dataBase.year, dataBase.month, dataBase.day + extraDias, minutos ~/ 60, minutos % 60);
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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          airport,
          style: TextStyle(color: Colors.white, fontSize: compact ? 18 : 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
        ),
      ],
    );
  }

  List<Map<String, String>> eventosPrincipaisDaEscala() {
    final referencia = referenciaPeriodoEscala();
    final inicioJanela = inicioDaJanelaEscala(referencia);
    final fimJanela = fimDaJanelaEscala(referencia);
    final mesReferencia = mesAnoReferenciaEscala();

    final base = escalaEventos.where((event) {
      if (!ehEventoVisivelNaEscala(event)) return false;

      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) return false;

      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;

      if (escalaPeriodo == 'Hoje') {
        return mesmoDia(inicioEfetivo, referencia) || mesmoDia(fimEfetivo, referencia);
      }

      if (escalaPeriodo == 'Semana') {
        return !fimEfetivo.isBefore(inicioJanela) &&
            (fimJanela == null || !inicioEfetivo.isAfter(fimJanela));
      }

      // No modo Mês a escala mostra o mês inteiro importado.
      // A tela apenas rola automaticamente até hoje/próxima atividade.
      if (mesReferencia != null) {
        return inicioEfetivo.year == mesReferencia.year && inicioEfetivo.month == mesReferencia.month;
      }

      return true;
    }).toList();

    base.sort((a, b) {
      final dataA = inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
      final dataB = inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
      return dataA.compareTo(dataB);
    });

    return base;
  }

  void agendarAutoScrollEscala(List<Map<String, String>> eventos) {
    if (selectedIndex != 0 || escalaPeriodo != 'Mês' || eventos.isEmpty) return;

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
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        final retryContext = key?.currentContext;
        if (retryContext == null) return;
        Scrollable.ensureVisible(
          retryContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      });
    });
  }

  String? dataAlvoScrollEscala(List<Map<String, String>> eventos) {
    final hoje = DateTime.now();
    final datas = eventos
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
        ehFolgaOuDayOff(event) ||
        id.startsWith('HSB') ||
        id.startsWith('ASB');
  }

  DateTime inicioDaJanelaEscala(DateTime referencia) {
    final mesReferencia = mesAnoReferenciaEscala();
    if (mesReferencia != null) return DateTime(mesReferencia.year, mesReferencia.month, 1);
    return DateTime(referencia.year, referencia.month, 1);
  }

  DateTime? fimDaJanelaEscala(DateTime referencia) {
    if (escalaPeriodo == 'Hoje') {
      return DateTime(referencia.year, referencia.month, referencia.day, 23, 59, 59);
    }

    if (escalaPeriodo == 'Semana') {
      return DateTime(referencia.year, referencia.month, referencia.day + 6, 23, 59, 59);
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
    final mesReferencia = mesAnoReferenciaEscala();

    if (mesReferencia != null && mesReferencia.year == agora.year && mesReferencia.month == agora.month) {
      return agora;
    }

    final datas = escalaEventos
        .map((event) => inicioEventoDateTime(event) ?? fimEventoDateTime(event))
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
        minutosVoo += diferencaMinutos(event['saida'] ?? '', event['chegada'] ?? '');
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

  List<Map<String, String>> eventosParaResumoSelecionado() {
    final referencia = referenciaPeriodoEscala();
    final inicioJanela = inicioDaJanelaEscala(referencia);
    final fimJanela = fimDaJanelaEscala(referencia);
    final mesReferencia = mesAnoReferenciaEscala();

    final eventos = escalaEventos.where((event) {
      if (!ehEventoVisivelNaEscala(event)) return false;

      final inicio = inicioEventoDateTime(event);
      final fim = fimEventoDateTime(event);
      if (inicio == null && fim == null) return false;

      final inicioEfetivo = inicio ?? fim!;
      final fimEfetivo = fim ?? inicioEfetivo;

      if (escalaPeriodo == 'Hoje') {
        return mesmoDia(inicioEfetivo, referencia) || mesmoDia(fimEfetivo, referencia);
      }

      if (escalaPeriodo == 'Semana') {
        return !fimEfetivo.isBefore(inicioJanela) &&
            (fimJanela == null || !inicioEfetivo.isAfter(fimJanela));
      }

      if (mesReferencia != null) {
        return inicioEfetivo.month == mesReferencia.month &&
            inicioEfetivo.year == mesReferencia.year;
      }

      return true;
    }).toList();

    eventos.sort((a, b) {
      final dataA = inicioEventoDateTime(a) ?? fimEventoDateTime(a) ?? DateTime(2100);
      final dataB = inicioEventoDateTime(b) ?? fimEventoDateTime(b) ?? DateTime(2100);
      return dataA.compareTo(dataB);
    });

    return eventos;
  }

  String contextoResumoSelecionado() {
    if (escalaPeriodo == 'Hoje') return 'hoje';
    if (escalaPeriodo == 'Semana') return '7 dias';
    return mesReferenciaEscala();
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
    if (ehFolgaOuDayOff(event)) return DateTime(dataBase.year, dataBase.month, dataBase.day, 0, 0);

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
    if (ehFolgaOuDayOff(event)) return DateTime(dataBase.year, dataBase.month, dataBase.day, 23, 59);

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

    var fim = DateTime(
      dataBase.year,
      dataBase.month,
      dataBase.day + extraDias,
      minutosFim ~/ 60,
      minutosFim % 60,
    );

    if (inicio != null && fim.isBefore(inicio)) {
      fim = fim.add(const Duration(days: 1));
    }

    return fim;
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

  Map<String, List<Map<String, String>>> agruparEventosPorData(List<Map<String, String>> eventos) {
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
            : 'Cálculo pela Tabela B.1 para tripulação simples aclimatada.';

    return buildPageShell(
      title: 'Jornada',
      subtitle: 'Calcule limite de jornada, horário de término e corte dos motores.',
      icon: Icons.timer_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 760;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF020817), Color(0xFF071A34), Color(0xFF031024)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.28)),
                          ),
                          child: const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calculadora de Jornada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 23 : 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                aviso,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: buildJornadaSwitchCard(),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: buildJornadaDropdown<String>(
                            label: 'Fuso da apresentação',
                            icon: Icons.public_outlined,
                            value: jornadaFusoApresentacao,
                            items: fusosBrasil.keys.toList(),
                            onChanged: (value) => setState(() => jornadaFusoApresentacao = value ?? jornadaFusoApresentacao),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: buildJornadaDropdown<String>(
                            label: 'Fuso do último destino',
                            icon: Icons.place_outlined,
                            value: jornadaFusoUltimoDestino,
                            items: fusosBrasil.keys.toList(),
                            onChanged: (value) => setState(() => jornadaFusoUltimoDestino = value ?? jornadaFusoUltimoDestino),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 260,
                          child: buildJornadaDropdown<String>(
                            label: 'Tipo de tripulação',
                            icon: Icons.groups_2_outlined,
                            value: jornadaTripulacao,
                            items: const ['Simples', 'Composta', 'Revezamento'],
                            onChanged: (value) => setState(() => jornadaTripulacao = value ?? jornadaTripulacao),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 220,
                          child: buildJornadaDropdown<int>(
                            label: 'Etapas / voos',
                            icon: Icons.flight_takeoff_outlined,
                            value: jornadaEtapas,
                            items: const [1, 2, 3, 4, 5, 6, 7, 8],
                            formatter: (value) => value >= 7 ? '7+ etapas' : '$value etapa${value == 1 ? '' : 's'}',
                            onChanged: (value) => setState(() => jornadaEtapas = value ?? jornadaEtapas),
                          ),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 220,
                          child: buildHorarioApresentacaoCard(),
                        ),
                        SizedBox(
                          width: isMobile ? double.infinity : 360,
                          child: buildExtensaoJornadaCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    buildJornadaResultado(calc, isMobile: isMobile),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              buildTabelaB1Visual(),
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

  Widget buildJornadaSwitchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: jornadaInputDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.access_time_filled_outlined, color: AppColors.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aclimatado',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          Switch(
            value: jornadaAclimatado,
            activeColor: AppColors.cyan,
            onChanged: (value) => setState(() => jornadaAclimatado = value),
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
        padding: const EdgeInsets.all(16),
        decoration: jornadaInputDecoration(),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.schedule_outlined, color: AppColors.cyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apresentação',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatarTimeOfDay(jornadaApresentacao),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.all(16),
      decoration: jornadaInputDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6B21A).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.more_time_outlined, color: Color(0xFFF6B21A), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Extensão de jornada',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: jornadaHouveExtensao,
                activeColor: const Color(0xFFF6B21A),
                onChanged: (value) => setState(() {
                  jornadaHouveExtensao = value;
                  if (!value) jornadaMinutosExcedidos = 0;
                }),
              ),
            ],
          ),
          if (jornadaHouveExtensao) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Minutos excedidos',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '$minutos min',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
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
              onChanged: (value) => setState(() => jornadaMinutosExcedidos = value),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hotel_outlined, color: Colors.white.withValues(alpha: 0.70), size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Descanso mínimo: ${formatarMinutosComoDuracao(descanso)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Regra aplicada: 12h + dobro dos minutos excedidos.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Sem extensão: descanso mínimo base de 12h.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: jornadaInputDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.navy2,
                iconEnabledColor: Colors.white70,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.48), fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(formatter?.call(item) ?? item.toString(), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return items.map((item) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          formatter?.call(item) ?? item.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
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
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    );
  }

  Widget buildJornadaResultado(Map<String, dynamic> calc, {required bool isMobile}) {
    final limiteJornada = calc['limite_jornada_texto'] as String;
    final limiteVoo = calc['limite_voo_texto'] as String;
    final termino = calc['termino_texto'] as String;
    final corte = calc['corte_texto'] as String;
    final faixa = calc['faixa'] as String;
    final coluna = calc['coluna'] as String;
    final fusoDestino = calc['fuso_destino'] as String;
    final descansoMinimo = calc['descanso_minimo_texto'] as String;
    final minutosExcedidos = calc['minutos_excedidos'] as int;

    final cards = [
      buildResultadoJornadaCard(Icons.timelapse_outlined, 'Limite de jornada', limiteJornada, 'Tabela B.1 • $faixa • $coluna', AppColors.blue),
      buildResultadoJornadaCard(Icons.flight_land_outlined, 'Corte dos motores', corte, '30 min antes do término', const Color(0xFFF6B21A)),
      buildResultadoJornadaCard(Icons.flag_outlined, 'Término da jornada', termino, 'Hora local: $fusoDestino', AppColors.green),
      buildResultadoJornadaCard(Icons.flight_outlined, 'Limite de voo', limiteVoo, 'Tempo máximo de voo', AppColors.cyan),
      buildResultadoJornadaCard(Icons.hotel_outlined, 'Descanso mínimo', descansoMinimo, minutosExcedidos > 0 ? '12h + 2 × $minutosExcedidos min' : 'Sem extensão de jornada', const Color(0xFF9AA7FF)),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards.map((card) {
        return SizedBox(
          width: isMobile ? double.infinity : 260,
          child: card,
        );
      }).toList(),
    );
  }

  Widget buildResultadoJornadaCard(IconData icon, String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 5),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w600)),
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
          const Text('Tabela B.1 usada no cálculo', style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('O número fora dos parênteses é jornada máxima. O número entre parênteses é tempo máximo de voo.', style: TextStyle(color: Color(0xFF607086), fontSize: 13, fontWeight: FontWeight.w600)),
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
                return DataRow(cells: linha.map((cell) => DataCell(Text(cell, style: const TextStyle(fontWeight: FontWeight.w700)))).toList());
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int calcularDescansoMinimoMinutos() {
    final excedidos = jornadaHouveExtensao ? jornadaMinutosExcedidos.round() : 0;
    return (12 * 60) + (2 * excedidos);
  }

  Map<String, dynamic> calcularJornadaManual() {
    final reportMin = jornadaApresentacao.hour * 60 + jornadaApresentacao.minute;
    final row = linhaTabelaB1(reportMin);
    final col = colunaTabelaB1(jornadaEtapas);
    final valores = tabelaB1()[row]![col]!;

    final limiteJornadaMin = (valores[0] * 60).round();
    final limiteVooMin = (valores[1] * 60).round();

    final offsetOrigem = fusosBrasil[jornadaFusoApresentacao] ?? -3;
    final offsetDestino = fusosBrasil[jornadaFusoUltimoDestino] ?? -3;

    final base = DateTime(2026, 1, 1, jornadaApresentacao.hour, jornadaApresentacao.minute);
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
      'minutos_excedidos': jornadaHouveExtensao ? jornadaMinutosExcedidos.round() : 0,
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
      '06:00–06:59': {'1-2': [11, 9], '3-4': [11, 9], '5': [10, 8], '6': [9, 8], '7+': [9, 8]},
      '07:00–07:59': {'1-2': [13, 9.5], '3-4': [12, 9], '5': [11, 9], '6': [10, 8], '7+': [9, 8]},
      '08:00–11:59': {'1-2': [13, 10], '3-4': [13, 9.5], '5': [12, 9], '6': [11, 9], '7+': [10, 8]},
      '12:00–13:59': {'1-2': [12, 9.5], '3-4': [12, 9], '5': [11, 9], '6': [10, 8], '7+': [9, 8]},
      '14:00–15:59': {'1-2': [11, 9], '3-4': [11, 9], '5': [10, 8], '6': [9, 8], '7+': [9, 8]},
      '16:00–17:59': {'1-2': [10, 8], '3-4': [10, 8], '5': [9, 8], '6': [9, 8], '7+': [9, 8]},
      '18:00–05:59': {'1-2': [9, 8], '3-4': [9, 8], '5': [9, 7], '6': [9, 7], '7+': [9, 7]},
    };
  }

  String formatarTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String formatarHoraDateTime(DateTime dt) {
    final hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final diaOffset = dt.day - 1;
    if (diaOffset <= 0) return hora;
    return '$hora +$diaOffset';
  }

  String formatarHoraDateTimeComBase(DateTime dt, DateTime dataBase) {
    final hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
      subtitle: selectedFileName == null ? 'Nenhuma escala importada.' : 'Visão técnica tipo Excel: $selectedFileName',
      icon: Icons.table_chart_outlined,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: escalaEventos.isEmpty
              ? const Center(
                  child: Text(
                    'Importe uma escala Excel para visualizar a tabela técnica.',
                    style: TextStyle(color: Color(0xFF536273), fontWeight: FontWeight.w600),
                  ),
                )
              : buildEventosTable(),
        ),
      ),
    );
  }

  Widget buildEventosTable() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
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
              DataColumn(label: Text('Janta')),
              DataColumn(label: Text('Ceia')),
              DataColumn(label: Text('Grupo Diária')),
              DataColumn(label: Text('Moeda')),
              DataColumn(label: Text('Status')),
            ],
            rows: escalaEventos.map((event) {
              return DataRow(cells: [
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
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget buildConfigPage() {
    return buildPageShell(
      title: 'Configurações',
      subtitle: 'Valores de cargos, benefícios, descontos e parâmetros do simulador.',
      icon: Icons.settings_outlined,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edite os valores e pressione Enter em cada campo. Depois clique em salvar para manter no navegador.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF536273), fontWeight: FontWeight.w600),
                    ),
                  ),
                  PrimaryButton(icon: Icons.save_outlined, label: 'Salvar configs', onTap: salvarConfiguracoesLocais),
                  const SizedBox(width: 10),
                  SecondaryButton(icon: Icons.currency_exchange, label: 'Atualizar dólar', onTap: carregarCotacaoDolar),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          buildCargoConfigEditor(),
        ],
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cargo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navy)),
                const SizedBox(height: 16),
                ...campos.map((campo) {
                  return buildConfigField(
                    cargo: cargo,
                    campo: campo,
                    valor: config[campo] ?? 0,
                  );
                }),
              ]),
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
      text: valor.toStringAsFixed(campo.startsWith('km') ? 6 : 2).replaceAll('.', ','),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Text(
            formatarCampoConfig(campo),
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ]),
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
    final voosSemDistancia = (resumo['voos_sem_distancia'] as List<dynamic>? ?? []);

    return buildPageShell(
      title: 'Aeroportos',
      subtitle: 'Corrija rotas sem distância e mantenha uma lista local de aeroportos pendentes.',
      icon: Icons.place_outlined,
      child: ListView(
        padding: EdgeInsets.zero,
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
                      style: const TextStyle(fontSize: 15, color: Color(0xFF536273), fontWeight: FontWeight.w700),
                    ),
                  ),
                  PrimaryButton(icon: Icons.add_location_alt_outlined, label: 'Adicionar aeroporto', onTap: abrirDialogAdicionarAeroporto),
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
                      headingRowColor: WidgetStateProperty.all(AppColors.softBlue),
                      columns: const [
                        DataColumn(label: Text('IATA')),
                        DataColumn(label: Text('ICAO')),
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('Latitude')),
                        DataColumn(label: Text('Longitude')),
                      ],
                      rows: aeroportosLocais.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item['iata']?.toString() ?? '')),
                          DataCell(Text(item['icao']?.toString() ?? '')),
                          DataCell(Text(item['nome']?.toString() ?? '')),
                          DataCell(Text(item['lat']?.toString() ?? '')),
                          DataCell(Text(item['lon']?.toString() ?? '')),
                        ]);
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              dialogField(iata, 'IATA'),
              dialogField(icao, 'ICAO'),
              dialogField(nome, 'Nome'),
              dialogField(lat, 'Latitude'),
              dialogField(lon, 'Longitude'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  void imprimirPdfEscala() {
    if (escalaEventos.isEmpty) {
      showSnack('Importe uma escala antes de gerar o PDF.');
      return;
    }

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
      final cls = tipo == 'VOO' ? 'voo' : tipo.contains('RESERVA') ? 'reserva' : tipo.contains('SOBREAVISO') ? 'sobreaviso' : 'folga';
      final detalhe = tipo == 'VOO' ? '$origem → $destino' : (isFolga ? 'Dia livre' : formatarIntervaloEvento(saida, chegada));
      final horario = isFolga ? '' : (tipo == 'VOO' ? '$saida – $chegada' : formatarIntervaloEvento(saida, chegada));
      return '<div class="event $cls"><div><b>${esc(isFolga ? 'FOLGA' : tipo)}</b> ${esc(id)}</div><div>${esc(detalhe)}</div><div>${esc(horario)}</div></div>';
    }

    String jornadaHtml(List<Map<String, String>> eventosDoDia) {
      final parts = <String>[];
      String? ultimoReport;

      for (var i = 0; i < eventosDoDia.length; i++) {
        final event = eventosDoDia[i];
        final tipo = (event['tipo'] ?? '').toUpperCase();
        final dutyReport = horarioLimpo(event['duty_report'] ?? '');

        if (tipo == 'VOO' && dutyReport.isNotEmpty && dutyReport != ultimoReport) {
          final analise = calcularLimiteJornadaDaEscala(eventosDoDia, i, dutyReport);
          final limite = analise['limite_jornada_horario']?.toString() ?? '';
          parts.add('<div class="report"><b>Apresentação</b> ${esc(dutyReport)}${limite.isNotEmpty ? ' · Limite de jornada ${esc(limite)}' : ''}</div>');
          ultimoReport = dutyReport;
        }

        parts.add(eventHtml(event));
      }

      return parts.join();
    }

    final dias = grouped.entries.map((entry) {
      final data = entry.key;
      final eventosHtml = jornadaHtml(entry.value);
      return '<section class="day"><h2>${esc(data)}</h2>$eventosHtml</section>';
    }).join();

    final content = """
<!doctype html>
<html>
<head>
<meta charset=\"utf-8\">
<title>Crew 4U - Escala</title>
<style>
  @page { size: A4; margin: 12mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, sans-serif; margin: 0; color: #061329; background: white; }
  .header { background: #061329; color: white; border-radius: 18px; padding: 18px; margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; }
  .logo { font-size: 28px; font-weight: 900; letter-spacing: -1px; }
  .logo span { color: #128DFF; }
  .sub { color: rgba(255,255,255,.70); font-size: 12px; margin-top: 4px; }
  .day { border: 1px solid #D8E2EE; border-radius: 14px; overflow: hidden; margin-bottom: 10px; page-break-inside: avoid; }
  h2 { margin: 0; padding: 9px 12px; background: #EAF5FF; font-size: 14px; color: #061329; }
  .report { margin: 9px 10px 0; padding: 8px 10px; border-radius: 10px; background: #E8F4FF; color: #075CA8; font-size: 11px; font-weight: 800; border: 1px solid #B9DAFF; }
  .event { display: grid; grid-template-columns: 1.1fr 1.2fr .9fr; gap: 8px; padding: 10px 12px; border-top: 1px solid #E6EEF7; font-size: 12px; align-items: center; }
  .voo { border-left: 5px solid #128DFF; }
  .reserva { border-left: 5px solid #E53935; }
  .sobreaviso { border-left: 5px solid #F5B31A; }
  .folga { border-left: 5px solid #19A65A; }
</style>
<script>window.onload = function() { setTimeout(function(){ window.print(); }, 300); };</script>
</head>
<body>
  <div class=\"header\">
    <div><div class=\"logo\">crew<span>4</span>u</div><div class=\"sub\">${esc(selectedFileName ?? '')}</div></div>
    <div>${esc(mesReferenciaEscala())}</div>
  </div>
  $dias
</body>
</html>
""";

    final blob = html.Blob([content], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }


  void imprimirPdfHolerite() {
    final holerite = calcularHoleriteLocal();
    final proventos = holerite['proventos'] as List<dynamic>;
    final baseIr = toStringDynamicMap(holerite['base_ir']);
    final descontos = holerite['descontos'] as List<dynamic>;
    final salario = toStringDynamicMap(holerite['salario']);
    final diarias = toStringDynamicMap(resumo['diarias']);

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
      final moeda = dados['moeda']?.toString() ?? obterMoedaPadraoDoGrupo(grupo);

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
          ${row('Janta', 'jantar')}
          ${row('Ceia', 'ceia')}
          <tr><td class="left"><b>TOTAL</b></td><td></td><td><b>${esc(formatarMoeda(dados['total'], moeda))}</b></td></tr>
        </table>
      ''';
    }

    final content = '''
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

    final blob = html.Blob([content], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  void exportarCsvHolerite() {
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

    rows.add(['TOTAL PROVENTOS', '', '', formatarMoeda(salario['proventos'], 'BRL')]);
    rows.add([]);

    rows.add(['BASE DE IR']);
    rows.add(['Total Proventos', formatarMoeda(baseIr['total_proventos'], 'BRL')]);
    rows.add(['INSS Remuneracao', '-${formatarMoeda(baseIr['inss_remuneracao'], 'BRL')}']);
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

    rows.add(['DESCONTO TOTAL', '', formatarMoeda(salario['descontos'], 'BRL')]);
    rows.add([]);

    rows.add(['SALARIO']);
    rows.add(['Proventos', formatarMoeda(salario['proventos'], 'BRL')]);
    rows.add(['Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}']);
    rows.add(['SALARIO LIQUIDO', formatarMoeda(salario['salario_liquido'], 'BRL')]);

    final csv = rows.map((row) {
      return row.map((cell) {
        final safe = cell.replaceAll('"', '""');
        return '"$safe"';
      }).join(';');
    }).join('\n');

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename = 'crew4u_holerite_${selectedCargo.toLowerCase()}.csv';

    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                  )
                ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ]),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.blue, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
