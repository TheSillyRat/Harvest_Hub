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
      this.inStock = true,
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
  bool _priceMenuOpen = false;
  static const _rangeFloor = 0.0;
  static const _rangeCeil = 1000.0;
  late RangeValues _range;
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
    final start = (widget.initial.minPrice ?? _rangeFloor)
        .clamp(_rangeFloor, _rangeCeil)
        .toDouble();
    final end = (widget.initial.maxPrice ?? _rangeCeil)
        .clamp(_rangeFloor, _rangeCeil)
        .toDouble();
    _range = RangeValues(start <= end ? start : end, end);
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
        _priceMenuOpen = false;
        _inStock = true;
        _range = const RangeValues(_rangeFloor, _rangeCeil);
        _min.clear();
        _max.clear();
        _form = GlobalKey<FormState>();
      });

  Future<bool> _ensureLocation() => widget.location.ensureRecent();

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
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: _titleStyle),
                    const SizedBox(height: 8),
                    child,
                  ]),
            ),
          ),
        ),
      );

  Future<void> _chooseSort(String key, bool enabled) async {
    if (enabled && key == 'nearest' && !await _ensureLocation()) return;
    if (!mounted) return;
    setState(() => _sort = enabled ? key : 'newest');
  }

  String get _priceSortLabel => switch (_sort) {
        'price_asc' => 'Low to High',
        'price_desc' => 'High to Low',
        _ => 'Choose one',
      };

  void _setPriceSpan(RangeValues values) {
    final start = values.start.clamp(_rangeFloor, _rangeCeil).toDouble();
    final end = values.end.clamp(start, _rangeCeil).toDouble();
    setState(() {
      _range = RangeValues(start, end);
      _min.text = start.round().toString();
      _max.text = end.round().toString();
    });
  }

  void _syncSpanFromFields() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    if (min == null || max == null || min < 0 || max < min) return;
    setState(() {
      _range = RangeValues(
        min.clamp(_rangeFloor, _rangeCeil).toDouble(),
        max.clamp(_rangeFloor, _rangeCeil).toDouble(),
      );
    });
  }

  InputDecoration _priceField(String label) => InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: HhColors.text.withValues(alpha: 0.35)),
        ),
      );

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
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  InkWell(
                                    key: const Key('price-sort'),
                                    onTap: widget.location.loading
                                        ? null
                                        : () => setState(() =>
                                            _priceMenuOpen = !_priceMenuOpen),
                                    child: InputDecorator(
                                      decoration: _priceField('Price'),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text(_priceSortLabel,
                                                style: const TextStyle(
                                                    fontSize: 13))),
                                        Icon(
                                            _priceMenuOpen
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            size: 18),
                                      ]),
                                    ),
                                  ),
                                  if (_priceMenuOpen) ...[
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, children: [
                                      _pickButton(
                                          'Low to High',
                                          _sort == 'price_asc',
                                          () => _chooseSort('price_asc',
                                              _sort != 'price_asc')),
                                      _pickButton(
                                          'High to Low',
                                          _sort == 'price_desc',
                                          () => _chooseSort('price_desc',
                                              _sort != 'price_desc')),
                                    ]),
                                  ],
                                ],
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: TextFormField(
                                                controller: _min,
                                                validator: _priceError,
                                                onChanged: (_) =>
                                                    _syncSpanFromFields(),
                                                style: const TextStyle(
                                                    fontSize: 13),
                                                decoration:
                                                    _priceField('Min price'),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true))),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: TextFormField(
                                                controller: _max,
                                                onChanged: (_) =>
                                                    _syncSpanFromFields(),
                                                style: const TextStyle(
                                                    fontSize: 13),
                                                decoration:
                                                    _priceField('Max price'),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                validator: (text) {
                                                  final error =
                                                      _priceError(text);
                                                  if (error != null) {
                                                    return error;
                                                  }
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
                                      ]),
                                  RangeSlider(
                                    values: _range,
                                    min: _rangeFloor,
                                    max: _rangeCeil,
                                    divisions: 100,
                                    labels: RangeLabels(
                                      _range.start.round().toString(),
                                      _range.end.round().toString(),
                                    ),
                                    onChanged: _setPriceSpan,
                                  ),
                                  Text(
                                    'Within ${_range.start.round()} – ${_range.end.round()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              )),
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
      ),
      );
}
