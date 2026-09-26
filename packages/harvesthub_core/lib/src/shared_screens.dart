import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'models.dart';
import 'order_service.dart';
import 'auth_controller.dart';
import 'widgets.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in [
      'name',
      'email',
      'phone',
      'address',
      'password',
      'confirm',
      'businessName',
      'description',
      'area'
    ])
      k: TextEditingController()
  };
  bool register = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String value(String name) => fields[name]!.text;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                        key: form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.eco,
                                  size: 72, color: HhColors.primary),
                              const SizedBox(height: 12),
                              Text('HarvestHub',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge),
                              Text(
                                  widget.role == Roles.customer
                                      ? 'Fresh produce, near you'
                                      : widget.role == Roles.farmer
                                          ? 'Farmer Storefront'
                                          : 'System Administration',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 28),
                              if (register)
                                HhTextField(
                                    controller: fields['name']!,
                                    label: 'Full Name'),
                              HhTextField(
                                  controller: fields['email']!,
                                  label: 'Email Address',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: emailValidator),
                              if (register) ...[
                                HhTextField(
                                    controller: fields['phone']!,
                                    label: 'Phone Number',
                                    keyboardType: TextInputType.phone,
                                    validator: phoneValidator),
                                HhTextField(
                                    controller: fields['address']!,
                                    label: 'Contact Address'),
                              ],
                              HhTextField(
                                  controller: fields['password']!,
                                  label: 'Password',
                                  obscure: true,
                                  validator: (s) => (s?.length ?? 0) < 6
                                      ? 'Password must be at least 6 characters'
                                      : null),
                              if (register)
                                HhTextField(
                                    controller: fields['confirm']!,
                                    label: 'Confirm Password',
                                    obscure: true,
                                    validator: (s) => s != value('password')
                                        ? 'Passwords do not match'
                                        : null),
                              if (register && widget.role == Roles.farmer) ...[
                                HhTextField(
                                    controller: fields['businessName']!,
                                    label: 'Storefront Name'),
                                HhTextField(
                                    controller: fields['description']!,
                                    label: 'Storefront Description',
                                    maxLines: 3),
                                HhTextField(
                                    controller: fields['area']!,
                                    label: 'Area / Region'),
                              ],
                              HhButton(
                                  label: register ? 'Register' : 'Log In',
                                  busy: auth.isLoading,
                                  onPressed: () async {
                                    if (!form.currentState!.validate()) return;
                                    final success = await (() {
                                      if (!register) {
                                        return auth.login(value('email'),
                                            value('password'), widget.role);
                                      }
                                      if (widget.role == Roles.farmer) {
                                        return auth.registerFarmer(
                                            name: value('name'),
                                            email: value('email'),
                                            phone: value('phone'),
                                            address: value('address'),
                                            password: value('password'),
                                            businessName: value('businessName'),
                                            description: value('description'),
                                            area: value('area'));
                                      }
                                      return auth.registerCustomer(
                                          name: value('name'),
                                          email: value('email'),
                                          phone: value('phone'),
                                          address: value('address'),
                                          password: value('password'));
                                    })();
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(auth.errorMessage ??
                                                'Authentication failed')),
                                      );
                                    }
                                  }),
                              if (widget.role != Roles.admin)
                                TextButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => setState(
                                            () => register = !register),
                                    child: Text(register
                                        ? 'Already have an account? Log In'
                                        : 'Do not have an account? Register')),
                              const SizedBox(height: 16),
                              const Text(pickupNotice,
                                  textAlign: TextAlign.center),
                            ]))))));
  }
}

class ProfileScreen extends StatelessWidget {
  final List<Widget> extra;
  const ProfileScreen({super.key, this.extra = const []});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) {
      return const EmptyView(message: 'Not logged in');
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 48)),
      const SizedBox(height: 16),
      Text(user.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
      Text(user.email, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.phone), title: Text(user.phone)),
      ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(user.address)),
      ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit Profile'),
          onTap: () => openPage(context, EditProfileScreen(user: user))),
      ...extra,
      ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log Out'),
          onTap: () => perform(context, context.read<AuthController>().logout)),
    ]);
  }
}

class EditProfileScreen extends StatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.user.name);
  late final phone = TextEditingController(text: widget.user.phone);
  late final address = TextEditingController(text: widget.user.address);
  final business = TextEditingController(),
      description = TextEditingController(),
      area = TextEditingController();
  bool busy = false, loaded = false;
  Object? loadError;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (widget.user.role == Roles.farmer) {
      try {
        final d = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(widget.user.uid)
            .get();
        if (d.exists && d.data() != null) {
          final p = FarmerProfile.fromMap(d.data()!, id: d.id);
          business.text = p.businessName;
          description.text = p.description;
          area.text = p.area;
        }
      } catch (e) {
        loadError = e;
      }
    }
    if (mounted) setState(() => loaded = true);
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, business, description, area]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: !loaded
          ? const LoadingView()
          : loadError != null
              ? EmptyView(message: errorMessage(loadError!))
              : Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    HhTextField(controller: name, label: 'Full Name'),
                    HhTextField(
                        controller: phone,
                        label: 'Phone Number',
                        validator: phoneValidator),
                    HhTextField(controller: address, label: 'Contact Address'),
                    if (widget.user.role == Roles.farmer) ...[
                      HhTextField(
                          controller: business, label: 'Storefront Name'),
                      HhTextField(
                          controller: description,
                          label: 'Description',
                          maxLines: 3),
                      HhTextField(controller: area, label: 'Area / Region'),
                    ],
                    HhButton(
                        label: 'Save Profile',
                        busy: busy,
                        onPressed: () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => busy = true);
                          try {
                            final db = FirebaseFirestore.instance;
                            final batch = db.batch();
                            batch.update(
                                db.collection('users').doc(widget.user.uid), {
                              'name': name.text.trim(),
                              'phone': phone.text.trim(),
                              'address': address.text.trim()
                            });
                            if (widget.user.role == Roles.farmer) {
                              batch.update(
                                  db.collection('farmers').doc(widget.user.uid),
                                  {
                                    'businessName': business.text.trim(),
                                    'description': description.text.trim(),
                                    'area': area.text.trim()
                                  });
                            }
                            await batch.commit();
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        }),
                  ])));
}

