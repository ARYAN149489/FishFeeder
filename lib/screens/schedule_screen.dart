import 'package:flutter/material.dart';
import '../models/feeding_schedule.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  static const List<String> _allDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  void _showAddScheduleSheet() {
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    Set<String> selectedDays = {};
    int durationSeconds = 10;
    final durationController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24, 16, 24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'New Feeding Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time picker
                  const Text(
                    'Feed Time',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor: AppTheme.surfaceDark,
                                hourMinuteColor: AppTheme.primaryTeal
                                    .withValues(alpha: 0.15),
                                dialHandColor: AppTheme.primaryTeal,
                                dialBackgroundColor: AppTheme.cardDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              color: AppTheme.accentCyan, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Day selector
                  const Text(
                    'Repeat Days',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allDays.map((day) {
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.3),
                        checkmarkColor: AppTheme.accentCyan,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.accentCyan : Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryTeal
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Duration (how long food is dispensed)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dispense Duration',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$durationSeconds seconds',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick duration presets
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 20, 30, 60].map((sec) {
                      final isSelected = durationSeconds == sec;
                      return ChoiceChip(
                        label: Text('${sec}s'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() {
                              durationSeconds = sec;
                              durationController.text = sec.toString();
                            });
                          }
                        },
                        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.35),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.accentCyan : Colors.white60,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryTeal : Colors.white12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Custom duration input field
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setSheetState(() => durationSeconds = parsed);
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.timer_outlined,
                          color: AppTheme.accentCyan, size: 20),
                      suffixText: 'seconds',
                      suffixStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      hintText: 'Enter duration in seconds',
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedDays.isEmpty || durationSeconds <= 0
                          ? null
                          : () async {
                              final timeStr =
                                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                              await _firestoreService.addSchedule(
                                time: timeStr,
                                days: selectedDays.toList()
                                  ..sort((a, b) {
                                    return _allDays
                                        .indexOf(a)
                                        .compareTo(_allDays.indexOf(b));
                                  }),
                                durationSeconds: durationSeconds,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Schedule'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: AppTheme.accentCyan, size: 24),
            const SizedBox(width: 8),
            const Text('Schedules'),
          ],
        ),
      ),
      body: StreamBuilder<List<FeedingSchedule>>(
        stream: _firestoreService.streamSchedules(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            );
          }

          final schedules = snapshot.data ?? [];

          if (schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy,
                      size: 64, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  const Text(
                    'No schedules yet',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add a schedule, or load demo schedules',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _firestoreService.seedSampleData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Demo schedules seeded!'),
                            backgroundColor: AppTheme.primaryTeal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Load Demo Schedules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: schedules.length,
            itemBuilder: (context, index) =>
                _buildScheduleCard(schedules[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }

  Widget _buildScheduleCard(FeedingSchedule schedule) {
    return Dismissible(
      key: Key(schedule.id ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppTheme.errorRed),
      ),
      onDismissed: (_) {
        if (schedule.id != null) {
          _firestoreService.deleteSchedule(schedule.id!);
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Time
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: AppTheme.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          schedule.time,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Duration badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 14, color: AppTheme.accentCyan),
                        const SizedBox(width: 4),
                        Text(
                          '${schedule.durationSeconds}s',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Toggle switch
                  Switch(
                    value: schedule.active,
                    onChanged: (value) {
                      if (schedule.id != null) {
                        _firestoreService.updateScheduleActive(
                          schedule.id!, value,
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Day chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _allDays.map((day) {
                  final isActive = schedule.days.contains(day);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryTeal.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.primaryTeal.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppTheme.accentCyan : Colors.white24,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
