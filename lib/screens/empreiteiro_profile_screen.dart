import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/company_record.dart';
import '../models/inspection_record.dart';
import '../models/service_record.dart';
import 'company_nc_whatsapp_charge_screen.dart';
import 'company_form_screen.dart';

class EmpreiteiroProfileScreen extends StatefulWidget {
  const EmpreiteiroProfileScreen({
    super.key,
    required this.company,
    required this.servicesBox,
  });

  final CompanyRecord company;
  final Box<ServiceRecord> servicesBox;

  @override
  State<EmpreiteiroProfileScreen> createState() => _EmpreiteiroProfileScreenState();
}

class _EmpreiteiroProfileScreenState extends State<EmpreiteiroProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final inspectionsBox = Hive.box<InspectionRecord>('inspections');

    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: inspectionsBox.listenable(),
      builder: (context, inspectionsValue, _) {
        return ValueListenableBuilder<Box<CompanyRecord>>(
          valueListenable: companiesBox.listenable(),
          builder: (context, value, _) {
            final currentCompany = value.get(widget.company.id) ?? widget.company;
            final services = widget.servicesBox.values.where((s) => s.empresaId == currentCompany.id).toList();
            final emAndamento = services.where((s) => s.status == 'em_andamento').length;
            final aguardando = services.where((s) => s.status == 'aguardando_inspecao').length;
            final pendente = services.where((s) => s.status == 'pendente').length;
            final finalizados = services.where((s) => s.status == 'concluido').length;
            final ncAberta = inspectionsValue.values.where((r) {
              if (r.deleted) return false;
              if ((r.ncCompanyId ?? '').trim() != currentCompany.id) return false;
              return r.itens.any((item) => item.status == 'nok');
            }).length;

            final ativos = emAndamento + aguardando + pendente;

            return Scaffold(
              appBar: AppBar(
                title: Text('Perfil • ${currentCompany.nome}'),
                actions: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () async {
                      await showCompanyFormDialog(
                        context: context,
                        box: companiesBox,
                        initial: currentCompany,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    title: 'Perfil',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nome: ${currentCompany.nome}'),
                        Text('Especialidade: ${currentCompany.especialidade}'),
                        Text('CNPJ: ${currentCompany.cnpj ?? '-'}'),
                        Text('WhatsApp: ${(currentCompany.phone ?? '').trim().isEmpty ? '-' : currentCompany.phone}'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompanyNcWhatsappChargeScreen(
                                  company: currentCompany,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message_outlined),
                          label: const Text('Cobrar NC por WhatsApp'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(title: 'Serviços finalizados', child: Text('$finalizados')),
                  const SizedBox(height: 10),
                  _Card(title: 'NC em aberto', child: Text('$ncAberta')),
                  const SizedBox(height: 10),
                  _Card(title: 'Serviços em andamento', child: Text('$ativos')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

