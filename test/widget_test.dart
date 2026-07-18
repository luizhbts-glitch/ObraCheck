// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: fluxo básico de push/pop/dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (routeContext) => Scaffold(
                        appBar: AppBar(title: const Text('Tela B')),
                        body: Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              await showDialog<void>(
                                context: routeContext,
                                builder: (_) => const AlertDialog(
                                  title: Text('Dialogo'),
                                ),
                              );
                            },
                            child: const Text('Abrir diálogo'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Ir para B'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ir para B'));
    await tester.pumpAndSettle();
    expect(find.text('Tela B'), findsOneWidget);

    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Dialogo'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Dialogo'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Ir para B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
