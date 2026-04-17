// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:residuos_massa_estimada/data/models/estimate_response.dart';
import 'package:residuos_massa_estimada/data/models/estimation_record.dart';
import 'package:residuos_massa_estimada/data/models/image_analysis.dart';
import 'package:residuos_massa_estimada/domain/entities/app_status.dart';
import 'package:residuos_massa_estimada/presentation/screens/home_screen.dart';
import 'package:residuos_massa_estimada/services/backend_service.dart';

class FakeBackendService extends BackendService {
  FakeBackendService() : super(baseUrl: 'http://localhost');

  @override
  Future<AppStatus> checkStatus() async {
    return const AppStatus(
      isBackendReachable: true,
      message: 'Backend Fake online.',
    );
  }

  @override
  Future<List<EstimationRecord>> fetchHistory() async {
    return [
      EstimationRecord(
        id: '1',
        wasteType: 'plastico',
        volumeMethod: 'recipiente_conhecido',
        estimatedVolumeM3: 0.4,
        densityKgM3: 45,
        estimatedMassKg: 18,
        lowerBoundKg: 15.84,
        upperBoundKg: 20.16,
        confidenceLevel: 'media-alta',
        createdAt: DateTime.parse('2026-04-17T11:23:13.132987Z'),
        notes: 'registro fake',
      ),
    ];
  }

  @override
  Future<EstimateResponseModel> createEstimate(
    Map<String, dynamic> payload,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ImageAnalysisResponse> analyzeImage(file) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('home screen renders core texts', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(backendService: FakeBackendService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estimativa de massa de residuos'), findsOneWidget);
    expect(find.textContaining('Fase 3'), findsOneWidget);
    expect(find.text('Analise assistida por imagem'), findsOneWidget);
    expect(find.text('Nova analise'), findsOneWidget);
    expect(find.text('Calcular estimativa'), findsOneWidget);
  });
}
