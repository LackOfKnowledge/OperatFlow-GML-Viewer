import 'package:flutter/material.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const OperatFlowApp());
}

class OperatFlowApp extends StatelessWidget {
  const OperatFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OperatFlow GML Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}