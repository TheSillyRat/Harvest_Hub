import 'package:flutter/material.dart';

void main() => runApp(const CustomerApp());

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Customer App Shell')),
        body: const Center(child: Text('Customer App Skeleton')),
      ),
    );
  }
}
