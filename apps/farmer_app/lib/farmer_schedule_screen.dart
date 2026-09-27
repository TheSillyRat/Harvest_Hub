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
  List<({TimeOfDay from, TimeOfDay to})> _slots = [];
  bool _isSaving = false;
  bool _isLoading = true;

  late Set<String> _savedDays;
  late TimeOfDay _savedOpenTime;
  late TimeOfDay _savedCloseTime;
  late List<({TimeOfDay from, TimeOfDay to})> _savedSlots;

  @override
  void initState() {
    super.initState();
    _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    _openTime = const TimeOfDay(hour: 7, minute: 0);
    _closeTime = const TimeOfDay(hour: 21, minute: 0);
    _slots = [];
    _savedDays = Set<String>.from(_selectedDays);
    _savedOpenTime = _openTime;
    _savedCloseTime = _closeTime;
    _savedSlots = [];
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .get();
      final data = doc.data();
      if (data != null) {
        _parseFromFirestore(data);
      } else {
        _parseFromWidgetParams();
      }
    } catch (_) {
      _parseFromWidgetParams();
    }

    _savedDays = Set<String>.from(_selectedDays);
    _savedOpenTime = _openTime;
    _savedCloseTime = _closeTime;
    _savedSlots = _slots.map((s) => (from: s.from, to: s.to)).toList();

    if (mounted) setState(() => _isLoading = false);
  }

  void _parseFromFirestore(Map<String, dynamic> data) {
    final days = data['operatingDays'] as List<dynamic>?;
    if (days != null && days.isNotEmpty) {
      _selectedDays = Set<String>.from(days.map((e) => e.toString()));
    } else {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    }

    final openingTime = data['openingTime'] as String?;
    final closingTime = data['closingTime'] as String?;
    final operatingSlots = data['operatingSlots'] as List<dynamic>?;

    if (openingTime != null && closingTime != null) {
      _openTime =
          _parseTime(openingTime) ?? const TimeOfDay(hour: 7, minute: 0);
      _closeTime =
          _parseTime(closingTime) ?? const TimeOfDay(hour: 21, minute: 0);

      if (operatingSlots != null && operatingSlots.isNotEmpty) {
        _slots = operatingSlots.map((s) {
          final map = Map<String, dynamic>.from(s as Map);
          final from = _parseTime(map['from'] as String? ?? '');
          final to = _parseTime(map['to'] as String? ?? '');
          return (
            from: from ?? const TimeOfDay(hour: 7, minute: 0),
            to: to ?? const TimeOfDay(hour: 11, minute: 30),
          );
        }).toList();
      }
    } else {
      _parseLegacyFormat(data);
    }
  }

  void _parseLegacyFormat(Map<String, dynamic> data) {
    final morningOpen = _parseTime(data['morningOpen'] as String? ?? '');
    final morningClose = _parseTime(data['morningClose'] as String? ?? '');
    final afternoonOpen = _parseTime(data['afternoonOpen'] as String? ?? '');
    final afternoonClose = _parseTime(data['afternoonClose'] as String? ?? '');

    if (morningOpen != null && afternoonClose != null) {
      _openTime = morningOpen;
      _closeTime = afternoonClose;
      _slots = [];
      if (morningClose != null) {
        _slots.add((from: morningOpen, to: morningClose));
      }
      if (afternoonOpen != null) {
        _slots.add((from: afternoonOpen, to: afternoonClose));
      }
    } else {
      _parseFromWidgetParams();
    }
  }

  void _parseFromWidgetParams() {
    if (widget.initialOperatingDays != null &&
        widget.initialOperatingDays!.isNotEmpty) {
      _selectedDays = Set<String>.from(widget.initialOperatingDays!);
    } else {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    }

    _openTime = const TimeOfDay(hour: 7, minute: 0);
    _closeTime = const TimeOfDay(hour: 18, minute: 0);
    _slots = [];

    final raw = widget.initialOperatingHours?.trim() ?? '';
    if (raw.isNotEmpty) {
      final sessions = raw.split(RegExp(r'[,&]'));
      for (final session in sessions) {
        final parts = session.split('-');
        if (parts.length == 2) {
          final from = _parseTime(parts[0].trim());
          final to = _parseTime(parts[1].trim());
          if (from != null && to != null) {
            _slots.add((from: from, to: to));
          }
        }
      }
      if (_slots.isNotEmpty) {
        _openTime = _slots.first.from;
        _closeTime = _slots.last.to;
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

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

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
    if (sorted.length == 6 && sorted[0] == 'Mon' && sorted[5] == 'Sat') {
      return 'Mon - Sat';
    }

    return sorted.join(', ');
  }

  String _buildOperatingHoursString() {
    if (_slots.isEmpty) {
      return '${_formatTimeOfDay(_openTime)} - ${_formatTimeOfDay(_closeTime)}';
    }
    return _slots
        .map((s) => '${_formatTimeOfDay(s.from)} - ${_formatTimeOfDay(s.to)}')
        .join(', ');
  }

  bool _hasChanges() {
    if (_selectedDays.length != _savedDays.length) return true;
    if (!_selectedDays.containsAll(_savedDays)) return true;
    if (_openTime != _savedOpenTime) return true;
    if (_closeTime != _savedCloseTime) return true;
    if (_slots.length != _savedSlots.length) return true;
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i].from != _savedSlots[i].from ||
          _slots[i].to != _savedSlots[i].to) {
        return true;
      }
    }
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

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
        onSelected(picked);
      });
    }
  }

  void _addSlot() {
    final closeMin = _timeToMinutes(_closeTime);

    TimeOfDay newFrom = _openTime;
    TimeOfDay newTo = _closeTime;

    if (_slots.isNotEmpty) {
      final lastTo = _slots.last.to;
      final lastToMin = _timeToMinutes(lastTo);
      if (lastToMin + 60 <= closeMin) {
        newFrom = TimeOfDay(hour: lastTo.hour + 1, minute: lastTo.minute);
        newTo = _closeTime;
      } else if (lastToMin < closeMin) {
        newFrom = lastTo;
        newTo = _closeTime;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No room to add another time slot within operating hours.'),
            backgroundColor: FarmerColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _slots.add((from: newFrom, to: newTo));
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  String? _validateSlots() {
    final openMin = _timeToMinutes(_openTime);
    final closeMin = _timeToMinutes(_closeTime);

    if (closeMin <= openMin) {
      return 'Close time must be after open time.';
    }

    for (int i = 0; i < _slots.length; i++) {
      final fromMin = _timeToMinutes(_slots[i].from);
      final toMin = _timeToMinutes(_slots[i].to);

      if (toMin <= fromMin) {
        return 'Slot ${i + 1}: "To" time must be after "From" time.';
      }

      if (fromMin < openMin || toMin > closeMin) {
        return 'Slot ${i + 1} is outside operating hours '
            '(${_formatTimeOfDay(_openTime)} - ${_formatTimeOfDay(_closeTime)}).';
      }
    }

    final sorted = List<({TimeOfDay from, TimeOfDay to})>.from(_slots);
    sorted.sort(
        (a, b) => _timeToMinutes(a.from).compareTo(_timeToMinutes(b.from)));

    for (int i = 1; i < sorted.length; i++) {
      if (_timeToMinutes(sorted[i].from) < _timeToMinutes(sorted[i - 1].to)) {
        return 'Time slots overlap. Please adjust your schedule.';
      }
    }

    return null;
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

    final closeMin = _timeToMinutes(_closeTime);
    final openMin = _timeToMinutes(_openTime);

    if (closeMin <= openMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Close time must be after open time.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_slots.isNotEmpty) {
      final error = _validateSlots();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: FarmerColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final hoursStr = _buildOperatingHoursString();
      final sortedDays =
          _allDays.where((d) => _selectedDays.contains(d)).toList();

      final slotsData = _slots
          .map((s) => {
                'from': _formatTimeOfDay(s.from),
                'to': _formatTimeOfDay(s.to),
              })
          .toList();

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .set({
        'operatingHours': hoursStr,
        'operatingDays': sortedDays,
        'openingTime': _formatTimeOfDay(_openTime),
        'closingTime': _formatTimeOfDay(_closeTime),
        'operatingSlots': slotsData,
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

  Widget _buildQuickDayChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isActive ? Colors.white : FarmerColors.primaryOlive,
      ),
      backgroundColor:
          isActive ? FarmerColors.primaryOlive : FarmerColors.tagBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Row(
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: FarmerColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatTimeOfDay(time),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FarmerColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotRow(int index) {
    final slot = _slots[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FarmerColors.primaryOlive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: FarmerColors.primaryOlive,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(
                initialTime: slot.from,
                onSelected: (t) {
                  _slots[index] = (from: t, to: slot.to);
                },
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.login_rounded,
                        size: 16, color: FarmerColors.primaryOlive),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimeOfDay(slot.from),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FarmerColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                size: 18, color: FarmerColors.textMuted),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(
                initialTime: slot.to,
                onSelected: (t) {
                  _slots[index] = (from: slot.from, to: t);
                },
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 16, color: FarmerColors.primaryOlive),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimeOfDay(slot.to),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FarmerColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _removeSlot(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FarmerColors.alertRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: FarmerColors.alertRed),
            ),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.arrow_back_rounded,
                color: FarmerColors.textDark),
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
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: FarmerColors.primaryOlive))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            FarmerColors.primaryOlive.withValues(alpha: 0.15),
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
                            color: FarmerColors.primaryOlive
                                .withValues(alpha: 0.1),
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
                                'Schedule Preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: FarmerColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDaysSummary(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: FarmerColors.primaryOlive,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _buildOperatingHoursString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FarmerColors.textDark,
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
                        _buildQuickDayChip(
                          label: 'All Days',
                          isActive: _selectedDays.length == 7,
                          onTap: () => setState(
                              () => _selectedDays = Set<String>.from(_allDays)),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDayChip(
                          label: 'Weekdays (Mon-Fri)',
                          isActive: _selectedDays.length == 5 &&
                              !_selectedDays.contains('Sat') &&
                              !_selectedDays.contains('Sun'),
                          onTap: () => setState(() => _selectedDays = {
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri'
                              }),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDayChip(
                          label: 'Weekends (Sat-Sun)',
                          isActive: _selectedDays.length == 2 &&
                              _selectedDays.contains('Sat') &&
                              _selectedDays.contains('Sun'),
                          onTap: () =>
                              setState(() => _selectedDays = {'Sat', 'Sun'}),
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
                          color: isSelected
                              ? Colors.white
                              : FarmerColors.textDark,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              FarmerColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: FarmerColors.accentGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Overall Operating Hours',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FarmerColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set your overall open and close times for the day.',
                    style:
                        TextStyle(fontSize: 13, color: FarmerColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildTimePickerTile(
                        label: 'Open Time',
                        icon: Icons.login_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        time: _openTime,
                        onTap: () => _pickTime(
                          initialTime: _openTime,
                          onSelected: (t) => _openTime = t,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTimePickerTile(
                        label: 'Close Time',
                        icon: Icons.logout_rounded,
                        iconColor: FarmerColors.alertRed,
                        time: _closeTime,
                        onTap: () => _pickTime(
                          initialTime: _closeTime,
                          onSelected: (t) => _closeTime = t,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FarmerColors.primaryOlive
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.view_timeline_rounded,
                          size: 18,
                          color: FarmerColors.primaryOlive,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Time Slots',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FarmerColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _slots.isEmpty
                        ? 'No time slots added. Your store operates continuously during overall hours.'
                        : 'Define specific time windows within your operating hours.',
                    style: const TextStyle(
                        fontSize: 13, color: FarmerColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_slots.length, (i) => _buildSlotRow(i)),
                  InkWell(
                    onTap: _addSlot,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: FarmerColors.primaryOlive
                              .withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: FarmerColors.primaryOlive
                            .withValues(alpha: 0.04),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 20, color: FarmerColors.primaryOlive),
                          SizedBox(width: 6),
                          Text(
                            'Add Time Slot',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FarmerColors.primaryOlive,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
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
