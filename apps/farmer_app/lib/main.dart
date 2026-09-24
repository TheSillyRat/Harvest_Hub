import 'package:flutter/material.dart';

void main() => runApp(const FarmerApp());

class FarmerApp extends StatelessWidget {
  const FarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Farmer App Shell')),
        body: const Center(child: Text('Farmer App Skeleton')),
      ),
    );
  }
}
