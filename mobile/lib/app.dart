import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'services/backend_service.dart';

class WasteMassEstimatorApp extends StatelessWidget {
  const WasteMassEstimatorApp({super.key});

  static const appTitle = 'MassaR';
  static const appSubtitle = 'Estimativa de Massa de Residuos';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomeScreen(backendService: BackendService()),
    );
  }
}
