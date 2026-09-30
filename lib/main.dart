// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:async';

import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/reports_screen.dart';
import 'screens/open_nc_screen.dart';
import 'screens/services_screen.dart';
import 'screens/diary_list_screen.dart';
import 'screens/diary_edit_screen.dart';
import 'screens/ficha_fvs_mode_screen.dart';
import 'screens/visual_tower_map_screen.dart';
import 'screens/empreiteiros_screen.dart';
import 'screens/almoxarifado_hub_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/cargo_record.dart';
import 'models/centro_custo_record.dart';
import 'models/company_record.dart';
import 'models/construtora_record.dart';
import 'models/cotacao_record.dart';
import 'models/descritivo_servico_record.dart';
import 'models/despesa_record.dart';
import 'models/diary_record.dart';
import 'models/employee_record.dart';
import 'models/equipamento_estoque_record.dart';
import 'models/fornecedor_record.dart';
import 'models/inspection_record.dart';
import 'models/insumo_obra_record.dart';
import 'models/material_catalogo_record.dart';
import 'models/medicao_empreiteiro_record.dart';
import 'models/orcamento_servico_record.dart';
import 'models/pedido_compra_record.dart';
import 'models/perfil_acesso_record.dart';
import 'models/recebimento_material_record.dart';
import 'models/requisicao_compra_record.dart';
import 'models/project_record.dart';
import 'models/project_invite_record.dart';
import 'models/project_access_code_record.dart';
import 'models/service_record.dart';
import 'models/user_org_membership.dart';
import 'models/user_project_membership.dart';
import 'services/auth_service.dart';
import 'services/app_update_service.dart';
import 'services/platform_service.dart';
import 'services/sync_orchestrator.dart';
import 'services/project_context_service.dart';
import 'services/project_members_service.dart';
import 'services/user_profile_service.dart';
import 'screens/compras_home_screen.dart';
import 'screens/construtoras_admin_screen.dart';
import 'screens/despesas_screen.dart';
import 'screens/funcionarios_screen.dart';
import 'screens/login_screen.dart';
import 'screens/project_members_screen.dart';
import 'screens/project_settings_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme_controller.dart';
import 'utils/app_date_utils.dart';
import 'utils/app_log.dart';
import 'utils/hive_box_helper.dart';
import 'utils/nc_utils.dart';
import 'utils/project_scope.dart';
import 'widgets/home_sidebar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveBoxHelper.checkAndRecoverIfNeeded();

  final needsReopen = HiveBoxHelper.hasCriticalFailure;
  if (needsReopen) {
    debugPrint('[BOOT] Recovery executado, reabrindo boxes essenciais...');
  }

  await _initializeFirebase();
  await _initializeHiveMinimal();

  final themeController = AppThemeController(Hive.box('prefs'));
  await themeController.load();

  runApp(ObraCheckApp(themeController: themeController));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startBackgroundServices();
  });
}