class OrdersScreen extends StatefulWidget {
  final Stream<List<FarmOrder>> stream;
  final String role;
  const OrdersScreen({super.key, required this.stream, required this.role});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String? status;
  @override
  Widget build(BuildContext context) => Column(children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: const Text('All'),
                      selected: status == null,
                      onSelected: (_) => setState(() => status = null))),
              ...OrderStatus.labels.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(e.value),
                      selected: status == e.key,
                      onSelected: (_) => setState(() => status = e.key)))),
            ])),
        Expanded(
            child: DataList<FarmOrder>(
                stream: widget.stream,
                empty: 'No orders available',
                builder: (context, orders) {
                  final filtered = orders
                      .where((o) => status == null || o.status == status)
                      .toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(message: 'No orders in this status');
                  }
                  return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final o = filtered[i];
                        return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                                title: Text(widget.role == Roles.customer
                                    ? o.farmerName
                                    : o.customerName),
                                subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '#${o.id.substring(0, o.id.length > 8 ? 8 : o.id.length)} · ${DateFormat('dd/MM/yyyy').format(o.createdAt)}'),
                                      StatusChip(o.status),
                                      PriceText(o.total),
                                    ]),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => openPage(
                                    context,
                                    OrderDetailScreen(
                                        id: o.id, role: widget.role))));
                      });
                })),
      ]);
}

class OrderDetailScreen extends StatefulWidget {
  final String id, role;
  const OrderDetailScreen({super.key, required this.id, required this.role});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final stream = OrderService().watch(widget.id);
  bool busy = false;
  Future<void> change(Future<void> Function() action,
      {bool cancel = false}) async {
    if (cancel) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Cancel Order?'),
                  content: const Text(
                      'Ordered item quantities will be returned to stock.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Go Back')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Cancel Order'))
                  ]));
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    await perform(context, action);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: StreamBuilder<FarmOrder?>(
          stream: stream,
          builder: (context, s) {
            if (s.hasError) return EmptyView(message: errorMessage(s.error!));
            if (s.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (s.data == null) {
              return const EmptyView(message: 'Order not found');
            }
            final o = s.data!;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text('Order ID: ${o.id}'),
              Align(
                  alignment: Alignment.centerLeft, child: StatusChip(o.status)),
              Text(o.farmerName, style: Theme.of(context).textTheme.titleLarge),
              Text('Customer: ${o.customerName} · ${o.customerPhone}'),
              Text('Contact Address: ${o.address}'),
              Text(
                  'Pickup Slot: ${pickupSlots[o.pickupSlot] ?? o.pickupSlot} · ${DateFormat('dd/MM/yyyy').format(o.pickupDate)}'),
              const SizedBox(height: 12),
              const Text(pickupNotice),
              const Text(simulationNotice),
              const Divider(),
              ...o.items.map((i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.name),
                  subtitle: Text('${i.qty} ${i.unit} × ${vnd(i.price)}'),
                  trailing: Text(vnd(i.subtotal)))),
              const Divider(),
              PriceText(o.total),
              const SizedBox(height: 24),
              if (widget.role != Roles.customer &&
                  OrderStatus.next.containsKey(o.status))
                HhButton(
                    label:
                        'Mark as ${OrderStatus.labels[OrderStatus.next[o.status]!]}',
                    busy: busy,
                    onPressed: () =>
                        change(() => OrderService().advanceStatus(o.id))),
              if (OrderStatus.canCancel(o.status))
                TextButton(
                    onPressed: busy
                        ? null
                        : () => change(() => OrderService().cancel(o.id),
                            cancel: true),
                    child: const Text('Cancel Order',
                        style: TextStyle(color: HhColors.danger))),
            ]);
          }));
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Về HarvestHub')),
      body: ListView(padding: const EdgeInsets.all(24), children: const [
        Icon(Icons.eco, size: 72, color: HhColors.primary),
        SizedBox(height: 20),
        Text('Từ nông trại đến bàn ăn',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text(
            'HarvestHub kết nối người mua với nông dân địa phương. Khám phá nông sản, đặt trước và đến nhận tại điểm bán.'),
        SizedBox(height: 20),
        Text(pickupNotice),
        Text(simulationNotice),
      ]));
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(), message = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Liên hệ')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            HhTextField(controller: subject, label: 'Chủ đề'),
            HhTextField(controller: message, label: 'Nội dung', maxLines: 6),
            HhButton(
                label: 'Gửi liên hệ',
                busy: busy,
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  final u = context.read<AuthController>().user;
                  if (u == null) return;
                  setState(() => busy = true);
                  try {
                    await FirebaseFirestore.instance.collection('contacts').add(
                          ContactMessage(
                            id: '',
                            name: u.name,
                            email: u.email,
                            subject: subject.text.trim(),
                            message: message.text.trim(),
                            createdAt: DateTime.now(),
                            sourceApp: 'customer_app',
                          ).toMap(),
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã gửi liên hệ')));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }),
          ])));
}
