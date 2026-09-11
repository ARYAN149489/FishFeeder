import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSendingCommand = false;
  bool _isProcessingData = false;

  Future<void> _sendCommand(String type) async {
    setState(() => _isSendingCommand = true);
    try {
      await _firestoreService.sendCommand(type);
      if (mounted) {
        final label = type == 'start_feeding' ? 'Start' : 'Stop';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  type == 'start_feeding'
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text('$label feeding command sent to device!'),
              ],
            ),
            backgroundColor: type == 'start_feeding'
                ? AppTheme.successGreen
                : AppTheme.warningAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Command failed: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCommand = false);
    }
  }

  Future<void> _seedDummyData() async {
    setState(() => _isProcessingData = true);
    try {
      await _firestoreService.seedSampleData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Dummy sensor, schedule & history data seeded!'),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to seed data: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingData = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber),
            SizedBox(width: 8),
            Text('Clear All Data?'),
          ],
        ),
        content: const Text(
          'This will delete all test records from sensor readings, schedules, history, and commands in Firestore.\n\nYou can re-seed dummy data anytime.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Database'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingData = true);
    try {
      await _firestoreService.clearAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('All test data removed from database!'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear data: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingData = false);
    }
  }

  void _showDatabaseManagerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storage_rounded,
                        color: AppTheme.accentCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database & Demo Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Firestore: devices/device_001',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: AppTheme.accentCyan, size: 22),
                ),
                title: const Text(
                  'Populate Dummy Data',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Adds sample sensor readings, 3 schedules, and 20 history events with chart data',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _seedDummyData();
                },
              ),
              const Divider(color: Colors.white12, height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppTheme.errorRed, size: 22),
                ),
                title: const Text(
                  'Clear All Data',
                  style: TextStyle(
                      color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Wipes test sensor readings, schedules, history, and commands for clean hardware testing',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _clearAllData();
                },
              ),
            ],
          ),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.water_drop,
                  color: AppTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'AquaFeed',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isProcessingData
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentCyan,
                    ),
                  )
                : const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Database & Demo Controls',
            onPressed: _isProcessingData ? null : _showDatabaseManagerSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<SensorReading?>(
        stream: _firestoreService.streamLatestSensorReading(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: AppTheme.errorRed),
                    const SizedBox(height: 12),
                    const Text(
                      'Error connecting to Firestore',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            );
          }

          final reading = snapshot.data;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge row
                _buildStatusBadges(reading),
                const SizedBox(height: 16),

                // If no reading in database, show a prominent dummy data callout
                if (reading == null) _buildEmptyStateBanner(),

                // Sensor reading cards grid
                _buildSensorGrid(reading),
                const SizedBox(height: 24),

                // Feeding control section
                _buildFeedingControls(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryTeal.withValues(alpha: 0.25),
            AppTheme.cardDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science,
                    color: AppTheme.accentCyan, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Empty Database / No Live Data',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Load sample sensor values, feeding schedules, and history chart to preview the complete app. You can clear it anytime.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessingData ? null : _seedDummyData,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Add Dummy Data',
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isProcessingData ? null : _clearAllData,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.white54),
                label: const Text('Clear DB',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadges(SensorReading? reading) {
    return Row(
      children: [
        // Live / Offline indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: reading != null
                ? AppTheme.successGreen.withValues(alpha: 0.15)
                : AppTheme.errorRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: reading != null
                  ? AppTheme.successGreen.withValues(alpha: 0.4)
                  : AppTheme.errorRed.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reading != null
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  boxShadow: reading != null
                      ? [
                          BoxShadow(
                            color: AppTheme.successGreen.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                reading != null ? 'LIVE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: reading != null
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Solar / Battery badge
        if (reading != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: reading.solarCharging
                  ? AppTheme.warningAmber.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: reading.solarCharging
                    ? AppTheme.warningAmber.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reading.solarCharging
                      ? Icons.solar_power
                      : Icons.battery_charging_full,
                  size: 14,
                  color: reading.solarCharging
                      ? AppTheme.warningAmber
                      : Colors.white54,
                ),
                const SizedBox(width: 5),
                Text(
                  reading.solarCharging ? 'SOLAR ACTIVE' : 'BATTERY ONLY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: reading.solarCharging
                        ? AppTheme.warningAmber
                        : Colors.white60,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        if (reading != null)
          Text(
            _formatTimestamp(reading.timestamp),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildSensorGrid(SensorReading? reading) {
    final items = [
      _SensorCardData(
        icon: Icons.thermostat_rounded,
        label: 'Temperature',
        value: reading != null ? reading.temperature.toStringAsFixed(1) : '--',
        unit: '°C',
        color: const Color(0xFFFF7043),
        status: reading != null
            ? (reading.temperature >= 24 && reading.temperature <= 29
                ? 'Optimal'
                : 'Check')
            : null,
      ),
      _SensorCardData(
        icon: Icons.science_rounded,
        label: 'pH Level',
        value: reading != null ? reading.ph.toStringAsFixed(1) : '--',
        unit: 'pH',
        color: const Color(0xFF66BB6A),
        status: reading != null
            ? (reading.ph >= 6.8 && reading.ph <= 8.0 ? 'Optimal' : 'Check')
            : null,
      ),
      _SensorCardData(
        icon: Icons.water_rounded,
        label: 'Turbidity',
        value: reading != null ? reading.turbidity.toStringAsFixed(1) : '--',
        unit: 'NTU',
        color: const Color(0xFF42A5F5),
        status: reading != null
            ? (reading.turbidity < 25 ? 'Clear' : 'Murky')
            : null,
      ),
      _SensorCardData(
        icon: Icons.opacity_rounded,
        label: 'TDS Level',
        value: reading != null ? reading.tds.toStringAsFixed(0) : '--',
        unit: 'ppm',
        color: const Color(0xFFAB47BC),
        status: reading != null
            ? (reading.tds < 500 ? 'Good' : 'High')
            : null,
      ),
      _SensorCardData(
        icon: Icons.scale_rounded,
        label: 'Feed Weight',
        value: reading != null ? reading.feedWeight.toStringAsFixed(0) : '--',
        unit: 'g',
        color: const Color(0xFFFFCA28),
        status: reading != null
            ? (reading.feedWeight > 500 ? 'Ample' : 'Low Feed')
            : null,
      ),
      _SensorCardData(
        icon: Icons.battery_charging_full_rounded,
        label: 'Battery',
        value: reading != null ? '${reading.batteryPercent}' : '--',
        unit: '%',
        color: _getBatteryColor(reading?.batteryPercent),
        status: reading != null
            ? (reading.batteryPercent > 20 ? 'Healthy' : 'Low')
            : null,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.26, // Expanded vertical ratio to completely eliminate overflow
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildSensorCard(items[index]),
    );
  }

  Widget _buildSensorCard(_SensorCardData data) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardDark,
            Color.lerp(AppTheme.cardDark, data.color, 0.12)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: data.color.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: Icon + Unit badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: data.color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  data.unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: data.color,
                  ),
                ),
              ),
            ],
          ),

          // Middle & Bottom: Value + Label with safety scaling
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (data.status != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      data.status!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: data.color.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Feeding Control',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            if (_isSendingCommand)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentCyan,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCommandButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start Feeding',
                color: AppTheme.successGreen,
                onPressed: _isSendingCommand
                    ? null
                    : () => _sendCommand('start_feeding'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCommandButton(
                icon: Icons.stop_rounded,
                label: 'Stop Feeding',
                color: AppTheme.errorRed,
                onPressed: _isSendingCommand
                    ? null
                    : () => _sendCommand('stop_feeding'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommandButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBatteryColor(int? percent) {
    if (percent == null) return Colors.white38;
    if (percent > 60) return AppTheme.successGreen;
    if (percent > 25) return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SensorCardData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? status;

  const _SensorCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.status,
  });
}