void _startBackgroundServices() {
  SyncOrchestrator.instance.start();
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

Future<void> _initializeHiveMinimal() async {
  await Hive.initFlutter();
  _registerHiveAdapters();
  await _openEssentialBoxes();
}

Future<void> _openEssentialBoxes() async {
  await HiveBoxHelper.openBoxSafe<InspectionRecord>('inspections');
  await HiveBoxHelper.openBoxSafe<ProjectRecord>('projects');
  await HiveBoxHelper.openBoxSafe<UserProjectMembership>(
    'user_project_memberships',
  );
  await HiveBoxHelper.openBoxRawSafe('prefs');
  await ProjectContextService.instance.ensureDefaultProject();
}

Future<void> _openLazyBoxes() async {
  await HiveBoxHelper.openBoxSafe<ServiceRecord>('services');
  await HiveBoxHelper.openBoxSafe<CompanyRecord>('companies');
  await HiveBoxHelper.openBoxSafe<DiaryRecord>('diaries');
  await HiveBoxHelper.openBoxSafe<ProjectInviteRecord>('project_invites');
  await HiveBoxHelper.openBoxSafe<ProjectAccessCodeRecord>(
    'project_access_codes',
  );
  await HiveBoxHelper.openBoxSafe<ConstrutoraRecord>('construtoras');
  await HiveBoxHelper.openBoxSafe<UserOrgMembership>('user_org_memberships');
  await HiveBoxHelper.openBoxSafe<CargoRecord>('cargos');
  await HiveBoxHelper.openBoxSafe<EmployeeRecord>('employees');
  await HiveBoxHelper.openBoxSafe<PerfilAcessoRecord>('perfis_acesso');
  await HiveBoxHelper.openBoxSafe<FornecedorRecord>('fornecedores');
  await HiveBoxHelper.openBoxSafe<MaterialCatalogoRecord>('materiais_catalogo');
  await HiveBoxHelper.openBoxSafe<CentroCustoRecord>('centros_custo');
  await HiveBoxHelper.openBoxSafe<RequisicaoCompraRecord>('requisicoes_compra');
  await HiveBoxHelper.openBoxSafe<CotacaoRecord>('cotacoes');
  await HiveBoxHelper.openBoxSafe<PedidoCompraRecord>('pedidos_compra');
  await HiveBoxHelper.openBoxSafe<DescritivoServicoRecord>('descritivos_servico');
  await HiveBoxHelper.openBoxSafe<OrcamentoServicoRecord>('orcamentos_servico');
  await HiveBoxHelper.openBoxSafe<MedicaoEmpreiteiroRecord>('medicoes_empreiteiro');
  await HiveBoxHelper.openBoxSafe<RecebimentoMaterialRecord>('recebimentos_material');
  await HiveBoxHelper.openBoxSafe<DespesaRecord>('despesas');
  await HiveBoxHelper.openBoxSafe<EquipamentoEstoqueRecord>('equipamentos_estoque');
  await HiveBoxHelper.openBoxSafe<InsumoObraRecord>('insumos_obra');
  await HiveBoxHelper.openBoxSafe<InsumoMovimentoRecord>('insumos_obra_movimentos');
  await HiveBoxHelper.openBoxSafe<InsumoConferenciaRecord>('insumos_obra_conferencias');
  await HiveBoxHelper.openBoxRawSafe('project_settings');
  await HiveBoxHelper.openBoxRawSafe('equipments');
  await HiveBoxHelper.openBoxRawSafe('equipment_movements');
}

void _registerHiveAdapters() {
  _safeRegisterAdapter(() => Hive.registerAdapter(InspectionRecordAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(InspectionItemResultAdapter()),
  );
  _safeRegisterAdapter(
    () => Hive.registerAdapter(InspectionPhotoDataAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(ServiceRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(CompanyRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(DiaryServiceEntryAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(DiaryOwnLaborEntryAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(DiaryRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(ProjectRecordAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(UserProjectMembershipAdapter()),
  );
  _safeRegisterAdapter(
    () => Hive.registerAdapter(ProjectInviteRecordAdapter()),
  );
  _safeRegisterAdapter(
    () => Hive.registerAdapter(ProjectAccessCodeRecordAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(ConstrutoraRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(UserOrgMembershipAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(CargoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(EmployeeRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(PermissaoItemAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(PerfilAcessoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(PermissaoOverrideAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(FornecedorRecordAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(MaterialCatalogoRecordAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(CentroCustoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(ItemRequisicaoAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(RequisicaoCompraRecordAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(ItemCotacaoAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(CotacaoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(PedidoCompraRecordAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(DescritivoServicoRecordAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(ItemOrcamentoAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(OrcamentoServicoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(ItemMedicaoAdapter()));
  _safeRegisterAdapter(
    () => Hive.registerAdapter(MedicaoEmpreiteiroRecordAdapter()),
  );
  _safeRegisterAdapter(
    () => Hive.registerAdapter(ItemRecebimentoVerificadoAdapter()),
  );
  _safeRegisterAdapter(
    () => Hive.registerAdapter(RecebimentoMaterialRecordAdapter()),
  );
  _safeRegisterAdapter(() => Hive.registerAdapter(DespesaRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(EquipamentoEstoqueRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(InsumoObraRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(InsumoMovimentoRecordAdapter()));
  _safeRegisterAdapter(() => Hive.registerAdapter(InsumoConferenciaRecordAdapter()));
}

void _safeRegisterAdapter(void Function() register) {
  try {
    register();
  } catch (e) {
    // Esperado apenas em hot-reload/hot-restart (adapter já registrado).
    // Qualquer outra causa (ex.: colisão de typeId) precisa aparecer no log —
    // já mascarou um bug real de convites não persistindo.
    debugPrint('[BOOT] registerAdapter falhou: $e');
  }
}

class ObraCheckApp extends StatelessWidget {
  const ObraCheckApp({super.key, required this.themeController});

  final AppThemeController themeController;

  static const String profileRoute = '/profile';

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Obra Check',
            // Sem limite de largura em telas grandes — pedido explícito do
            // usuário em 2026-08-22 (a barra lateral da Home consumia
            // espaço só ali, mas o restante do app queria mais largura
            // também, não só a Home). Antes disso existiu uma versão que
            // limitava a 900px qualquer tela empurrada por cima da Home
            // (via RouteObserver); removida por não ser o que foi pedido.
            builder: (context, child) => child ?? const SizedBox.shrink(),
            theme: _lightTheme(),
            darkTheme: _darkTheme(),
            themeMode: themeController.themeMode,
            routes: {profileRoute: (_) => const ProfileScreen()},
            home: const _AuthGate(),
          );
        },
      ),
    );
  }

  ThemeData _lightTheme() {
    final app = AppColors.light();
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: app.selected,
      onPrimary: app.selectedText,
      secondary: app.success,
      onSecondary: Colors.white,
      error: app.danger,
      onError: Colors.white,
      surface: app.surface,
      onSurface: app.textPrimary,
      surfaceContainerHighest: app.surfaceAlt,
      onSurfaceVariant: app.textSecondary,
      outline: app.borderStrong,
      outlineVariant: app.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF101B30),
      onInverseSurface: Colors.white,
      inversePrimary: const Color(0xFF9BC2FF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: app.background,
      cardTheme: CardThemeData(
        color: app.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: app.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: app.border),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: app.surface,
        foregroundColor: app.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: app.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: app.selected, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: app.surfaceAlt,
        selectedColor: app.selected,
        disabledColor: app.disabled,
        secondarySelectedColor: app.selected,
        side: BorderSide(color: app.border),
        labelStyle: TextStyle(
          color: app.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: app.selectedText,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: app.primaryAction,
          foregroundColor: Colors.white,
          disabledBackgroundColor: app.disabled,
          disabledForegroundColor: app.disabledText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: app.primaryAction,
        foregroundColor: Colors.white,
      ),
      iconTheme: IconThemeData(color: app.textPrimary),
    );
    return base.copyWith(extensions: <ThemeExtension<dynamic>>[app]);
  }

  ThemeData _darkTheme() {
    final app = AppColors.dark();
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: app.selected,
      onPrimary: app.selectedText,
      secondary: app.success,
      onSecondary: const Color(0xFF061A0F),
      error: app.danger,
      onError: const Color(0xFF1A0608),
      surface: app.surface,
      onSurface: app.textPrimary,
      surfaceContainerHighest: app.surfaceAlt,
      onSurfaceVariant: app.textSecondary,
      outline: app.borderStrong,
      outlineVariant: app.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFEDF2FF),
      onInverseSurface: const Color(0xFF111318),
      inversePrimary: const Color(0xFF2563EB),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: app.background,
      cardTheme: CardThemeData(
        color: app.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: app.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: app.border),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: app.surface,
        foregroundColor: app.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: app.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: app.selected, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: app.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: app.surface),
      chipTheme: ChipThemeData(
        backgroundColor: app.surfaceAlt,
        selectedColor: app.selected,
        disabledColor: app.disabled,
        secondarySelectedColor: app.selected,
        side: BorderSide(color: app.borderStrong),
        labelStyle: TextStyle(
          color: app.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: app.selectedText,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: app.primaryAction,
          foregroundColor: Colors.white,
          disabledBackgroundColor: app.disabled,
          disabledForegroundColor: app.disabledText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: app.primaryAction,
        foregroundColor: Colors.white,
      ),
      iconTheme: IconThemeData(color: app.textPrimary),
    );
    return base.copyWith(extensions: <ThemeExtension<dynamic>>[app]);
  }
}

Future<String> _runUnifiedSyncNow(
  BuildContext context, {
  bool showSnackbars = true,
  String trigger = 'manual',
}) async {
  final result = await SyncOrchestrator.instance.requestSync(
    trigger: trigger,
    manual: showSnackbars,
  );
  final status = result.message;
  final counters = result.counters;

  if (!context.mounted) return status;
  if (!showSnackbars) return status;

  if (!result.success || counters == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
    return status;
  }

  final pendingTotal =
      SyncOrchestrator.instance.stateNotifier.value.pending.total;
  final messenger = ScaffoldMessenger.of(context);
  if (pendingTotal == 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Sincronização concluída com sucesso. Tudo sincronizado.',
        ),
      ),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Sincronização concluída, mas ainda há $pendingTotal pendências locais.',
        ),
      ),
    );
  }

  return pendingTotal == 0
      ? 'Tudo sincronizado'
      : 'Sincronização concluída com pendências ($pendingTotal)';
}

String _formatSyncDateTimeLabel(DateTime? value) {
  if (value == null) return 'Ainda não sincronizado';
  final local = value.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date às $time';
}

Future<void> _showSyncHistorySheet(BuildContext context) async {
  final history = SyncOrchestrator.instance.history;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Histórico de sincronização',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                Text(
                  'Nenhuma execução registrada ainda.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, indexSep) =>
                        const Divider(height: 16),
                    itemBuilder: (_, index) {
                      final item = history[index];
                      final finished = _formatSyncDateTimeLabel(
                        item.finishedAt,
                      );
                      final status = item.success
                          ? 'sucesso'
                          : item.errorCategory == SyncErrorCategory.photo
                          ? 'erro de foto'
                          : 'erro';
                      final pending = SyncPendingSummaryFormatter.short(
                        item.pendingAfter,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$finished — $status — $pending',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'trigger: ${item.trigger} • runId: ${item.runId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? AuthService.instance.currentUser;

        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          // Evita travar indefinidamente na tela inicial quando o stream demora
          // para emitir em cenários de bootstrap/rede.
          return const LoginScreen();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            user != null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const LoginScreen();
        }

        return const HomePage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _syncing = false;
  bool _sidebarPinned = (Hive.box('prefs').get('sidebar_pinned') as bool?) ?? false;
  SyncOrchestratorState _syncState = const SyncOrchestratorState.initial();
  bool _openingTodayDiary = false;
  bool _updateAvailable = AppUpdateService.instance.updateAvailable;
  String? _userNome;
  String? _userEmail;
  String? _userCompany;
  String? _lastTodayInspectionLogFingerprint;
  int? _stableConferidasToday;
  int? _stableFinalizadasToday;
  int? _stableRascunhosToday;
  String? _stableUniqueTodayProjectId;
  final ProjectContextService _projectContext = ProjectContextService.instance;

  /// Navigator aninhado que a sidebar (telas grandes) envolve — o
  /// dashboard e qualquer tela empurrada a partir dele vivem aqui, pra
  /// sidebar ficar fixa fora da navegação. Só existe montado quando
  /// `isLargeScreen`; em telas pequenas fica `null` e as navegações
  /// caem no Navigator raiz normal (mesmo comportamento de sempre).
  final GlobalKey<NavigatorState> _contentNavigatorKey = GlobalKey<NavigatorState>();

  /// Navegação a partir da sidebar/"Ações rápidas" — troca a seção
  /// inteira (volta ao dashboard e empurra a nova tela por cima),
  /// igual clicar numa aba diferente, em vez de empilhar seção sobre
  /// seção (Compras > Funcionários > Permissões exigiria 3 "voltar" pra
  /// sair). Navegação DENTRO de uma seção (ex.: Compras abrindo
  /// Requisições) continua empilhando normalmente — isso aqui só troca
  /// o que está no nível mais alto do Navigator aninhado.
  Future<T?> _openSection<T>(BuildContext context, WidgetBuilder builder) {
    final nested = _contentNavigatorKey.currentState;
    if (nested != null) {
      return nested.pushAndRemoveUntil<T>(
        MaterialPageRoute(builder: builder),
        (route) => route.isFirst,
      );
    }
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
  }

  Box<InspectionRecord> get _inspectionsBox =>
      Hive.box<InspectionRecord>('inspections');

  Box<ServiceRecord>? _servicesBoxInstance;

  Box<ServiceRecord> get _servicesBox {
    _servicesBoxInstance ??= Hive.box<ServiceRecord>('services');
    return _servicesBoxInstance!;
  }

  Box<DiaryRecord>? _diariesBoxInstance;

  Box<DiaryRecord> get _diariesBox {
    _diariesBoxInstance ??= Hive.box<DiaryRecord>('diaries');
    return _diariesBoxInstance!;
  }

  @override
  void dispose() {
    try {
      SyncOrchestrator.instance.stateNotifier.removeListener(
        _onSyncStateChanged,
      );
    } catch (_) {}
    AppUpdateService.instance.removeListener(_onAppUpdateChanged);
    _projectContext.removeListener(_onProjectContextChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleSidebarPinned(bool pinned) {
    setState(() => _sidebarPinned = pinned);
    unawaited(Hive.box('prefs').put('sidebar_pinned', pinned));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDashboardClock();
      unawaited(AppUpdateService.instance.checkNow());
    }
  }

  void _refreshDashboardClock() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppUpdateService.instance.addListener(_onAppUpdateChanged);
    // Sem isso, o AppBar (ícones de Compras/RH/Despesas, toggle de modo)
    // só atualiza no próximo rebuild "por acaso" da HomePage — vinculando
    // uma obra a uma construtora em outra tela, o ícone não aparecia até
    // reabrir o app. `AnimatedBuilder` mais abaixo já cobre o corpo da
    // tela, mas o `appBar:` do Scaffold fica fora dele.
    _projectContext.addListener(_onProjectContextChanged);
    unawaited(AppUpdateService.instance.checkNow());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _openLazyBoxesForHome();
      _initializeHomeServices();
      unawaited(_loadInitialData());
    });
  }

  void _onProjectContextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onAppUpdateChanged() {
    if (!mounted) return;
    setState(() {
      _updateAvailable = AppUpdateService.instance.updateAvailable;
    });
  }

  Future<void> _openLazyBoxesForHome() async {
    await _openLazyBoxes();
    if (mounted) setState(() {});
  }

  void _initializeHomeServices() {
    SyncOrchestrator.instance.stateNotifier.addListener(_onSyncStateChanged);
    _syncState = SyncOrchestrator.instance.stateNotifier.value;
    _syncing = _syncState.isSyncing;
  }

  void _onSyncStateChanged() {
    if (!mounted) return;
    final nextState = SyncOrchestrator.instance.stateNotifier.value;
    setState(() {
      _syncState = nextState;
      _syncing = nextState.isSyncing;
    });
  }

  Future<void> _loadInitialData() async {
    try {
      await _projectContext.refreshMembershipsForCurrentUser();
      await _projectContext.hydrateCurrentProject();
      await _loadUserName();
      await SyncOrchestrator.instance.refreshPendingSnapshot();
      // Dispara sync logo após memberships carregadas, sem esperar o timer de 5min.
      unawaited(
        SyncOrchestrator.instance.requestSync(
          trigger: 'initial_load',
          manual: false,
        ),
      );
    } catch (e, st) {
      debugPrint('[HomePage] _loadInitialData error: $e\n$st');
    }
  }

  void _toggleOrgEditMode() {
    final enabling = !_projectContext.orgEditModeEnabled;
    setState(() {
      _projectContext.setOrgEditMode(enabling);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabling
              ? 'Modo edição ativado: você agora pode alterar dados desta obra.'
              : 'Modo visualização: alterações bloqueadas novamente.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickProject() async {
    final projects = _projectContext.availableProjectsForCurrentUserSync();
    String? selectedId = _projectContext.currentProjectIdSync;
    final canCreateProject = _projectContext.canCreateProjectSync;
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    try {
      final result = await showDialog<(String?, bool)?>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Obra ativa'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Selecionar obra',
                        ),
                        isExpanded: true,
                        items: projects
                            .map(
                              (p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: Text('${p.name} (${p.code})'),
                              ),
                            )
                            .toList(),
                        onChanged: projects.isEmpty
                            ? null
                            : (value) =>
                                  setDialogState(() => selectedId = value),
                      ),
                      if (projects.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Seu perfil foi criado com sucesso, mas você ainda não foi vinculado a uma obra.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Criar obra rápida',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da obra',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Código da obra',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: !canCreateProject
                              ? null
                              : () {
                                  Navigator.pop(dialogContext, (null, true));
                                  unawaited(
                                    _projectContext.createProject(
                                      name: nameController.text,
                                      code: codeController.text,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Criar e ativar'),
                        ),
                      ),
                      if (!canCreateProject)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Sem permissão para criar obra.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, (null, false)),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: projects.isEmpty || selectedId == null
                        ? null
                        : () =>
                              Navigator.pop(dialogContext, (selectedId, false)),
                    child: const Text('Aplicar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || result == null) return;
      final selected = result.$1;
      final created = result.$2;

      if (created) {
        await _projectContext.hydrateCurrentProject();
        await SyncOrchestrator.instance.refreshPendingSnapshot();
        _refreshDashboardClock();
        return;
      }

      if (selected == null) return;
      await _projectContext.switchProject(selected);
      await SyncOrchestrator.instance.refreshPendingSnapshot();
      _refreshDashboardClock();
    } finally {
      nameController.dispose();
      codeController.dispose();
    }
  }

  Future<void> _goToProfile() async {
    final nested = _contentNavigatorKey.currentState;
    if (nested != null) {
      await nested.pushNamedAndRemoveUntil(
        ObraCheckApp.profileRoute,
        (route) => route.isFirst,
      );
    } else {
      await Navigator.of(context).pushNamed(ObraCheckApp.profileRoute);
    }

    if (!mounted) return;
    await _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await UserProfileService.instance.getCurrentUserProfile();
      final firebaseUser = FirebaseAuth.instance.currentUser;

      String? nome;
      String? email;
      String? company;

      final profileNome = profile?.nome.trim();
      final profileEmail = profile?.email?.trim();
      final profileCompany = profile?.company?.trim();
      if (profileNome != null && profileNome.isNotEmpty) {
        nome = profileNome;
      } else {
        final displayName = firebaseUser?.displayName?.trim();
        if (displayName != null && displayName.isNotEmpty) {
          nome = displayName;
        } else {
          final email = firebaseUser?.email?.trim();
          if (email != null && email.isNotEmpty && email.contains('@')) {
            nome = email.split('@').first;
          }
        }
      }

      if (profileEmail != null && profileEmail.isNotEmpty) {
        email = profileEmail;
      } else {
        final firebaseEmail = firebaseUser?.email?.trim();
        if (firebaseEmail != null && firebaseEmail.isNotEmpty) {
          email = firebaseEmail;
        }
      }

      if (profileCompany != null && profileCompany.isNotEmpty) {
        company = profileCompany;
      }

      if (!mounted) return;
      setState(() {
        _userNome = nome;
        _userEmail = email;
        _userCompany = company;
      });
    } catch (e) {
      debugPrint('Erro ao carregar nome do usuário: $e');
    }
  }

  Future<void> _refreshAccessState() async {
    await _projectContext.refreshMembershipsForCurrentUser();
    await _projectContext.hydrateCurrentProject();
    await _loadUserName();
    if (_projectContext.hasProjectAccessForCurrentUserSync) {
      await SyncOrchestrator.instance.refreshPendingSnapshot();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _validateAccessCode(String code) async {
    final result = await ProjectMembersService.instance.consumeAccessCode(
      code: code,
    );
    if (!mounted) return;

    if (result.success) {
      debugPrint(
        '[ACCESS_CODE_UI] success=true code=$code message=${result.message}',
      );
      await _refreshAccessState();
      if (!mounted) return;

      final hasProjectAccess =
          _projectContext.hasProjectAccessForCurrentUserSync;
      if (!hasProjectAccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Código consumido e vínculo criado, mas a obra ainda não foi ativada nesta sessão. Toque em "Atualizar acesso".',
              ),
            ),
          );
        return;
      }

      final projectName = _projectContext.currentProjectNameSync.trim();
      final successMessage =
          projectName.isNotEmpty && projectName != 'Sem obra vinculada'
          ? '${result.message} Você entrou na obra "$projectName".'
          : result.message;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
      return;
    }

    debugPrint(
      '[ACCESS_CODE_UI] success=false code=$code message=${result.message}',
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _syncOnEnter({
    required String trigger,
    required bool notifyUser,
  }) async {
    if (SyncOrchestrator.instance.stateNotifier.value.isSyncing) return;

    if (AppLog.enableSyncLogs) {
      debugPrint('[SYNC] disparo=$trigger');
    }

    try {
      if (!mounted) return;
      await _runUnifiedSyncNow(
        context,
        showSnackbars: notifyUser,
        trigger: trigger,
      );
    } catch (e) {
      debugPrint('Erro ao sincronizar: $e');
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _normalizeBusinessToken(String? raw) {
    return (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  DateTime _conferidasEventAtLocal(InspectionRecord record) {
    final updatedOrCreated = record.updatedAt.isBefore(record.createdAt)
        ? record.createdAt
        : record.updatedAt;
    return (record.finalizedAt ?? record.actionAt ?? updatedOrCreated)
        .toLocal();
  }

  DateTime? _finalizadasEventAtLocal(InspectionRecord record) {
    if (!record.isFinalState) return null;
    return (record.finalizedAt ?? record.actionAt)?.toLocal();
  }

  DateTime? _rascunhosEventAtLocal(InspectionRecord record) {
    if (!record.isDraft) return null;
    return (record.actionAt ?? record.createdAt).toLocal();
  }

  bool _isInspectionFromToday(InspectionRecord record, DateTime nowLocal) {
    final normalizedNow = nowLocal.toLocal();
    return _isSameDay(_conferidasEventAtLocal(record), normalizedNow);
  }

  DateTime _todayInspectionEventAtLocal(InspectionRecord record) {
    return _conferidasEventAtLocal(record);
  }

  String _todayBusinessKey({
    required InspectionRecord record,
    required String currentProjectId,
  }) {
    final location = (record.localRef?.trim().isNotEmpty == true)
        ? record.localRef!.trim()
        : record.apto.trim();
    final element = record.normalizedInspectionElement;
    final projectToken = _normalizeBusinessToken(
      record.projectId.trim().isNotEmpty ? record.projectId : currentProjectId,
    );
    return '$projectToken|'
        '${_normalizeBusinessToken(record.torre)}|'
        '${record.andar}|'
        '${_normalizeBusinessToken(location)}|'
        '${_normalizeBusinessToken(record.fvsCodigo)}|'
        '${_normalizeBusinessToken(element)}';
  }

  int _countUniqueTodayByBusinessKey({
    required Iterable<InspectionRecord> records,
    required DateTime nowLocal,
    required String currentProjectId,
    required DateTime? Function(InspectionRecord record) eventAtLocalSelector,
  }) {
    final normalizedNow = nowLocal.toLocal();
    final keys = <String>{};
    for (final record in records) {
      final eventAt = eventAtLocalSelector(record);
      if (eventAt == null) continue;
      if (!_isSameDay(eventAt, normalizedNow)) continue;
      keys.add(
        _todayBusinessKey(record: record, currentProjectId: currentProjectId),
      );
    }
    return keys.length;
  }

  void _logTodayInspectionsDiagnostics({
    required String currentProjectId,
    required DateTime nowLocal,
    required Iterable<InspectionRecord> rawRecords,
    required List<InspectionRecord> scopedRecords,
    required List<InspectionRecord> todayRecords,
    required int uniqueTodayInspections,
  }) {
    if (!kDebugMode) return;

    final dayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final dayEndExclusive = dayStart.add(const Duration(days: 1));
    final latestUpdate = scopedRecords.isEmpty
        ? 'none'
        : scopedRecords
              .map((e) => e.updatedAt.toIso8601String())
              .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final fingerprint =
        '${dayStart.toIso8601String()}|$currentProjectId|${rawRecords.length}|${scopedRecords.length}|${todayRecords.length}|$uniqueTodayInspections|$latestUpdate';
    if (_lastTodayInspectionLogFingerprint == fingerprint) return;
    _lastTodayInspectionLogFingerprint = fingerprint;

    if (AppLog.enableHomeLogs) {
      debugPrint(
        '[HOME][TODAY_INSPECTIONS] projectId=$currentProjectId nowLocal=${nowLocal.toIso8601String()} '
        'windowStart=${dayStart.toIso8601String()} windowEndExclusive=${dayEndExclusive.toIso8601String()} '
        'rawTotal=${rawRecords.length} scopedTotal=${scopedRecords.length} todayFiltered=${todayRecords.length} uniqueToday=$uniqueTodayInspections',
      );
    }

    for (final record in scopedRecords) {
      final eventAt = _todayInspectionEventAtLocal(record);
      final isToday = _isInspectionFromToday(record, nowLocal);
      final reason = isToday ? 'ACTION_TODAY' : 'OUTSIDE_TODAY_WINDOW';
      final location = (record.localRef?.trim().isNotEmpty == true)
          ? record.localRef!.trim()
          : record.apto.trim();
      if (AppLog.enableHomeLogs) {
        debugPrint(
          '[HOME][TODAY_INSPECTIONS][ITEM] included=$isToday reason=$reason '
          'id=${record.id} projectId=${record.projectId} status=${record.status} isDraft=${record.isDraft} isFinal=${record.isFinalState} '
          'fvs=${record.fvsCodigo} torre=${record.torre} andar=${record.andar} local=$location '
          'createdAt=${record.createdAt.toIso8601String()} updatedAt=${record.updatedAt.toIso8601String()} '
          'businessDate=${record.businessDate.toIso8601String()} eventAtLocal=${eventAt.toIso8601String()}',
        );
      }
    }
  }

  String _todayDiaryId(String projectId, DateTime date) {
    final normalized = AppDateUtils.normalizeLocalDate(date);
    final stamp =
        '${normalized.year.toString().padLeft(4, '0')}${normalized.month.toString().padLeft(2, '0')}${normalized.day.toString().padLeft(2, '0')}';
    return 'diary:$projectId:$stamp';
  }

  DiaryRecord? _findTodayDiary(String currentProjectId, DateTime date) {
    final target = AppDateUtils.normalizeLocalDate(date);
    final fromId = _diariesBox.get(_todayDiaryId(currentProjectId, target));
    if (fromId != null && !fromId.deleted) return fromId;

    final scoped = filterRecordsByProjectScope(
      _diariesBox.values.where((d) => !d.deleted),
      currentProjectId: currentProjectId,
      projectId: (d) => d.projectId,
      obra: (d) => d.obra,
    );
    for (final diary in scoped) {
      final d = AppDateUtils.normalizeLocalDate(diary.date);
      if (_isSameDay(d, target)) return diary;
    }
    return null;
  }

  // Ações do menu (barra lateral em telas grandes, lista "Ações rápidas"
  // em telas pequenas) — extraídas pra métodos próprios pra não duplicar
  // a navegação entre as duas apresentações.
  Future<void> _openFichaFvs() async {
    await _openSection(context, (_) => const FichaFvsModeScreen());
    _refreshDashboardClock();
  }

  Future<void> _openMapaVisual() async {
    await _openSection(context, (_) => const VisualTowerMapScreen());
    _refreshDashboardClock();
  }

  Future<void> _openServicos() async {
    await _openSection(context, (_) => const ServicesScreen());
    _refreshDashboardClock();
  }

  Future<void> _openEmpreiteiros() async {
    await _openSection(context, (_) => const EmpreiteirosScreen());
    _refreshDashboardClock();
  }

  Future<void> _openRelatorios() async {
    await _openSection(context, (_) => const ReportsScreen());
    _refreshDashboardClock();
  }

  Future<void> _openDiarioDeObra() async {
    await _openSection(context, (_) => const DiaryListScreen());
    _refreshDashboardClock();
  }

  Future<void> _openAlmoxarife() async {
    await _openSection(context, (_) => const AlmoxarifadoHubScreen());
    _refreshDashboardClock();
  }

  Future<void> _openCompras() async {
    await _openSection(context, (_) => const ComprasHomeScreen());
  }

  Future<void> _openFuncionarios() async {
    await _openSection(
      context,
      (_) => FuncionariosScreen(orgId: _projectContext.currentProject!.orgId),
    );
  }

  Future<void> _openDespesas() async {
    await _openSection(
      context,
      (_) => DespesasScreen(orgId: _projectContext.currentProject!.orgId),
    );
  }

  Future<void> _openTodayDiaryShortcut() async {
    if (_openingTodayDiary) return;
    final projectId = _projectContext.currentProjectIdSync.trim();
    if (projectId.isEmpty) return;

    setState(() => _openingTodayDiary = true);
    try {
      final today = AppDateUtils.getTodayDate();
      final now = DateTime.now();
      final existing = _findTodayDiary(projectId, today);

      final diary =
          existing ??
          DiaryRecord(
            id: _todayDiaryId(projectId, today),
            projectId: projectId,
            obra: _projectContext.currentProjectNameSync,
            date: today,
            climate: '',
            generalNotes: '',
            serviceEntries: const [],
            ownLaborEntries: const [],
            createdAt: now,
            updatedAt: now,
            deleted: false,
            pendingSync: true,
            deletedAt: null,
            generalPhotos: const [],
            climateMorning: '',
            climateAfternoon: '',
            rentedMachinery: '',
            rentedEquipment: '',
            createdByName: '',
            approvedByName: '',
            approvalStatus: 'pendente',
          );

      if (existing == null) {
        await _diariesBox.put(diary.id, diary);
      }

      if (!mounted) return;
      await _openSection(context, (_) => DiaryEditScreen(diary: diary));
      _refreshDashboardClock();
    } finally {
      if (mounted) setState(() => _openingTodayDiary = false);
    }
  }

  String _todayDiaryStatusText(String currentProjectId) {
    final todayDiary = _findTodayDiary(
      currentProjectId,
      AppDateUtils.getTodayDate(),
    );
    if (todayDiary == null) return 'Nenhum diário aberto hoje';

    final updated = todayDiary.updatedAt.toLocal();
    final now = DateTime.now().toLocal();
    final minutes = now.difference(updated).inMinutes;
    if (minutes <= 15) return 'Diário em andamento';
    return 'Atualizado às ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _buildGreeting(DateTime.now());
    final hasProject = _projectContext.hasProjectAccessForCurrentUserSync;
    // Calculado aqui em cima (não dentro dos builders aninhados mais
    // abaixo) de propósito: só o MediaQuery.of(context) usado AQUI, no
    // contexto do próprio State, garante que uma mudança de largura
    // reconstrua o build() inteiro — inclusive `hasProject` — junto.
    // Calculando isLargeScreen só lá dentro (como estava antes), um
    // resize puro reconstruía só o builder aninhado que dependia do
    // MediaQuery, reusando a mesma closure "congelada" com o hasProject
    // antigo — o menu lateral e a lista "Ações rápidas" ficavam
    // inconsistentes um com o outro sobre a mesma obra estar vinculada.
    final isLargeScreen = MediaQuery.of(context).size.width > 1000;

    final dashboardScaffold = Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        // AnimatedBuilder próprio aqui — não basta reconstruir o
        // `_HomePageState.build()` inteiro quando `_projectContext` muda:
        // uma vez que essa Scaffold vira o conteúdo (possivelmente já
        // montado antes) do Navigator aninhado da sidebar em telas
        // grandes, contar só com o `hasProject` capturado lá em cima
        // arrisca a mesma inconsistência já vista entre sidebar e
        // "Ações rápidas" num resize puro — aqui reagindo sozinho,
        // sem depender de o Navigator aninhado "perceber" o rebuild.
        child: AnimatedBuilder(
          animation: _projectContext,
          builder: (context, _) {
            final hasProjectFresh = _projectContext.hasProjectAccessForCurrentUserSync;
            return AppBar(
              title: const Text('Obra Check'),
              actions: [
                if (hasProjectFresh && _projectContext.hasElevatedAccessSync)
                  IconButton(
                    tooltip: _projectContext.orgEditModeEnabled
                        ? 'Modo edição ativo — tocar para voltar à visualização'
                        : 'Modo visualização — tocar para liberar edição',
                    onPressed: _toggleOrgEditMode,
                    icon: Icon(
                      _projectContext.orgEditModeEnabled
                          ? Icons.edit
                          : Icons.visibility_outlined,
                      color: _projectContext.orgEditModeEnabled
                          ? Theme.of(context).colorScheme.tertiary
                          : null,
                    ),
                  ),
                if (_projectContext.isGlobalAdminSync)
                  IconButton(
                    tooltip: 'Construtoras (administração)',
                    onPressed: () {
                      _openSection(context, (_) => const ConstrutorasAdminScreen());
                    },
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                // Compras/RH/Despesas migraram pro menu lateral (barra da
                // Home) — eram "atalhos temporários até o menu lateral
                // existir", agora viraram sub-itens dele, como o
                // comentário anterior já previa.
                if (hasProjectFresh)
                  IconButton(
                    tooltip: 'Trocar obra',
                    onPressed: _pickProject,
                    icon: const Icon(Icons.business_outlined),
                  ),
                IconButton(
                  tooltip: 'Perfil',
                  onPressed: _goToProfile,
                  icon: const Icon(Icons.account_circle_outlined),
                ),
                IconButton(
                  tooltip: 'Sincronizar',
                  onPressed: _syncing
                      ? null
                      : () => _syncOnEnter(trigger: 'manual', notifyUser: true),
                  icon: const Icon(Icons.sync),
                ),
                IconButton(
                  tooltip: 'Sair',
                  onPressed: () async {
                    await AuthService.instance.logout();
                  },
                  icon: const Icon(Icons.logout),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            if (_syncing) const LinearProgressIndicator(minHeight: 2),
            _ConnectivityBanner(isOnline: _syncState.isOnline),
            Expanded(
              child: ValueListenableBuilder<Box<ServiceRecord>>(
                valueListenable: _servicesBox.listenable(),
                builder: (context, servicesValue, _) {
                  return AnimatedBuilder(
                    animation: _projectContext,
                    builder: (context, _) {
                      return ValueListenableBuilder<Box<InspectionRecord>>(
                        valueListenable: _inspectionsBox.listenable(),
                        builder: (context, value, child) {
                          if (!_projectContext
                              .hasProjectAccessForCurrentUserSync) {
                            return _NoProjectLinkedCard(
                              name: _userNome,
                              email: _userEmail,
                              company: _userCompany,
                              onValidateCode: _validateAccessCode,
                              onRefreshAccess: _refreshAccessState,
                              onLogout: () async {
                                await AuthService.instance.logout();
                              },
                            );
                          }

                          final nowLocal = DateTime.now();
                          final currentProjectId =
                              _projectContext.currentProjectIdSync;
                          final all =
                              filterRecordsByProjectScope(
                                value.values.where((r) => !r.deleted),
                                currentProjectId: currentProjectId,
                                projectId: (r) => r.projectId,
                                obra: (r) => r.obra,
                              ).toList()..sort(
                                (a, b) => b.updatedAt.compareTo(a.updatedAt),
                              );

                          final services = filterRecordsByProjectScope(
                            servicesValue.values,
                            currentProjectId: currentProjectId,
                            projectId: (s) => s.projectId,
                            obra: (s) => s.obra,
                          ).toList();
                          final servicesOpen = services
                              .where(
                                (service) => service.status == 'em_andamento',
                              )
                              .length;
                          final servicesWaiting = services
                              .where(
                                (service) =>
                                    service.status == 'aguardando_inspecao',
                              )
                              .length;

                          final today = all
                              .where(
                                (record) =>
                                    _isInspectionFromToday(record, nowLocal),
                              )
                              .toList();
                          final openNcItems = countOpenNcItemsUnique(all);
                          final conferidasHoje = _countUniqueTodayByBusinessKey(
                            records: all,
                            nowLocal: nowLocal,
                            currentProjectId: currentProjectId,
                            eventAtLocalSelector: (record) =>
                                _conferidasEventAtLocal(record),
                          );
                          final finalizadasHoje =
                              _countUniqueTodayByBusinessKey(
                                records: all,
                                nowLocal: nowLocal,
                                currentProjectId: currentProjectId,
                                eventAtLocalSelector: (record) =>
                                    _finalizadasEventAtLocal(record),
                              );
                          final rascunhosHoje = _countUniqueTodayByBusinessKey(
                            records: all,
                            nowLocal: nowLocal,
                            currentProjectId: currentProjectId,
                            eventAtLocalSelector: (record) =>
                                _rascunhosEventAtLocal(record),
                          );
                          final isTodayCounterLoading = _syncing;
                          if (_stableUniqueTodayProjectId != currentProjectId) {
                            _stableUniqueTodayProjectId = currentProjectId;
                            _stableConferidasToday = null;
                            _stableFinalizadasToday = null;
                            _stableRascunhosToday = null;
                          }
                          if (!isTodayCounterLoading) {
                            _stableConferidasToday = conferidasHoje;
                            _stableFinalizadasToday = finalizadasHoje;
                            _stableRascunhosToday = rascunhosHoje;
                          }
                          final displayedConferidasHoje = isTodayCounterLoading
                              ? (_stableConferidasToday ?? 0)
                              : conferidasHoje;
                          final displayedFinalizadasHoje = isTodayCounterLoading
                              ? (_stableFinalizadasToday ?? 0)
                              : finalizadasHoje;
                          final displayedRascunhosHoje = isTodayCounterLoading
                              ? (_stableRascunhosToday ?? 0)
                              : rascunhosHoje;
                          _logTodayInspectionsDiagnostics(
                            currentProjectId: currentProjectId,
                            nowLocal: nowLocal,
                            rawRecords: value.values.where((r) => !r.deleted),
                            scopedRecords: all,
                            todayRecords: today,
                            uniqueTodayInspections: conferidasHoje,
                          );

                          final dashboardList = ListView(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              16 + MediaQuery.of(context).padding.bottom,
                            ),
                            children: [
                              Text(
                                _userNome != null
                                    ? '$greeting, $_userNome'
                                    : greeting,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _SyncCompactIndicator(
                                state: _syncState,
                                onTap: _goToProfile,
                              ),
                              if (_updateAvailable) ...[
                                const SizedBox(height: 12),
                                _AppUpdateCard(
                                  subtitle:
                                      AppUpdateService.instance.updateSubtitle,
                                  actionLabel: AppUpdateService
                                      .instance
                                      .updateActionLabel,
                                  onUpdate: () async {
                                    await AppUpdateService.instance
                                        .applyUpdate();
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              _ObraHeader(
                                nome: _projectContext.currentProjectNameSync,
                              ),
                              const SizedBox(height: 20),

                              const _SectionTitle('Resumo do dia'),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: _KpiCard(
                                      titulo: 'NC abertas',
                                      valor: '$openNcItems',
                                      icone: Icons.report_problem_outlined,
                                      acaoLabel: 'Ver todas',
                                      detalhe: null,
                                      onAction: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                OpenNcScreen(records: all),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _KpiCard(
                                      titulo: 'Inspecionadas hoje',
                                      valor:
                                          '${displayedFinalizadasHoje + displayedRascunhosHoje}',
                                      icone: Icons.checklist_outlined,
                                      detalhe: null,
                                      acaoLabel: 'Ver',
                                      onAction: () async {
                                        final now = DateTime.now();
                                        final start = DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        );
                                        final end = DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        );
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReportsScreen(
                                              initialFrom: start,
                                              initialTo: end,
                                            ),
                                          ),
                                        );
                                        _refreshDashboardClock();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: _KpiCard(
                                      titulo: 'Serviços em aberto',
                                      valor: '$servicesOpen',
                                      icone: Icons.handyman_outlined,
                                      detalhe: null,
                                      acaoLabel: 'Ver',
                                      onAction: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ServicesScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _KpiCard(
                                      titulo: 'Aguardando inspeção',
                                      valor: '$servicesWaiting',
                                      icone: Icons.hourglass_bottom_outlined,
                                      detalhe: null,
                                      acaoLabel: 'Ver',
                                      onAction: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ServicesScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              if (!isLargeScreen) ...[
                              const _SectionTitle('Ações rápidas'),
                              const SizedBox(height: 12),

                              _ActionButton(
                                label: 'Ficha F.V.S.',
                                icon: Icons.assignment_turned_in_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FichaFvsModeScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Mapa visual',
                                icon: Icons.apartment_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const VisualTowerMapScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Serviços',
                                icon: Icons.handyman_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ServicesScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Empreiteiros',
                                icon: Icons.groups_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EmpreiteirosScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Relatórios',
                                icon: Icons.picture_as_pdf_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ReportsScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Diário de Obra',
                                icon: Icons.menu_book_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DiaryListScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              ValueListenableBuilder<Box<DiaryRecord>>(
                                valueListenable: _diariesBox.listenable(),
                                builder: (context, value, child) {
                                  final currentProjectId =
                                      _projectContext.currentProjectIdSync;
                                  return _ActionButton(
                                    label: 'Diário de hoje',
                                    subtitle: _todayDiaryStatusText(
                                      currentProjectId,
                                    ),
                                    icon: Icons.today_outlined,
                                    busy: _openingTodayDiary,
                                    onTap: () async {
                                      await _openTodayDiaryShortcut();
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              _ActionButton(
                                label: 'Almoxarife',
                                icon: Icons.inventory_2_outlined,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AlmoxarifadoHubScreen(),
                                    ),
                                  );
                                  _refreshDashboardClock();
                                },
                              ),
                              const SizedBox(height: 10),

                              if (hasProject &&
                                  (_projectContext.currentProject?.orgId ?? '')
                                      .isNotEmpty) ...[
                                _ActionButton(
                                  label: 'Compras',
                                  icon: Icons.shopping_cart_outlined,
                                  onTap: _openCompras,
                                ),
                                const SizedBox(height: 10),
                                _ActionButton(
                                  label: 'Funcionários (RH)',
                                  icon: Icons.badge_outlined,
                                  onTap: _openFuncionarios,
                                ),
                                const SizedBox(height: 10),
                                _ActionButton(
                                  label: 'Despesas',
                                  icon: Icons.receipt_long_outlined,
                                  onTap: _openDespesas,
                                ),
                                const SizedBox(height: 10),
                              ],
                              ], // if (!isLargeScreen)

                              const SizedBox(height: 12),
                              _HomeFooterDate(
                                date: AppDateUtils.getTodayDate(),
                              ),
                            ],
                          );

                          return dashboardList;
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!isLargeScreen) return dashboardScaffold;

    // Em telas grandes a sidebar fica fixa fora de qualquer navegação —
    // tudo que hoje é "conteúdo" (o próprio dashboard, e qualquer tela
    // empurrada a partir dele) vive dentro deste Navigator aninhado,
    // que a sidebar envolve por fora. Telas pushed daqui (Compras,
    // Almoxarife etc.) não precisam saber que estão aninhadas —
    // `Navigator.of(context)` chamado de dentro delas já resolve pra
    // este Navigator (o ancestral mais próximo), não pro da raiz.
    return ValueListenableBuilder<Box<DiaryRecord>>(
      valueListenable: _diariesBox.listenable(),
      builder: (context, diariesValue, _) {
        final diaryProjectId = _projectContext.currentProjectIdSync;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeSidebar(
              pinned: _sidebarPinned,
              onTogglePin: _toggleSidebarPinned,
              items: [
                SidebarAction(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Ficha F.V.S.',
                  onTap: _openFichaFvs,
                ),
                SidebarAction(
                  icon: Icons.apartment_outlined,
                  label: 'Mapa visual',
                  onTap: _openMapaVisual,
                ),
                SidebarAction(
                  icon: Icons.handyman_outlined,
                  label: 'Serviços',
                  onTap: _openServicos,
                ),
                SidebarAction(
                  icon: Icons.groups_outlined,
                  label: 'Empreiteiros',
                  onTap: _openEmpreiteiros,
                ),
                SidebarAction(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Relatórios',
                  onTap: _openRelatorios,
                ),
                SidebarAction(
                  icon: Icons.menu_book_outlined,
                  label: 'Diário de Obra',
                  onTap: _openDiarioDeObra,
                ),
                SidebarAction(
                  icon: Icons.today_outlined,
                  label: 'Diário de hoje',
                  subtitle: _todayDiaryStatusText(diaryProjectId),
                  busy: _openingTodayDiary,
                  onTap: _openTodayDiaryShortcut,
                ),
                SidebarAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'Almoxarife',
                  onTap: _openAlmoxarife,
                ),
                if (hasProject &&
                    (_projectContext.currentProject?.orgId ?? '').isNotEmpty) ...[
                  SidebarAction(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Compras',
                    onTap: _openCompras,
                  ),
                  SidebarAction(
                    icon: Icons.badge_outlined,
                    label: 'Funcionários (RH)',
                    onTap: _openFuncionarios,
                  ),
                  SidebarAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Despesas',
                    onTap: _openDespesas,
                  ),
                ],
              ],
            ),
            Expanded(
              child: Navigator(
                key: _contentNavigatorKey,
                onGenerateRoute: (settings) {
                  if (settings.name == ObraCheckApp.profileRoute) {
                    return MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                      settings: settings,
                    );
                  }
                  return MaterialPageRoute(
                    builder: (_) => dashboardScaffold,
                    settings: settings,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _buildGreeting(DateTime now) {
    final saudacao = now.hour < 12
        ? 'Bom dia'
        : now.hour < 18
        ? 'Boa tarde'
        : 'Boa noite';

    return saudacao;
  }
}

class _ObraHeader extends StatelessWidget {
  final String nome;
  const _ObraHeader({required this.nome});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: appColors.projectCardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: appColors.projectAvatarBackground,
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                children: [
                  TextSpan(
                    text: 'L',
                    style: TextStyle(color: appColors.projectAvatarTextPrimary),
                  ),
                  TextSpan(
                    text: '7',
                    style: TextStyle(color: appColors.projectAvatarTextAccent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Obra ativa',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Text(
                  nome,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUpdateCard extends StatelessWidget {
  const _AppUpdateCard({
    required this.onUpdate,
    required this.subtitle,
    required this.actionLabel,
  });

  final Future<void> Function() onUpdate;
  final String subtitle;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_outlined, color: appColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atualização disponível',
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: appColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onUpdate, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.state,
    required this.formattedLastSync,
    required this.onSyncNow,
    required this.onViewHistory,
  });

  final SyncOrchestratorState state;
  final String formattedLastSync;
  final VoidCallback? onSyncNow;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    final status = state.visualStatus;
    final (label, icon, color) = switch (status) {
      SyncVisualStatus.offline => (
        'Sem internet',
        Icons.cloud_off_outlined,
        appColors.statusPending,
      ),
      SyncVisualStatus.syncing => ('Sincronizando', Icons.sync, scheme.primary),
      SyncVisualStatus.error => (
        'Erro',
        Icons.error_outline,
        appColors.statusNc,
      ),
      SyncVisualStatus.pending => (
        'Pendências',
        Icons.pending_actions_outlined,
        appColors.statusDraft,
      ),
      SyncVisualStatus.synced => (
        'Tudo sincronizado',
        Icons.cloud_done_outlined,
        appColors.statusOk,
      ),
    };

    final pending = state.pending;
    final pendingSummary = SyncPendingSummaryFormatter.short(pending);
    final pendingLines = SyncPendingSummaryFormatter.operationalLines(pending);
    final hasPhotoPriority =
        pending.photos > 0 ||
        state.lastErrorCategory == SyncErrorCategory.photo;
    final photoMessage = state.lastErrorCategory == SyncErrorCategory.photo
        ? 'Último erro relacionado a fotos. Verifique anexos e tente novamente.'
        : pending.photos > 0
        ? '${pending.photos} ${pending.photos == 1 ? 'foto pendente de envio' : 'fotos pendentes de envio'}'
        : null;
    final buttonLabel = state.isSyncing
        ? 'Sincronizando...'
        : status == SyncVisualStatus.error
        ? 'Tentar novamente'
        : 'Sincronizar agora';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardColor,
        border: Border.all(color: appColors.borderStrong),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sincronização: $label',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ),
              Text(
                '${pending.total} pend.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pendingSummary,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasPhotoPriority && photoMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: appColors.statusPending.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                photoMessage,
                style: TextStyle(
                  color: appColors.statusPending,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SyncPendingPill(label: 'Inspeções', value: pending.inspections),
              _SyncPendingPill(label: 'Fotos', value: pending.photos),
              _SyncPendingPill(label: 'Diários', value: pending.diaries),
              _SyncPendingPill(label: 'Serviços', value: pending.services),
              _SyncPendingPill(label: 'Empresas', value: pending.companies),
              _SyncPendingPill(
                label: 'Equipamentos',
                value: pending.equipments,
              ),
              _SyncPendingPill(
                label: 'Movimentações',
                value: pending.movements,
              ),
            ],
          ),
          if (pendingLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pendingLines.join(' • '),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Última sincronização: $formattedLastSync',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (state.lastError != null &&
              state.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Último erro: ${state.lastError}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: appColors.statusNc,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onViewHistory,
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Ver histórico'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSyncNow,
              icon: state.isSyncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncCompactIndicator extends StatelessWidget {
  const _SyncCompactIndicator({required this.state, required this.onTap});

  final SyncOrchestratorState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final status = state.visualStatus;
    final hasPhotoPriority =
        state.pending.photos > 0 ||
        state.lastErrorCategory == SyncErrorCategory.photo;

    final (label, icon, color) = switch (status) {
      SyncVisualStatus.offline => (
        'Sem internet',
        Icons.cloud_off_outlined,
        appColors.statusPending,
      ),
      SyncVisualStatus.syncing => ('Sincronizando', Icons.sync, scheme.primary),
      SyncVisualStatus.error => (
        'Erro de sincronização',
        Icons.error_outline,
        appColors.statusNc,
      ),
      SyncVisualStatus.pending => (
        'Pendências de sincronização',
        Icons.pending_actions_outlined,
        appColors.statusDraft,
      ),
      SyncVisualStatus.synced => (
        'Tudo sincronizado',
        Icons.cloud_done_outlined,
        appColors.statusOk,
      ),
    };

    final subtitle = hasPhotoPriority
        ? (state.lastErrorCategory == SyncErrorCategory.photo
              ? 'Atenção: último erro foi com fotos'
              : '${state.pending.photos} ${state.pending.photos == 1 ? 'foto pendente' : 'fotos pendentes'}')
        : SyncPendingSummaryFormatter.short(state.pending);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasPhotoPriority
                  ? appColors.statusPending.withValues(alpha: 0.62)
                  : scheme.outlineVariant,
            ),
            color: hasPhotoPriority
                ? appColors.statusPending.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${state.pending.total}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncPendingPill extends StatelessWidget {
  const _SyncPendingPill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerHighest,
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final String? detalhe;
  final String? acaoLabel;
  final VoidCallback? onAction;

  const _KpiCard({
    required this.titulo,
    required this.valor,
    required this.icone,
    this.detalhe,
    this.acaoLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icone)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (detalhe != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalhe!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (acaoLabel != null && onAction != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onAction,
                    child: Text(
                      acaoLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: appColors.primaryAction,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  const _ActionButton({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: appColors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: appColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: appColors.selected),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: appColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: appColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right, color: appColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final syncing = SyncOrchestrator.instance.stateNotifier.value.isSyncing;

    final isWeb = PlatformService.instance.isWeb;
    final label = syncing
        ? 'Sincronizando'
        : isOnline
        ? 'Online'
        : (isWeb ? 'Sem internet' : 'Sem internet');
    final bgColor = syncing
        ? scheme.primaryContainer
        : isOnline
        ? appColors.statusOk.withValues(alpha: 0.12)
        : appColors.statusPending.withValues(alpha: 0.14);
    final fgColor = syncing
        ? scheme.onPrimaryContainer
        : isOnline
        ? appColors.statusOk
        : appColors.statusPending;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: bgColor,
      child: Row(
        children: [
          Icon(
            syncing
                ? Icons.sync
                : isOnline
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            size: 16,
            color: fgColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFooterDate extends StatelessWidget {
  const _HomeFooterDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'obra check • ${AppDateUtils.formatDateBr(date)}',
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NoProjectLinkedCard extends StatelessWidget {
  const _NoProjectLinkedCard({
    required this.name,
    required this.email,
    required this.company,
    required this.onValidateCode,
    required this.onRefreshAccess,
    required this.onLogout,
  });

  final String? name;
  final String? email;
  final String? company;
  final Future<void> Function(String code) onValidateCode;
  final Future<void> Function() onRefreshAccess;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aguardando acesso à obra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Perfil',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Nome: ${(name ?? '').trim().isEmpty ? '-' : name}'),
                Text('Email: ${(email ?? '').trim().isEmpty ? '-' : email}'),
                const SizedBox(height: 12),
                const Text(
                  'Empresa',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nome da empresa: ${(company ?? '').trim().isEmpty ? '-' : company}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Aguardando acesso à obra'),
                const SizedBox(height: 10),
                const Text(
                  'Seu perfil foi criado com sucesso, mas você ainda não foi vinculado a uma obra.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Você está vinculado à empresa, mas ainda não possui acesso a nenhuma obra. Aguarde a liberação de um administrador.',
                ),
                const SizedBox(height: 16),
                _AccessCodeInput(onValidateCode: onValidateCode),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await onRefreshAccess(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar acesso'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async => await onLogout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessCodeInput extends StatefulWidget {
  const _AccessCodeInput({required this.onValidateCode});

  final Future<void> Function(String code) onValidateCode;

  @override
  State<_AccessCodeInput> createState() => _AccessCodeInputState();
}

class _AccessCodeInputState extends State<_AccessCodeInput> {
  final TextEditingController _controller = TextEditingController();
  bool _validating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de acesso.')),
      );
      return;
    }

    setState(() => _validating = true);
    try {
      await widget.onValidateCode(code);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Código de acesso',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          enabled: !_validating,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Ex.: OC-AB12CD34',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _validating ? null : _submit,
            icon: _validating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vpn_key_outlined),
            label: Text(_validating ? 'Validando...' : 'Validar código'),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _onlineSyncing = false;
  String _onlineStatus = 'Pronto';
  SyncOrchestratorState _syncState = const SyncOrchestratorState.initial();

  @override
  void initState() {
    super.initState();
    _syncState = SyncOrchestrator.instance.stateNotifier.value;
    SyncOrchestrator.instance.stateNotifier.addListener(_onSyncStateChanged);
    unawaited(_loadProfileData());
  }

  @override
  void dispose() {
    SyncOrchestrator.instance.stateNotifier.removeListener(_onSyncStateChanged);
    _nameController.dispose();
    _cargoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (!mounted) return;
    setState(() {
      _syncState = SyncOrchestrator.instance.stateNotifier.value;
    });
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();

    String? nome;
    String? cargo;
    try {
      final profile = await UserProfileService.instance.getCurrentUserProfile();
      final profileNome = profile?.nome.trim();
      final profileCargo = profile?.cargo.trim();

      if (profileNome != null && profileNome.isNotEmpty) {
        nome = profileNome;
      }

      if (profileCargo != null && profileCargo.isNotEmpty) {
        cargo = profileCargo;
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    }

    final displayName = user?.displayName?.trim();
    if ((nome == null || nome.isEmpty) &&
        displayName != null &&
        displayName.isNotEmpty) {
      nome = displayName;
    }

    if (!mounted) return;
    setState(() {
      _emailController.text = email ?? '';
      _nameController.text = nome ?? '';
      _cargoController.text = cargo ?? '';
      _loading = false;
    });
    await _syncOnlineNow();
  }

  Future<void> _syncOnlineNow() async {
    if (_onlineSyncing) return;
    setState(() {
      _onlineSyncing = true;
      _onlineStatus = 'Sincronizando...';
    });
    try {
      final status = await _runUnifiedSyncNow(
        context,
        trigger: 'manual_profile',
      );
      if (!mounted) return;
      setState(() => _onlineStatus = status);
    } catch (e) {
      final isFirestoreDisabled =
          e is StateError && e.toString().contains('FIRESTORE_API_DISABLED');
      final message = isFirestoreDisabled
          ? 'Sync indisponível: Firestore não habilitado'
          : 'Falha na sincronização: $e';
      if (!mounted) return;
      setState(() => _onlineStatus = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _onlineSyncing = false);
    }
  }

  Future<void> _saveProfile() async {
    final nome = _nameController.text.trim();
    final cargo = _cargoController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um nome válido.')));
      return;
    }

    if (cargo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um cargo válido.')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await UserProfileService.instance.saveCurrentUserProfile(
        nome: nome,
        cargo: cargo,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(nome);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil salvo com sucesso.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o perfil.')),
      );
      debugPrint('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openUsersFromObra() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProjectMembersScreen()),
    );
  }

  Future<void> _openProjectSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProjectSettingsScreen()),
    );
  }

  String _themeLabel(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return 'Claro';
      case AppThemePreference.dark:
        return 'Escuro';
      case AppThemePreference.system:
        return 'Sistema';
    }
  }

  Future<void> _openThemePicker() async {
    final controller = AppThemeScope.of(context);
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final current = controller.preference;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('☀️', style: TextStyle(fontSize: 18)),
                title: const Text('Claro'),
                trailing: current == AppThemePreference.light
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetContext, AppThemePreference.light),
              ),
              ListTile(
                leading: const Text('🌙', style: TextStyle(fontSize: 18)),
                title: const Text('Escuro'),
                trailing: current == AppThemePreference.dark
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetContext, AppThemePreference.dark),
              ),
              ListTile(
                leading: const Text('⚙️', style: TextStyle(fontSize: 18)),
                title: const Text('Sistema'),
                trailing: current == AppThemePreference.system
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.pop(sheetContext, AppThemePreference.system),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await controller.setPreference(selected);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeScope.of(context);
    final currentTheme = themeController.preference;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionTitle('Informações do usuário'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cargoController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Cargo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: false,
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Usuários da obra'),
                    subtitle: const Text(
                      'Visualizar equipe cadastrada na mesma obra',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openUsersFromObra,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.apartment_outlined),
                    title: const Text('Configurações da obra'),
                    subtitle: const Text(
                      'Estrutura, áreas especiais e listas guiadas',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openProjectSettings,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Tema'),
                    subtitle: Text(_themeLabel(currentTheme)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openThemePicker,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Salvando...' : 'Salvar'),
                  ),
                ],
              ),
      ),
    );
  }
}
