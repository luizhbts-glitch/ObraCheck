# Obra Check — Documentação Técnica Atual

Este documento reflete o comportamento atual do app com base no código em produção no repositório.

## 1) Visão geral do app

O **Obra Check** é um aplicativo Flutter para controle de qualidade em obra com foco em FVS, NC, fotos de evidência, diário de obra e almoxarifado, seguindo abordagem **offline-first** com sincronização opcional com Firebase.

**Estado atual do sistema:**
- em produção controlada (uso interno em obra real);
- arquitetura estável com evolução contínua;
- módulos principais consolidados (FVS, NC, relatórios, sync);
- base pronta para expansão como produto multi-obra.

Principais capacidades:
- inspeção FVS por local e por ronda;
- rascunho/finalização de inspeções com bloqueio por status;
- relatórios PDF/Excel;
- painel de NC abertas com filtros;
- gestão de serviços e empreiteiros;
- diário de obra com fotos;
- almoxarifado com saídas/devoluções e histórico;
- multi-obra com controle de contexto por `projectId`.

---

## 2) Funcionalidades principais

### Inspeção FVS
- Entrada por modo em [`FichaFvsModeScreen`](lib/screens/ficha_fvs_mode_screen.dart).
- Execução da inspeção em [`InspectionScreen`](lib/screens/inspection_screen.dart).
- Status de item normalizados no workflow: `ok`, `nok`, `okAfterFix`, `none`.

### Relatórios
- Tela principal em [`ReportsScreen`](lib/screens/reports_screen.dart).
- PDF com seleção prévia de escopo (torre + FVS) em [`_pickPdfScope()`](lib/screens/reports_screen.dart:652).
- Exportação Excel separada do fluxo de PDF.

### NC abertas
- Visão consolidada em [`OpenNcScreen`](lib/screens/open_nc_screen.dart).
- Filtros por torre/FVS/elemento, agrupamento por local e atalhos para diagnóstico de duplicados.

### Serviços e empreiteiros
- Serviços em [`ServicesScreen`](lib/screens/services_screen.dart).
- Empreiteiros em [`EmpreiteirosScreen`](lib/screens/empreiteiros_screen.dart).

### Almoxarifado
- Fluxo em [`AlmoxarifeScreen`](lib/screens/almoxarife_screen.dart).
- Pendentes, equipamentos agrupados, histórico com filtros e tombstone automático de movimentos antigos (com `pendingSync`).

### Diário de obra
- Listagem em [`DiaryListScreen`](lib/screens/diary_list_screen.dart).
- Criação/edição em [`DiaryEditScreen`](lib/screens/diary_edit_screen.dart), com entradas de serviços, mão de obra própria e fotos.

### Multi-obra e acesso
- Contexto de obra ativo em [`ProjectContextService`](lib/services/project_context_service.dart).
- Memberships e código de acesso em [`ProjectMembersService`](lib/services/project_members_service.dart).

### Sync online
- Serviço central em [`CloudSyncService`](lib/services/cloud_sync_service.dart).
- Ação manual de sync unificada em [`_runUnifiedSyncNow()`](lib/main.dart:234).

---

## 3) Fluxo do usuário

1. **Login** em [`LoginScreen`](lib/screens/login_screen.dart): email/senha ou Google.
2. **Home** em [`HomePage`](lib/main.dart:319): indicadores, atalhos e troca de obra ativa.
3. **Navegação principal**: FVS, mapa visual, serviços, empreiteiros, relatórios, diário e almoxarifado.
4. **Inspeção (Local)**: local → FVS → execução.
5. **Ronda**: FVS → torre → grade de apartamentos/locais.
6. **Relatórios**: histórico filtrável + geração PDF/Excel.
7. **Perfil** em [`ProfileScreen`](lib/main.dart:1479): dados do usuário, tema, online mode e sync manual.

---

## 4) Arquitetura

Estrutura base em [`lib`](lib):

- [`lib/screens`](lib/screens): UI e interação.
- [`lib/services`](lib/services): regras de negócio, sync, contexto e integração.
- [`lib/models`](lib/models): modelos Hive/Firestore.
- [`lib/data`](lib/data): catálogos estáticos (FVS/estrutura).
- [`lib/widgets`](lib/widgets): componentes reutilizáveis.
- [`lib/theme`](lib/theme): tema e sistema de cores (incluindo evolução para ThemeExtension).

Bootstrap em [`main()`](lib/main.dart:37): inicializa Firebase, Hive, adapters, boxes, tema e gate de autenticação.

---

## 5) Modelo de dados

Entidade principal: [`InspectionRecord`](lib/models/inspection_record.dart).

Campos/regras de domínio relevantes:
- `status` com compatibilidade legada (`draft`, `final`, `finalized`);
- `locked` coerente com status final;
- `pendingSync` para fila local de sincronização;
- `deleted`/`deletedAt` para tombstone lógico;
- `businessDate` para data funcional de listagem/KPI;
- `projectId` para isolamento multi-obra;
- chave lógica de negócio por dia/local/FVS em [`logicalBusinessKey()`](lib/models/inspection_record.dart:302).

Outros modelos importantes:
- [`ServiceRecord`](lib/models/service_record.dart),
- [`CompanyRecord`](lib/models/company_record.dart),
- [`DiaryRecord`](lib/models/diary_record.dart),
- [`ProjectRecord`](lib/models/project_record.dart),
- [`UserProjectMembership`](lib/models/user_project_membership.dart).

---

## 6) Workflow de inspeção

Centralizado em [`InspectionWorkflowService`](lib/services/inspection_workflow_service.dart):

