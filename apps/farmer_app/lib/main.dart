import 'package:harvesthub_core/harvesthub_core.dart';
import 'farmer_app.dart';

Future<void> main() => bootstrap(role: Roles.farmer, home: const FarmerApp());
