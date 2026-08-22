import 'package:flutter_test/flutter_test.dart';
import 'package:obra_check/utils/similar_name.dart';

void main() {
  group('levenshteinDistance', () {
    test('strings idênticas têm distância zero', () {
      expect(levenshteinDistance('lixadeira', 'lixadeira'), 0);
    });

    test('uma inserção conta como distância 1', () {
      expect(levenshteinDistance('lixadeira', 'lixaderia'), 2);
    });

    test('string vazia conta o tamanho da outra', () {
      expect(levenshteinDistance('', 'abc'), 3);
      expect(levenshteinDistance('abc', ''), 3);
    });
  });

  group('areSimilarNames', () {
    test('nomes idênticos (após normalizar) NÃO são "parecidos"', () {
      expect(areSimilarNames('Lixadeira', 'lixadeira'), false);
      expect(areSimilarNames('Lixadeira  Angular', 'lixadeira angular'), false);
    });

    test('um nome contido no outro é parecido (ex. do usuário)', () {
      expect(areSimilarNames('Lixadeira', 'Lixadeira Angular'), true);
    });

    test('pequeno erro de digitação é parecido', () {
      expect(areSimilarNames('Lixadeira', 'Lixaderia'), true);
    });

    test('nomes bem diferentes não são parecidos', () {
      expect(areSimilarNames('Lixadeira', 'Furadeira de Impacto'), false);
    });

    test('string vazia nunca é parecida', () {
      expect(areSimilarNames('', 'Lixadeira'), false);
    });
  });

  group('findSimilarNames', () {
    test('filtra só os nomes parecidos da lista', () {
      final result = findSimilarNames('Lixadeira', [
        'Lixadeira Angular',
        'Furadeira',
        'Compactador de Solo',
      ]);
      expect(result, ['Lixadeira Angular']);
    });
  });
}
