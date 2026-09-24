import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'models.dart';
import 'theme.dart';

String vnd(num value) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(value);
String errorMessage(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email hoặc mật khẩu không đúng',
      'email-already-in-use' => 'Email đã được sử dụng',
      'weak-password' => 'Mật khẩu cần ít nhất 6 ký tự',
      'invalid-email' => 'Email không hợp lệ',
      'network-request-failed' => 'Không có kết nối mạng, vui lòng thử lại',
      'too-many-requests' => 'Thao tác quá nhiều, vui lòng thử lại sau',
      _ => 'Không thể xác thực. Vui lòng thử lại',
    };
  }
  if (e is FirebaseException) {
    return e.code == 'permission-denied'
        ? 'Bạn không có quyền thực hiện thao tác này'
        : 'Không thể kết nối dữ liệu. Vui lòng thử lại';
  }
  return e
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
}

void showError(BuildContext context, Object e) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(errorMessage(e))));
Future<void> perform(BuildContext context, Future<void> Function() action,
    {String? success}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class HhButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const HhButton(
      {super.key, required this.label, this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) => ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label));
}

class HhTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const HhTextField(
      {super.key,
      required this.controller,
      required this.label,
      this.obscure = false,
      this.maxLines = 1,
      this.keyboardType,
      this.validator});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
          controller: controller,
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: validator ?? requiredValue));
}

String? requiredValue(String? s) =>
    s == null || s.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;
String? emailValidator(String? s) =>
    s == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim())
        ? 'Email không hợp lệ'
        : null;
String? phoneValidator(String? s) =>
    s == null || !RegExp(r'^\+?[0-9 ()-]{8,15}$').hasMatch(s.trim())
        ? 'Số điện thoại không hợp lệ'
        : null;
String? nonNegativeInt(String? s) =>
    int.tryParse(s ?? '') == null || int.parse(s!) < 0
        ? 'Nhập số nguyên không âm'
        : null;

class PriceText extends StatelessWidget {
  final num price;
  const PriceText(this.price, {super.key});
  @override
  Widget build(BuildContext context) => Text(vnd(price),
      style: const TextStyle(
          fontWeight: FontWeight.bold, color: HhColors.primary, fontSize: 18));
}

class ProductImage extends StatelessWidget {
  final String url;
  const ProductImage(this.url, {super.key});
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? const ColoredBox(
          color: Color(0xFFE8F5E9),
          child: Center(child: Icon(Icons.eco, size: 48)))
      : CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => const LoadingView(),
          errorWidget: (context, url, error) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 40)));
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: product.stockQty <= 0 ? .55 : 1,
      child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                        aspectRatio: 1,
                        child: Stack(fit: StackFit.expand, children: [
                      ProductImage(product.imageUrl),
                      if (product.stockQty <= 0)
                        const Align(
                            alignment: Alignment.topLeft,
                            child: Chip(label: Text('Hết hàng')))
                    ])),
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              PriceText(product.price),
                              Text('/ ${product.unit}',
                                  style:
                                      const TextStyle(color: HhColors.muted)),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                                child: Text(product.farmerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: HhColors.primary, fontSize: 12))),
                            ])),
                  ]))));
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.confirmed => Colors.blue,
      OrderStatus.readyForPickup => Colors.teal,
      OrderStatus.completed => Colors.green,
      _ => Colors.grey
    };
    return Chip(
        label: Text(OrderStatus.labelVi(status)),
        backgroundColor: color.withValues(alpha: .14),
        labelStyle: TextStyle(color: color.shade800));
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final Widget? action;
  const EmptyView({super.key, this.message = 'Chưa có dữ liệu', this.action});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.eco_outlined, size: 52, color: HhColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) action!
          ])));
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class DataList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext, List<T>) builder;
  final String empty;
  const DataList(
      {super.key,
      required this.stream,
      required this.builder,
      this.empty = 'Chưa có dữ liệu'});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return EmptyView(message: errorMessage(s.error!));
        if (!s.hasData) return const LoadingView();
        if (s.data!.isEmpty) return EmptyView(message: empty);
        return builder(context, s.data!);
      });
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  const StatCard(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: HhColors.muted)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    color: HhColors.primary,
                    fontWeight: FontWeight.bold))
          ])));
}
