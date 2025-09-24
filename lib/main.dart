import 'package:blotter_avg/dashboard_window.dart';
import 'package:flutter/material.dart';

import 'image_window.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TIFF Paint App',
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 220, child: DashboardWindow()),
          const VerticalDivider(width: 1),
          Expanded(child: ImageWindow()),
        ],
      ),
    );
  }
}
