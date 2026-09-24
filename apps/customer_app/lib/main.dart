import 'package:harvesthub_core/harvesthub_core.dart';
import 'customer_app.dart';

Future<void> main() =>
    bootstrap(role: Roles.customer, home: const CustomerApp());
