import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

import '../location/customer_location.dart';

class ProductFilters {
  final String? categoryId;
  final String sort;
  final bool inStock;
  final double? radiusKm;
  final double? minPrice;
  final double? maxPrice;

  const ProductFilters(
      {this.categoryId,
      this.sort = 'newest',
      this.inStock = false,
      this.radiusKm,
      this.minPrice,
      this.maxPrice});
}

class ProductFiltersSheet extends StatefulWidget {
  final ProductFilters initial;
  final List<Category> categories;
  final CustomerLocation location;
  const ProductFiltersSheet(
      {super.key,
      required this.initial,
      required this.categories,
      required this.location});

  @override
  State<ProductFiltersSheet> createState() => _ProductFiltersSheetState();
}

class _ProductFiltersSheetState extends State<ProductFiltersSheet> {
  late String? _category;
  late String _sort;
  late bool _inStock;
  double? _radiusKm;
  late final TextEditingController _min;
  late final TextEditingController _max;
  var _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initial.radiusKm;
    _category = widget.initial.categoryId;
    _sort = widget.initial.sort;
    _inStock = widget.initial.inStock;
    _min =
        TextEditingController(text: widget.initial.minPrice?.toString() ?? '');
    _max =
        TextEditingController(text: widget.initial.maxPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _category = null;
        _sort = 'newest';
        _radiusKm = null;
        _inStock = false;
        _min.clear();
        _max.clear();
        _form = GlobalKey<FormState>();
      });

  Future<bool> _ensureLocation() async =>
      widget.location.position != null || await widget.location.locate();

  Future<void> _apply() async {
    if (!_form.currentState!.validate()) return;
    if ((_sort == 'nearest' || _radiusKm != null) && !await _ensureLocation()) {
      return;
    }
    if (!mounted) return;
    Navigator.pop(
        context,
        ProductFilters(
            categoryId: _category,
            sort: _sort,
            radiusKm: _radiusKm,
            inStock: _inStock,
            minPrice: double.tryParse(_min.text.trim()),
            maxPrice: double.tryParse(_max.text.trim())));
  }

  String? _priceError(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.trim());
    return value == null || !value.isFinite || value < 0
        ? 'Enter a valid price'
        : null;
  }

  static const _titleStyle =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static const _bodyStyle = TextStyle(fontSize: 12, color: HhColors.muted);

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: HhColors.text.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle),
                  const SizedBox(height: 8),
                  child,
                ]),
          ),
        ),
      );

  Future<void> _chooseSort(String key, bool enabled) async {
    if (enabled && key == 'nearest' && !await _ensureLocation()) return;
    if (!mounted) return;
    setState(() => _sort = enabled ? key : 'newest');
  }

  Widget _pickButton(String label, bool selected, VoidCallback? onPressed) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          foregroundColor: selected ? Colors.white : HhColors.text,
          backgroundColor: selected ? HhColors.primary : Colors.white,
          side: BorderSide(
              color: selected
                  ? HhColors.primary
                  : HhColors.text.withValues(alpha: 0.16)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label),
      );

  Widget _nearestSection() => _section(
      'Distance',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Compare your current location with each store pickup point.',
              style: _bodyStyle),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: const Text('Limit distance',
                  style: TextStyle(fontSize: 13)),
              subtitle: const Text('Approximate straight-line distance to pickup',
                  style: _bodyStyle),
              value: _radiusKm != null,
              onChanged: widget.location.loading
                  ? null
                  : (enabled) async {
                      if (enabled && !await _ensureLocation()) return;
                      if (mounted) {
                        setState(() => _radiusKm = enabled ? 10 : null);
                      }
                    }),
          Text(
              _radiusKm == null
                  ? 'Any distance'
                  : 'Within ${_radiusKm!.round()} km',
              style: const TextStyle(fontSize: 12)),
          Slider(
              key: const Key('distance-slider'),
              value: _radiusKm ?? 10,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${(_radiusKm ?? 10).round()} km',
              onChanged: _radiusKm == null || widget.location.loading
                  ? null
                  : (value) => setState(() => _radiusKm = value)),
          if (widget.location.loading)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Finding your location...')),
          if (widget.location.message != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.location.message!)),
          if (widget.location.issue == LocationIssue.blocked ||
              widget.location.issue == LocationIssue.disabled)
            TextButton(
                onPressed: widget.location.openSettings,
                child: const Text('Open settings')),
          if (widget.location.position != null &&
              widget.location.position!.accuracyMeters > 100)
            const Text(
                'Your location is approximate, so nearby results may vary.',
                style: TextStyle(fontSize: 12, color: HhColors.muted)),
        ],
      ));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.location,
        builder: (context, _) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .9,
            child: SafeArea(
                child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Product filters',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold))),
                    TextButton(
                        onPressed: _reset, child: const Text('Reset All')),
                    IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ])),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(
                              'Product category',
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ChoiceChip(
                                    label: const Text('All categories',
                                        style: TextStyle(fontSize: 12)),
                                    visualDensity: VisualDensity.compact,
                                    selected: _category == null,
                                    onSelected: (_) =>
                                        setState(() => _category = null)),
                                for (final category in widget.categories)
                                  ChoiceChip(
                                      label: Text(category.name,
                                          style: const TextStyle(fontSize: 12)),
                                      visualDensity: VisualDensity.compact,
                                      selected: _category == category.id,
                                      onSelected: (_) => setState(
                                          () => _category = category.id)),
                              ])),
                          _nearestSection(),
                          _section(
                              'Price',
                              DropdownButton<String>(
                                key: const Key('price-sort'),
                                isExpanded: true,
                                isDense: true,
                                value: _sort == 'price_asc' ||
                                        _sort == 'price_desc'
                                    ? _sort
                                    : null,
                                hint: const Text('Choose one',
                                    style: TextStyle(fontSize: 12)),
                                style: const TextStyle(
                                    fontSize: 13, color: HhColors.text),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'price_asc',
                                      child: Text('Low to High',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: HhColors.text))),
                                  DropdownMenuItem(
                                      value: 'price_desc',
                                      child: Text('High to Low',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: HhColors.text))),
                                ],
                                onChanged: widget.location.loading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _chooseSort(value, true);
                                        }
                                      },
                              )),
                          _section(
                              'Order',
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _pickButton(
                                    'Newest',
                                    _sort == 'newest',
                                    widget.location.loading
                                        ? null
                                        : () => _chooseSort(
                                            'newest', _sort != 'newest')),
                                _pickButton(
                                    'Nearest',
                                    _sort == 'nearest',
                                    widget.location.loading
                                        ? null
                                        : () => _chooseSort(
                                            'nearest', _sort != 'nearest')),
                              ])),
                          _section(
                              'Name',
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  title: const Text('Name (A-Z)',
                                      style: TextStyle(fontSize: 13)),
                                  subtitle: const Text(
                                      'Alphabetical order',
                                      style: _bodyStyle),
                                  value: _sort == 'name',
                                  onChanged: widget.location.loading
                                      ? null
                                      : (enabled) =>
                                          _chooseSort('name', enabled))),
                          _section(
                              'Price range',
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: TextFormField(
                                            controller: _min,
                                            validator: _priceError,
                                            style: const TextStyle(fontSize: 13),
                                            decoration: const InputDecoration(
                                                isDense: true,
                                                labelStyle:
                                                    TextStyle(fontSize: 12),
                                                labelText: 'Min price (USD)'),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: TextFormField(
                                            controller: _max,
                                            style: const TextStyle(fontSize: 13),
                                            decoration: const InputDecoration(
                                                isDense: true,
                                                labelStyle:
                                                    TextStyle(fontSize: 12),
                                                labelText: 'Max price (USD)'),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            validator: (text) {
                                              final error = _priceError(text);
                                              if (error != null) return error;
                                              final min = double.tryParse(
                                                  _min.text.trim());
                                              final max = double.tryParse(
                                                  _max.text.trim());
                                              return min != null &&
                                                      max != null &&
                                                      max < min
                                                  ? 'Must be at least min price'
                                                  : null;
                                            })),
                                  ])),
                          _section(
                              'Availability',
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  title: const Text('In-Stock Crops Only',
                                      style: TextStyle(fontSize: 13)),
                                  value: _inStock,
                                  onChanged: (value) =>
                                      setState(() => _inStock = value))),
                        ])),
              )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: widget.location.loading ? null : _apply,
                          child: const Text('Apply Filters')))),
            ])),
          ),
        ),
      );
}
