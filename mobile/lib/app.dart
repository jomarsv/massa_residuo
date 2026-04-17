import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'services/backend_service.dart';

class WasteMassEstimatorApp extends StatelessWidget {
  const WasteMassEstimatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residuos Massa Estimada',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomeScreen(backendService: BackendService()),
    );
  }
}