- composição de itens em [`composeItems()`](lib/services/inspection_workflow_service.dart:27);
- validação de finalização em [`validateFinalize()`](lib/services/inspection_workflow_service.dart:86);
- persistência de rascunho em [`saveDraft()`](lib/services/inspection_workflow_service.dart:121);
- persistência de finalização em [`saveFinalized()`](lib/services/inspection_workflow_service.dart:222).

Comportamentos atuais:
- finalização força estado final + `locked=true`;
- rascunho permanece editável;
- prevenção de duplicidade por reaproveitamento de registro equivalente (`logicalBusinessKey`);
- rastreio de ação por `actionType`, `actionBy*`, `actionAt`.

---

## 7) Relatórios

Implementação principal em [`ReportsScreen`](lib/screens/reports_screen.dart) e geração em [`PdfReportService`](lib/services/pdf_report_service.dart).

Fluxo PDF:
1. usuário aciona gerar relatório;
2. seleciona torre/área;
3. seleciona FVS;
4. app gera PDF por lote com escopo aplicado.

Fluxo Excel:
- exportação do período/filtros atuais em ação separada na mesma tela.

---

## 8) Almoxarifado

Módulo em [`AlmoxarifeScreen`](lib/screens/almoxarife_screen.dart):

- aba pendentes com devolução rápida;
- cadastro/edição de equipamentos;
- histórico de ciclos saída/devolução com filtros por equipamento, responsável e data;
- dados com escopo por obra (`projectId`) e suporte a sync.

---

## 9) Sincronização

Serviço central: [`CloudSyncService`](lib/services/cloud_sync_service.dart).

Características:
- sync condicionado a `online_enabled` e disponibilidade de conectividade;
- estratégia offline-first: alterações locais pendentes não são sobrescritas no pull;
- envio de tombstones antes de pull;
- merge por `updatedAt` com guardas de conflito;
- upload de fotos pendentes acoplado ao ciclo de sync;
- telemetria de execução em [`SyncRunStats`](lib/services/cloud_sync_service.dart:45).

### Fluxo operacional (offline-first)

1. usuário opera totalmente offline;
2. dados são salvos localmente com `pendingSync=true`;
3. ao habilitar modo online:
   - push de alterações locais;
   - envio de tombstones;
   - pull incremental remoto;
   - resolução de conflitos por `updatedAt`.

---

## 10) Fotos

Modelo de foto: [`InspectionPhotoData`](lib/models/inspection_record.dart:539).

Campos centrais:
- `localPath` (arquivo local),
- `photoUrl` (URL remota),
- `storagePath` (caminho no Storage),
- `pendingSync` (pendência de upload).

Resolução da fonte de exibição em [`resolveBestPhotoSource()`](lib/services/photo_service.dart:158):
- mobile prioriza arquivo local quando disponível;
- remoto usado quando há URL;
- fallback de compatibilidade para legado mobile.

---

## 11) Multi-obra

O contexto ativo é mantido em [`ProjectContextService`](lib/services/project_context_service.dart):

- hidratação de projeto atual,
- troca de obra,
- permissões por membership,
- fallback legado quando necessário.

Filtros por escopo de obra:
- [`filterRecordsByProjectScope()`](lib/utils/project_scope.dart),
- [`filterMapByProjectScope()`](lib/utils/project_scope.dart).

---

## 12) UI/UX atual

Estado atual de UX no código:

- tema claro/escuro/sistema com controle central;
- evolução para sistema de cores centralizado (ThemeExtension);
- feedback visual por status (ok, NC, corrigido);
- priorização de ações rápidas para uso em campo;
- redução de cliques em fluxos críticos;
- consistência visual entre módulos;
- ícones/emoji de FVS padronizados via [`formatFvsTitle()`](lib/utils/fvs_icon_formatter.dart:22);
- diário com ações contextuais por item;
- telas de diagnóstico e limpeza de duplicados acessíveis pela NC aberta.

---

## 13) Boas práticas do projeto

- **Offline-first** como padrão operacional.
- **Single source of truth**: código como base da documentação.
- **Compatibilidade legada** para status/estrutura antigos.
- **Tombstone lógico** para exclusão sincronizável.
- **Isolamento multi-obra** por `projectId`.
- **Serviços centralizados** para regra de negócio fora da UI.
- **Proteção contra duplicidade** no workflow e no sync.

### Diagnóstico e migração de legado (inspeções)

Serviço dedicado em [`InspectionLegacyMigrationService`](lib/services/inspection_legacy_migration_service.dart):

- diagnóstico: [`diagnoseLegacyInspections()`](lib/services/inspection_legacy_migration_service.dart:15);
- migração segura com `dryRun`: [`migrateLegacyInspections()`](lib/services/inspection_legacy_migration_service.dart:21).

Critérios aplicados incluem:
- status legado (`finalized`);
- inconsistência de `locked`;
- foto `pendingSync` sem `photoUrl`/`storagePath`;
- estrutura de foto legada;
- sinais de reabertura/edição.

---

## 14) Limitações atuais

- ausência de cobertura robusta de testes automatizados;
- dependência de sync manual para consistência total;
- ausência de versionamento formal de schema de dados;
- UX ainda em evolução para cenários com alto volume de fotos;
- ausência de camada avançada de observabilidade.

---

## 15) Próximos passos

- ampliar cobertura de testes de workflow/sync;
- expandir testes de regressão para cenários de legado e duplicidade;
- evoluir observabilidade de sync e migração;
- consolidar sistema de design (cores, componentes e padrões);
- melhorar experiência mobile/web em baixa conectividade.

---

## Princípios de design do sistema

- simplicidade operacional em campo;
- tolerância a falhas de conectividade;
- consistência eventual com prioridade local;
- rastreabilidade de ações do usuário;
- isolamento de dados por obra.