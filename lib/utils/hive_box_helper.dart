import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String kRecoveryFlagKey = '__obra_check_recovered__';
const int kRecoveryFlagVersion = 1;

class HiveBoxHelper {
  static bool _recoveryAttempted = false;
  static bool _hasCriticalFailure = false;
  static Box? _prefsBox;

  static bool get hasCriticalFailure => _hasCriticalFailure;

  static bool get isWebBuild => kIsWeb;

  static Future<void> checkAndRecoverIfNeeded() async {
    if (_recoveryAttempted || !kIsWeb) return;
    _recoveryAttempted = true;

    try {
      _prefsBox = await Hive.openBox('prefs');
      final lastRecovery = _prefsBox!.get(kRecoveryFlagKey, defaultValue: 0) as int;

      if (lastRecovery < kRecoveryFlagVersion) {
        debugPrint('[BOOT][RECOVERY] Detectada necessidade de recovery (version=$lastRecovery < $kRecoveryFlagVersion)');
        
        await _performFullReset();
        
        await _prefsBox!.put(kRecoveryFlagKey, kRecoveryFlagVersion);
        debugPrint('[BOOT][RECOVERY] Recovery concluído com sucesso');
      }
    } catch (e) {
      debugPrint('[BOOT][RECOVERY] Erro ao verificar necessidade de recovery: $e');
      await _performFullReset();
      
      try {
        _prefsBox = await Hive.openBox('prefs');
        await _prefsBox!.put(kRecoveryFlagKey, kRecoveryFlagVersion);
      } catch (reopenError) {
        debugPrint('[BOOT][RECOVERY] Erro ao reopen prefs após reset: $reopenError');
      }
    }
  }

  static Future<void> _closeBoxIfOpen(String name) async {
    try {
      final box = Hive.box(name);
      await box.close();
      debugPrint('[BOOT][RECOVERY] Box "$name" fechada');
    } catch (e) {
      debugPrint('[BOOT][RECOVERY] Box "$name" não estava aberta ou erro ao fechar: $e');
    }
  }

  static Future<void> _performFullReset() async {
    debugPrint('[BOOT][RECOVERY] Executando reset completo dos dados locais...');

    final boxNames = [
      'inspections',
      'services',
      'companies',
      'diaries',
      'projects',
      'user_project_memberships',
      'project_invites',
      'project_access_codes',
      'construtoras',
      'user_org_memberships',
      'cargos',
      'employees',
      'perfis_acesso',
      'fornecedores',
      'materiais_catalogo',
      'centros_custo',
      'requisicoes_compra',
      'cotacoes',
      'pedidos_compra',
      'descritivos_servico',
      'orcamentos_servico',
      'medicoes_empreiteiro',
      'medicoes_campo',
      'recebimentos_material',
      'despesas',
      'project_settings',
      'equipments',
      'equipment_movements',
      'prefs',
    ];

    for (final name in boxNames) {
      await _closeBoxIfOpen(name);
      
      try {
        await Hive.deleteBoxFromDisk(name);
        debugPrint('[BOOT][RECOVERY] Box "$name" deletada');
      } catch (e) {
        debugPrint('[BOOT][RECOVERY] Erro ao deletar box "$name": $e');
      }
    }

    _hasCriticalFailure = true;
    debugPrint('[BOOT][RECOVERY] Reset completo finalizado, boxes essenciais serão reabertas pelo app');
  }

  static Future<Box> openBoxSafe<T>(String boxName, {bool isLazy = false}) async {
    try {
      if (isLazy) {
        return await Hive.openBox<T>(boxName);
      }
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      debugPrint('[BOOT][HIVE] Falha ao abrir box "$boxName", tentando recover: $e');
      await _closeBoxIfOpen(boxName);
      try {
        await Hive.deleteBoxFromDisk(boxName);
        debugPrint('[BOOT][HIVE] Box "$boxName" deletada e será reaberta');
      } catch (deleteError) {
        debugPrint('[BOOT][HIVE] Falha ao limpar box "$boxName": $deleteError');
      }
      return await Hive.openBox<T>(boxName);
    }
  }

  static Future<Box> openBoxRawSafe(String boxName) async {
    try {
      return await Hive.openBox(boxName);
    } catch (e) {
      debugPrint('[BOOT][HIVE] Falha ao abrir box "$boxName", tentando recover: $e');
      await _closeBoxIfOpen(boxName);
      try {
        await Hive.deleteBoxFromDisk(boxName);
        debugPrint('[BOOT][HIVE] Box "$boxName" deletada e será reaberta');
      } catch (deleteError) {
        debugPrint('[BOOT][HIVE] Falha ao limpar box "$boxName": $deleteError');
      }
      return await Hive.openBox(boxName);
    }
  }

  static Future<void> reinitEssentialBoxes() async {
    debugPrint('[BOOT][RECOVERY] Reabrindo boxes essenciais...');
    await openBoxSafe('prefs');
    await openBoxSafe('projects');
    await openBoxSafe('user_project_memberships');
    debugPrint('[BOOT][RECOVERY] Boxes essenciais reabertas');
  }

  static void triggerRecovery() async {
    if (!kIsWeb) return;
    debugPrint('[BOOT][RECOVERY] Recovery solicitado manualmente');
    await _performFullReset();
  }
}