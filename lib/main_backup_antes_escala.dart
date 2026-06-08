
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
  int selectedIndex = 0;

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
  void initState() {
    super.initState();
    carregarConfiguracoesLocais();
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
        selectedIndex = 1;
        isLoading = false;
      });

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
      buildUploadPage(),
      buildHoleritePage(),
      buildEscalaPage(),
      buildConfigPage(),
      buildAeroportosPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          buildSidebar(),
          Expanded(child: pages[selectedIndex]),
        ],
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
          buildNavButton(0, Icons.upload_file_outlined, 'Upload'),
          buildNavButton(1, Icons.payments_outlined, 'Holerite'),
          buildNavButton(2, Icons.flight_takeoff_outlined, 'Escala'),
          buildNavButton(3, Icons.settings_outlined, 'Config'),
          buildNavButton(4, Icons.place_outlined, 'Aeroportos'),
          const Spacer(),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBFF), Color(0xFFEAF2FB)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            buildPageHeader(title: title, subtitle: subtitle, icon: icon),
            const SizedBox(height: 22),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navy2]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: AppColors.cyan, size: 29),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          buildTopBrand(),
        ],
      ),
    );
  }

  Widget buildTopBrand() {
    return SizedBox(
      height: 46,
      width: 150,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      title: 'Holerite',
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: buildExcelHoleriteBox(holerite),
                  ),
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

    return Container(
      padding: const EdgeInsets.all(26),
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
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.40)),
            ),
            child: const Icon(Icons.payments_outlined, color: AppColors.cyan, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Simulação Crew 4U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                selectedFileName == null ? 'Importe uma escala para gerar a simulação.' : '$selectedCargo • $selectedFileName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                Text(
                  'USD/BRL:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatarDecimal(cotacaoDolar, casas: 4),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Text(
                  cotacaoStatus,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: carregarCotacaoDolar,
                  child: Icon(
                    carregandoCotacao ? Icons.sync : Icons.refresh,
                    color: AppColors.cyan,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Diárias exterior em R\$: ${formatarMoeda(diariasUsdConvertidas, 'BRL')}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 18),
          buildHeaderMetric('Proventos', formatarMoeda(salario['proventos'], 'BRL')),
          const SizedBox(width: 10),
          buildHeaderMetric('Descontos', '-${formatarMoeda(salario['descontos'], 'BRL')}'),
          const SizedBox(width: 10),
          buildHeaderMetric('Líquido', formatarMoeda(salario['salario_liquido'], 'BRL'), highlight: true),
        ],
      ),
    );
  }

  Widget buildHeaderMetric(String title, String value, {bool highlight = false}) {
    return Container(
      width: 172,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
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
            fontSize: 17,
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
            'Holerite Calculado',
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

  Widget buildEscalaPage() {
    return buildPageShell(
      title: 'Escala',
      subtitle: selectedFileName == null ? 'Nenhuma escala importada.' : 'Eventos tratados do arquivo: $selectedFileName',
      icon: Icons.flight_takeoff_outlined,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: escalaEventos.isEmpty
              ? const Center(
                  child: Text(
                    'Importe uma escala Excel para visualizar os eventos tratados.',
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
<title>Crew 4U - Holerite</title>
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
      <h1>Simulação de Holerite</h1>
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
