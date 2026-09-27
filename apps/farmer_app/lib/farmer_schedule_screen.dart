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
  late TimeOfDay _morningOpen;
  late TimeOfDay _morningClose;
  late TimeOfDay _afternoonOpen;
  late TimeOfDay _afternoonClose;
  bool _isSaving = false;

  late final Set<String> _savedDays;
  late final TimeOfDay _savedMorningOpen;
  late final TimeOfDay _savedMorningClose;
  late final TimeOfDay _savedAfternoonOpen;
  late final TimeOfDay _savedAfternoonClose;

  @override
  void initState() {
    super.initState();
    _parseInitialData();
    _savedDays = Set<String>.from(_selectedDays);
    _savedMorningOpen = _morningOpen;
    _savedMorningClose = _morningClose;
    _savedAfternoonOpen = _afternoonOpen;
    _savedAfternoonClose = _afternoonClose;
  }

  void _parseInitialData() {
    if (widget.initialOperatingDays != null &&
        widget.initialOperatingDays!.isNotEmpty) {
      _selectedDays = Set<String>.from(widget.initialOperatingDays!);
    } else {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    }

    _morningOpen = const TimeOfDay(hour: 7, minute: 0);
    _morningClose = const TimeOfDay(hour: 11, minute: 30);
    _afternoonOpen = const TimeOfDay(hour: 13, minute: 30);
    _afternoonClose = const TimeOfDay(hour: 18, minute: 0);

    final raw = widget.initialOperatingHours?.trim() ?? '';
    if (raw.isNotEmpty) {
      final sessions = raw.split(RegExp(r'[,&]'));
      if (sessions.length >= 2) {
        final morningParts = sessions[0].split('-');
        if (morningParts.length == 2) {
          final o = _parseTime(morningParts[0].trim());
          final c = _parseTime(morningParts[1].trim());
          if (o != null) _morningOpen = o;
          if (c != null) _morningClose = c;
        }
        final afternoonParts = sessions[1].split('-');
        if (afternoonParts.length == 2) {
          final o = _parseTime(afternoonParts[0].trim());
          final c = _parseTime(afternoonParts[1].trim());
          if (o != null) _afternoonOpen = o;
          if (c != null) _afternoonClose = c;
        }
      } else if (sessions.length == 1 && sessions[0].contains('-')) {
        final parts = sessions[0].split('-');
        if (parts.length == 2) {
          final o = _parseTime(parts[0].trim());
          final c = _parseTime(parts[1].trim());
          if (o != null) _morningOpen = o;
          if (c != null) _afternoonClose = c;
        }
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
    if (sorted.length == 6 && sorted[0] == 'Mon' && sorted[5] == 'Sat') {
      return 'Mon - Sat';
    }

    return sorted.join(', ');
  }

  String _buildOperatingHoursString() {
    final morning =
        '${_formatTimeOfDay(_morningOpen)} - ${_formatTimeOfDay(_morningClose)}';
    final afternoon =
        '${_formatTimeOfDay(_afternoonOpen)} - ${_formatTimeOfDay(_afternoonClose)}';
    return '$morning, $afternoon';
  }

  bool _hasChanges() {
    if (_selectedDays.length != _savedDays.length) return true;
    if (!_selectedDays.containsAll(_savedDays)) return true;
    if (_morningOpen != _savedMorningOpen) return true;
    if (_morningClose != _savedMorningClose) return true;
    if (_afternoonOpen != _savedAfternoonOpen) return true;
    if (_afternoonClose != _savedAfternoonClose) return true;
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

    final mOpenMin = _morningOpen.hour * 60 + _morningOpen.minute;
    final mCloseMin = _morningClose.hour * 60 + _morningClose.minute;
    final aOpenMin = _afternoonOpen.hour * 60 + _afternoonOpen.minute;
    final aCloseMin = _afternoonClose.hour * 60 + _afternoonClose.minute;

    if (mCloseMin <= mOpenMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Morning close time must be after morning open time.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (aOpenMin < mCloseMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Afternoon open time must be after morning close time.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (aCloseMin <= aOpenMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Afternoon close time must be after afternoon open time.'),
          backgroundColor: FarmerColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final hoursStr = _buildOperatingHoursString();
      final sortedDays =
          _allDays.where((d) => _selectedDays.contains(d)).toList();

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerId)
          .set({
        'operatingHours': hoursStr,
        'operatingDays': sortedDays,
        'morningOpen': _formatTimeOfDay(_morningOpen),
        'morningClose': _formatTimeOfDay(_morningClose),
        'afternoonOpen': _formatTimeOfDay(_afternoonOpen),
        'afternoonClose': _formatTimeOfDay(_afternoonClose),
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

  Widget _buildTimeCard({
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FarmerColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    size: 18,
                    color: FarmerColors.accentGold,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Morning Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTimeCard(
                  label: 'Morning Open',
                  icon: Icons.login_rounded,
                  iconColor: FarmerColors.accentGold,
                  time: _morningOpen,
                  onTap: () => _pickTime(
                    initialTime: _morningOpen,
                    onSelected: (t) => _morningOpen = t,
                  ),
                ),
                const SizedBox(width: 12),
                _buildTimeCard(
                  label: 'Morning Close',
                  icon: Icons.logout_rounded,
                  iconColor: FarmerColors.accentGold,
                  time: _morningClose,
                  onTap: () => _pickTime(
                    initialTime: _morningClose,
                    onSelected: (t) => _morningClose = t,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FarmerColors.primaryOlive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.wb_twilight_rounded,
                    size: 18,
                    color: FarmerColors.primaryOlive,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Afternoon Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FarmerColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTimeCard(
                  label: 'Afternoon Open',
                  icon: Icons.login_rounded,
                  iconColor: FarmerColors.primaryOlive,
                  time: _afternoonOpen,
                  onTap: () => _pickTime(
                    initialTime: _afternoonOpen,
                    onSelected: (t) => _afternoonOpen = t,
                  ),
                ),
                const SizedBox(width: 12),
                _buildTimeCard(
                  label: 'Afternoon Close',
                  icon: Icons.logout_rounded,
                  iconColor: FarmerColors.primaryOlive,
                  time: _afternoonClose,
                  onTap: () => _pickTime(
                    initialTime: _afternoonClose,
                    onSelected: (t) => _afternoonClose = t,
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
