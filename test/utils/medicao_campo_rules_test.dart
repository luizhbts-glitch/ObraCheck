import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/models/medicao_campo_record.dart';
import 'package:obra_check/utils/medicao_campo_rules.dart';

MedicaoCampoApto _apto(String label, {String status = MedicaoStatus.pendente, int fotos = 0}) {
  return MedicaoCampoApto(
    torre: 'Paris',
    localRef: 'APTO_$label',
    label: label,
    andar: int.parse(label.substring(0, label.length - 2)),
    status: status,
    fotos: List.generate(
      fotos,
      (i) => MedicaoCampoFoto(id: 'f$i', capturedAt: DateTime(2026, 10, 5)),
    ),
  );
}

void main() {
  group('legenda da foto', () {
    test('traz obra, torre, apto, serviço, empreiteiro, data/hora e usuário', () {
      final linhas = buildMedicaoFotoLegendaLinhas(
        obra: 'Arsen Sabiá',
        torre: 'Paris',
        apto: '1101',
        servico: 'Piso cerâmico',
        empreiteiro: 'Silva Pisos',
        dataHora: DateTime(2026, 10, 5, 9, 7),
        usuario: 'Luiz',
      );
      final texto = linhas.join('\n');
      expect(texto, contains('Arsen Sabiá'));
      expect(texto, contains('Paris'));
      expect(texto, contains('1101'));
      expect(texto, contains('Piso cerâmico'));
      expect(texto, contains('Silva Pisos'));
      expect(texto, contains('05/10/2026 09:07'));
      expect(texto, contains('Luiz'));
    });

    test('campo vazio vira hífen, nunca some', () {
      final texto = buildMedicaoFotoLegenda(
        obra: '',
        torre: 'Paris',
        apto: '1101',
        servico: 'Piso',
        empreiteiro: '  ',
        dataHora: DateTime(2026, 1, 2, 3, 4),
        usuario: '',
      );
      expect(texto, contains('Obra: -'));
      expect(texto, contains('Empreiteiro: -'));
      expect(texto, contains('Usuário: -'));
    });
  });

  group('rótulo do local', () {
    test('apartamento numérico vira "Apto 1101", área comum mantém o nome', () {
      expect(rotuloLocalMedicao('1101'), 'Apto 1101');
      expect(rotuloLocalMedicao('Rooftop'), 'Rooftop');
      expect(rotuloLocalMedicao("Caixa d'água"), "Caixa d'água");
    });

    test('legenda da foto de área comum não diz "Apto"', () {
      final texto = buildMedicaoFotoLegenda(
        obra: 'Arsen',
        torre: 'Paris',
        apto: 'Barrilete',
        servico: 'Impermeabilização',
        empreiteiro: 'Silva',
        dataHora: DateTime(2026, 10, 6, 8, 0),
        usuario: 'Luiz',
      );
      expect(texto, contains('Barrilete'));
      expect(texto, isNot(contains('Apto Barrilete')));
    });

    test('áreas comuns ficam depois dos apartamentos na ordenação', () {
      final lista = [
        MedicaoCampoApto(torre: 'Paris', localRef: 'ROOFTOP', label: 'Rooftop', andar: 0),
        MedicaoCampoApto(torre: 'Paris', localRef: 'APTO_1101', label: '1101', andar: 11),
      ]..sort(compararAptosMedicao);
      expect(lista.map((a) => a.label).toList(), ['1101', 'Rooftop']);
    });
  });

  group('estacionamento', () {
    test('sem configuração usa módulos 1 a 4 com subsolo, térreo e G1', () {
      final mn = modulosENiveisDaGaragem(const []);
      expect(mn.modulos, ['Módulo 1', 'Módulo 2', 'Módulo 3', 'Módulo 4']);
      expect(mn.niveis, ['Subsolo', 'Térreo', 'G1']);
      final celulas = celulasGaragem(mn.modulos, mn.niveis);
      expect(celulas.length, 12);
      expect(celulas.first.label, 'Módulo 1 - Subsolo');
      expect(celulas.first.localRef, 'GARAGEM_MODULO_1_SUBSOLO');
      expect(celulas[2].localRef, 'GARAGEM_MODULO_1_G1');
      expect(celulas.map((c) => c.localRef).toSet().length, 12);
    });

    test('usa os módulos e níveis da configuração da obra quando existem', () {
      final mn = modulosENiveisDaGaragem(['Subsolo', 'Módulo A', 'G2', 'Rampa']);
      expect(mn.modulos, ['Módulo A']);
      expect(mn.niveis, ['Subsolo', 'G2']);
    });

    test('ordena módulo e depois nível, não alfabeticamente', () {
      final celulas = celulasGaragem(kModulosGaragemPadrao, kNiveisGaragemPadrao);
      final lista = celulas
          .map(
            (c) => MedicaoCampoApto(
              torre: kTorreGaragem,
              localRef: c.localRef,
              label: c.label,
              andar: c.rank,
            ),
          )
          .toList()
        ..shuffle();
      lista.sort(compararAptosMedicao);
      expect(lista.first.label, 'Módulo 1 - Subsolo');
      expect(lista[1].label, 'Módulo 1 - Térreo');
      expect(lista[2].label, 'Módulo 1 - G1');
      expect(lista.last.label, 'Módulo 4 - G1');
    });
  });

  group('elementos e serviço', () {
    test('serviço com elementos', () {
      expect(servicoComElementos('Execução de formas', ['Laje', 'Viga']), 'Execução de formas (Laje, Viga)');
      expect(servicoComElementos('Concretagem', const []), 'Concretagem');
    });

    test('serviço digitado à mão mostra só o nome', () {
      expect(rotuloServico(kServicoOutro, 'Carpintaria de laje'), 'Carpintaria de laje');
      expect(rotuloServico('3.1', 'Execução de formas'), '3.1 • Execução de formas');
    });

    test('registro antigo sem elementos continua legível', () {
      final r = MedicaoCampoRecord.fromMap({
        'id': 'x',
        'projectId': 'p',
        'obra': 'o',
        'servicoCodigo': 's',
        'servicoNome': 's',
        'createdAt': DateTime(2026, 10, 1),
        'updatedAt': DateTime(2026, 10, 1),
      });
      expect(r.elementos, isEmpty);
      final back = MedicaoCampoRecord.fromMap(
        r.copyWith(elementos: ['Pilar']).toMap(),
      );
      expect(back.elementos, ['Pilar']);
    });
  });

  group('resumirMedicao', () {
    test('conta status e fotos', () {
      final r = resumirMedicao([
        _apto('1101', status: MedicaoStatus.conferido, fotos: 2),
        _apto('1102', status: MedicaoStatus.conferido, fotos: 1),
        _apto('1103'),
        _apto('1104', status: MedicaoStatus.problema, fotos: 3),
      ]);
      expect(r.totalAptos, 4);
      expect(r.conferidos, 2);
      expect(r.pendentes, 1);
      expect(r.comProblema, 1);
      expect(r.totalFotos, 6);
    });

    test('status desconhecido conta como pendente', () {
      final r = resumirMedicao([_apto('1101', status: 'xyz')]);
      expect(r.pendentes, 1);
    });
  });

  group('validarNovaMedicao', () {
    test('exige serviço, empreiteiro e ao menos um apto', () {
      expect(
        validarNovaMedicao(servicoCodigo: '', empreiteiroNome: 'A', totalAptosSelecionados: 1),
        isNotNull,
      );
      expect(
        validarNovaMedicao(servicoCodigo: '5.4', empreiteiroNome: '', totalAptosSelecionados: 1),
        isNotNull,
      );
      expect(
        validarNovaMedicao(servicoCodigo: '5.4', empreiteiroNome: 'A', totalAptosSelecionados: 0),
        isNotNull,
      );
      expect(
        validarNovaMedicao(servicoCodigo: '5.4', empreiteiroNome: 'A', totalAptosSelecionados: 3),
        isNull,
      );
      expect(
        validarNovaMedicao(
          servicoCodigo: '3.1',
          empreiteiroNome: 'A',
          totalAptosSelecionados: 3,
          exigeElemento: true,
          totalElementos: 0,
        ),
        isNotNull,
      );
      expect(
        validarNovaMedicao(
          servicoCodigo: '3.1',
          empreiteiroNome: 'A',
          totalAptosSelecionados: 3,
          exigeElemento: true,
          totalElementos: 2,
        ),
        isNull,
      );
    });
  });

  test('compararAptosMedicao ordena numericamente por torre', () {
    final lista = [_apto('1102'), _apto('201'), _apto('1101')]..sort(compararAptosMedicao);
    expect(lista.map((a) => a.label).toList(), ['201', '1101', '1102']);
  });

  group('serialização', () {
    test('toMap/fromMap preserva aptos e metadados das fotos', () {
      final record = MedicaoCampoRecord(
        id: 'm1',
        projectId: 'p1',
        obra: 'Arsen Sabiá',
        servicoCodigo: '5.4',
        servicoNome: 'Piso cerâmico',
        empreiteiroId: 'e1',
        empreiteiroNome: 'Silva',
        periodo: 'Medição 03',
        responsavelNome: 'Luiz',
        aptos: [
          MedicaoCampoApto(
            torre: 'Paris',
            localRef: 'APTO_1101',
            label: '1101',
            andar: 11,
            status: MedicaoStatus.conferido,
            observacao: 'ok',
            fotos: [
              MedicaoCampoFoto(
                id: 'f1',
                localPath: '/tmp/a.jpg',
                dataUrl: 'data:image/jpeg;base64,AAAA',
                legenda: 'x',
                capturedAt: DateTime(2026, 10, 5),
                usuario: 'Luiz',
              ),
            ],
          ),
        ],
        createdAt: DateTime(2026, 10, 5),
        updatedAt: DateTime(2026, 10, 5),
        ano: 2026,
        mes: 9,
      );
      final map = record.toMap();
      final foto = ((map['aptos'] as List).first as Map)['fotos'] as List;
      expect((foto.first as Map).containsKey('dataUrl'), isFalse);
      expect((foto.first as Map).containsKey('localPath'), isFalse);

      final back = MedicaoCampoRecord.fromMap(map);
      expect(back.aptos.single.label, '1101');
      expect(back.aptos.single.status, MedicaoStatus.conferido);
      expect(back.aptos.single.fotos.single.legenda, 'x');
      expect(back.servicoNome, 'Piso cerâmico');
      expect(back.ano, 2026);
      expect(back.mes, 9);
    });

    test('copyWith não altera o id nem a criação', () {
      final r = MedicaoCampoRecord(
        id: 'm1',
        projectId: 'p1',
        obra: 'o',
        servicoCodigo: 's',
        servicoNome: 's',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        ano: 2026,
        mes: 1,
      );
      final c = r.copyWith(periodo: 'novo');
      expect(c.id, 'm1');
      expect(c.createdAt, DateTime(2026, 1, 1));
      expect(c.periodo, 'novo');
    });
  });

  group('pastas ano/mês/empreiteiro', () {
    MedicaoCampoRecord med(String id, int ano, int mes, String empId, String empNome) {
      return MedicaoCampoRecord(
        id: id,
        projectId: 'p',
        obra: 'o',
        servicoCodigo: 's',
        servicoNome: 's',
        empreiteiroId: empId,
        empreiteiroNome: empNome,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        ano: ano,
        mes: mes,
      );
    }

    test('rótulo do empreiteiro junta especialidade e nome', () {
      expect(rotuloEmpreiteiro(especialidade: 'Eletricista', nome: 'Marcio'), 'Eletricista - Marcio');
      expect(rotuloEmpreiteiro(especialidade: '', nome: 'Marcio'), 'Marcio');
    });

    test('nome do mês em português', () {
      expect(nomeMes(9), 'Setembro');
      expect(nomeMes(3), 'Março');
      expect(nomeMes(13), '-');
    });

    test('anos e meses vêm das medições e das pastas vazias, mais novo primeiro', () {
      final lista = [med('a', 2026, 9, 'e1', 'x'), med('b', 2025, 12, 'e1', 'x')];
      expect(anosDasPastas(lista, {'2027'}), [2027, 2026, 2025]);
      expect(mesesDasPastas(lista, {'2026|10'}, 2026), [10, 9]);
      expect(mesesDasPastas(lista, <String>{}, 2025), [12]);
    });

    test('agrupa por empreiteiro só dentro do ano/mês escolhido', () {
      final lista = [
        med('a', 2026, 9, 'e1', 'Eletricista - Marcio'),
        med('b', 2026, 9, 'e1', 'Eletricista - Marcio'),
        med('c', 2026, 9, 'e2', 'Pintor - Ze'),
        med('d', 2026, 8, 'e1', 'Eletricista - Marcio'),
      ];
      final g = agruparPorEmpreiteiro(lista, 2026, 9);
      expect(g.keys.toSet(), {'e1', 'e2'});
      expect(g['e1']!.length, 2);
      expect(g['e2']!.length, 1);
    });
  });
}
