import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/intervals_service.dart';
import '../parsers/fit_parser.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final _intervalsService = IntervalsService();
  final _fitParser = FitParser();

  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _error;
  String? _loadingActivityId;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final activities = await _intervalsService.getActivities(count: 20);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _activities = activities;
        if (activities.isEmpty) {
          _error = 'No activities found';
        }
      });
    }
  }

  Future<void> _analyzeActivity(Map<String, dynamic> activity) async {
    final activityId = activity['id']?.toString();
    if (activityId == null) return;

    setState(() => _loadingActivityId = activityId);

    final fitBytes = await _intervalsService.downloadFitFile(activityId);

    if (fitBytes != null) {
      final analysis = await _fitParser.parseBytes(fitBytes);

      if (analysis != null && mounted) {
        setState(() => _loadingActivityId = null);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnalysisScreen(analysis: analysis)),
        );
      } else if (mounted) {
        setState(() => _loadingActivityId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to parse activity')),
        );
      }
    } else if (mounted) {
      setState(() => _loadingActivityId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download FIT file')),
      );
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '--:--';
    final sec = seconds is int ? seconds : (seconds as num).toInt();
    final mins = sec ~/ 60;
    final secs = sec % 60;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remainingMins = mins % 60;
      return '$hours:${remainingMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(dynamic meters) {
    if (meters == null) return '--';
    final m = meters is int ? meters.toDouble() : (meters as num).toDouble();
    if (m >= 1000) {
      return '${(m / 1000).toStringAsFixed(2)} km';
    }
    return '${m.round()} m';
  }

  String _getSportEmoji(String? sport) {
    return switch (sport?.toLowerCase()) {
      'swim' || 'swimming' => '🏊',
      'run' || 'running' => '🏃',
      'ride' || 'cycling' => '🚴',
      'walk' || 'walking' => '🚶',
      _ => '🏋️',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Intervals.icu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadActivities,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadActivities,
                color: const Color(0xFF00D4FF),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return _ActivityCard(
                      activity: activity,
                      isLoading:
                          _loadingActivityId == activity['id']?.toString(),
                      onTap: () => _analyzeActivity(activity),
                      formatDuration: _formatDuration,
                      formatDistance: _formatDistance,
                      getSportEmoji: _getSportEmoji,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isLoading;
  final VoidCallback onTap;
  final String Function(dynamic) formatDuration;
  final String Function(dynamic) formatDistance;
  final String Function(String?) getSportEmoji;

  const _ActivityCard({
    required this.activity,
    required this.isLoading,
    required this.onTap,
    required this.formatDuration,
    required this.formatDistance,
    required this.getSportEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final name = activity['name'] ?? 'Workout';
    final sport = activity['type'] as String?;
    final startDate = activity['start_date_local'] as String?;
    final movingTime = activity['moving_time'];
    final distance = activity['distance'];

    // Parse date
    String dateStr = 'Unknown date';
    if (startDate != null) {
      try {
        final date = DateTime.parse(startDate);
        dateStr =
            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = startDate;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sport emoji
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    getSportEmoji(sport),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.timer,
                          label: formatDuration(movingTime),
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.straighten,
                          label: formatDistance(distance),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Loading indicator or arrow
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00D4FF),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3F3F46),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }
}
