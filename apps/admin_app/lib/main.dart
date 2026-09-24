import 'package:harvesthub_core/harvesthub_core.dart';
import 'admin_app.dart';

Future<void> main() => bootstrap(role: Roles.admin, home: const AdminApp());
