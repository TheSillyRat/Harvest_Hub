import 'package:flutter/material.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Admin App Shell')),
        body: const Center(child: Text('Admin App Skeleton')),
      ),
    );
  }
}
