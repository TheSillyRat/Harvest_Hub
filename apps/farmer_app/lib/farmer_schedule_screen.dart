import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'farmer_profile_screen.dart';

class FarmerScheduleScreen extends StatefulWidget {
  final String farmerId;
  final String? initialOperatingHours;
  final List<String>? initialOperatingDays;

  const FarmerScheduleScreen({
    super.key,
    required this.farmerId,
    this.initialOperatingHours,
    this.initialOperatingDays,
  });

  @override
  State<FarmerScheduleScreen> createState() => _FarmerScheduleScreenState();
}

class _FarmerScheduleScreenState extends State<FarmerScheduleScreen> {
  static const List<String> _allDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late Set<String> _selectedDays;
  late TimeOfDay _openTime;
  late TimeOfDay _closeTime;
  bool _isSaving = false;

  late final Set<String> _savedDays;
  late final TimeOfDay _savedOpenTime;
  late final TimeOfDay _savedCloseTime;

  @override
  void initState() {
    super.initState();
    _parseInitialData();
    _savedDays = Set<String>.from(_selectedDays);
    _savedOpenTime = _openTime;
    _savedCloseTime = _closeTime;
  }

  void _parseInitialData() {
    if (widget.initialOperatingDays != null &&
        widget.initialOperatingDays!.isNotEmpty) {
      _selectedDays = Set<String>.from(widget.initialOperatingDays!);
    } else {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    }

    _openTime = const TimeOfDay(hour: 7, minute: 0);
    _closeTime = const TimeOfDay(hour: 18, minute: 0);

    final hoursStr = widget.initialOperatingHours?.trim() ?? '';
    if (hoursStr.contains('-')) {
      final parts = hoursStr.split('-');
      if (parts.length == 2) {
        final parsedOpen = _parseTime(parts[0].trim());
        final parsedClose = _parseTime(parts[1].trim());
        if (parsedOpen != null) _openTime = parsedOpen;
        if (parsedClose != null) _closeTime = parsedClose;
      }
    }
  }

  TimeOfDay? _parseTime(String s) {
    try {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
      if (match != null) {
        final h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDaysSummary() {
    if (_selectedDays.isEmpty) return 'No days selected';
    if (_selectedDays.length == 7) return 'Everyday (Mon - Sun)';

    final weekdays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
    if (_selectedDays.length == 5 &&
        weekdays.every((d) => _selectedDays.contains(d))) {
      return 'Weekdays (Mon - Fri)';
    }

    final weekends = {'Sat', 'Sun'};
    if (_selectedDays.length == 2 &&
        weekends.every((d) => _selectedDays.contains(d))) {
      return 'Weekends (Sat - Sun)';
    }

    final sorted = _allDays.where((d) => _selectedDays.contains(d)).toList();
    if (sorted.length == 6 &&
        sorted[0] == 'Mon' &&
        sorted[5] == 'Sat') {
      return 'Mon - Sat';
    }

    return sorted.join(', ');
  }

  String _buildOperatingHoursString() {
    return '${_formatTimeOfDay(_openTime)} - ${_formatTimeOfDay(_closeTime)}';
  }

  bool _hasChanges() {
    if (_selectedDays.length != _savedDays.length) return true;
    if (!_selectedDays.containsAll(_savedDays)) return true;
    if (_openTime != _savedOpenTime) return true;
    if (_closeTime != _savedCloseTime) return true;
    return false;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes to your operating schedule. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmerColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _pickTime({required bool isOpenTime}) async {
    final initial = isOpenTime ? _openTime : _closeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: FarmerColors.primaryOlive,
              onPrimary: Colors.white,
              onSurface: FarmerColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one operating day.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final openMinutes = _openTime.hour * 60 + _openTime.minute;
    final closeMinutes = _closeTime.hour * 60 + _closeTime.minute;
    if (closeMinutes <= openMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing time must be after opening time.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final hoursStr = _buildOperatingHoursString();
      final sortedDays = _allDays.where((d) => _selectedDays.contains(d)).toList();

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .set({
        'operatingHours': hoursStr,
        'operatingDays': sortedDays,
        'openingTime': _formatTimeOfDay(_openTime),
        'closingTime': _formatTimeOfDay(_closeTime),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operating schedule saved successfully!'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: FarmerColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: FarmerColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FarmerColors.textDark),
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'Operating Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: FarmerColors.textDark,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FarmerColors.primaryOlive.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FarmerColors.primaryOlive.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: FarmerColors.primaryOlive,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Schedule Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: FarmerColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDaysSummary()} • ${_buildOperatingHoursString()}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: FarmerColors.primaryOlive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Operating Days',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select the days your farm or market stall is open for orders and pickup.',
              style: TextStyle(
                fontSize: 13,
                color: FarmerColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('All Days'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedDays.length == 7
                          ? Colors.white
                          : FarmerColors.primaryOlive,
                    ),
                    backgroundColor: _selectedDays.length == 7
                        ? FarmerColors.primaryOlive
                        : FarmerColors.tagBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDays = Set<String>.from(_allDays);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Weekdays (Mon-Fri)'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedDays.length == 5 &&
                              !_selectedDays.contains('Sat') &&
                              !_selectedDays.contains('Sun')
                          ? Colors.white
                          : FarmerColors.primaryOlive,
                    ),
                    backgroundColor: _selectedDays.length == 5 &&
                            !_selectedDays.contains('Sat') &&
                            !_selectedDays.contains('Sun')
                        ? FarmerColors.primaryOlive
                        : FarmerColors.tagBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Weekends (Sat-Sun)'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedDays.length == 2 &&
                              _selectedDays.contains('Sat') &&
                              _selectedDays.contains('Sun')
                          ? Colors.white
                          : FarmerColors.primaryOlive,
                    ),
                    backgroundColor: _selectedDays.length == 2 &&
                            _selectedDays.contains('Sat') &&
                            _selectedDays.contains('Sun')
                        ? FarmerColors.primaryOlive
                        : FarmerColors.tagBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDays = {'Sat', 'Sun'};
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: FarmerColors.primaryOlive,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : FarmerColors.textDark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? FarmerColors.primaryOlive
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: FarmerColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Specify daily opening and closing hours for pickup orders.',
              style: TextStyle(
                fontSize: 13,
                color: FarmerColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isOpenTime: true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.wb_sunny_outlined,
                                size: 16,
                                color: FarmerColors.accentGold,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Open Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: FarmerColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimeOfDay(_openTime),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FarmerColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isOpenTime: false),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.nightlight_round,
                                size: 16,
                                color: FarmerColors.primaryOlive,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Close Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: FarmerColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimeOfDay(_closeTime),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FarmerColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmerColors.primaryOlive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: _isSaving ? null : _saveSchedule,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
