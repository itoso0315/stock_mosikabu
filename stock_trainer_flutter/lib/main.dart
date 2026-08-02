import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const StockTrainerApp());
}

class StockTrainerApp extends StatelessWidget {
  const StockTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
