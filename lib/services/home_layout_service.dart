import 'package:flutter/foundation.dart';

/// Ponte entre a Home (que sabe se está a rota visível ou coberta por uma
/// tela empurrada por cima) e o `MaterialApp.builder` (que decide se
/// aplica o limite de largura de 900px). Só a Home, sendo a rota raiz,
/// libera a tela cheia — telas empurradas por cima continuam limitadas,
/// pra não quebrar layouts pensados pra ~900px de largura.
class HomeLayoutService {
  HomeLayoutService._();

  static final HomeLayoutService instance = HomeLayoutService._();

  final ValueNotifier<bool> homeIsTopRoute = ValueNotifier<bool>(true);
}
