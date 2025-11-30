import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String? initialFilePath;
  
  // Plugin nie wspiera Windows/Linux, więc wywołujemy go warunkowo
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      initialFilePath = initialMedia.first.path;
    }
  }

  runApp(OperatFlowApp(initialFilePath: initialFilePath));
}

class OperatFlowApp extends StatelessWidget {
  final String? initialFilePath;
  const OperatFlowApp({super.key, this.initialFilePath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OperatFlow GML Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomePage(initialFilePath: initialFilePath),
    );
  }
}