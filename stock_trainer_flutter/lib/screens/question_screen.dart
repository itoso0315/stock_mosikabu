

import 'package:flutter/material.dart';

class QuestionScreen extends StatelessWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題画面'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 72,
              color: Colors.blue,
            ),
            SizedBox(height: 24),
            Text(
              'Question Screen',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'ここにチャートが表示されます',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}