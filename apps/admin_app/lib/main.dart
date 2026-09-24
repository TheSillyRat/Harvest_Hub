import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}


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
