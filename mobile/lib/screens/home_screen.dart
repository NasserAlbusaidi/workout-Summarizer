import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/workout_provider.dart';
import '../services/intervals_service.dart';
import 'analysis_screen.dart';
import 'activities_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏃🚴🏊 '),
            Text(
              'Workout Analyzer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero section
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                ).createShader(bounds),
                child: Text(
                  'Analyze Your Workout',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a file or import from Intervals.icu',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // File picker card
              Card(
                child: InkWell(
                  onTap: state.isLoading
                      ? null
                      : () async {
                          await ref
                              .read(workoutProvider.notifier)
                              .pickAndAnalyze();

                          final newState = ref.read(workoutProvider);
                          if (newState.analysis != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnalysisScreen(
                                  analysis: newState.analysis!,
                                ),
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00D4FF,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: state.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF00D4FF),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.upload_file_rounded,
                                  size: 28,
                                  color: Color(0xFF00D4FF),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload File',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select .fit or .csv file',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Intervals.icu import button
              _IntervalsImportCard(),

              // Error message
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Features
              _FeatureRow(
                icon: Icons.cloud_off,
                title: 'Offline First',
                subtitle: 'Works without internet',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.speed,
                title: 'Instant Analysis',
                subtitle: 'All processing on-device',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.security,
                title: 'Privacy Focused',
                subtitle: 'Your data stays on your phone',
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF00D4FF)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntervalsImportCard extends StatefulWidget {
  @override
  State<_IntervalsImportCard> createState() => _IntervalsImportCardState();
}

class _IntervalsImportCardState extends State<_IntervalsImportCard> {
  final _intervalsService = IntervalsService();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final hasKey = await _intervalsService.hasApiKey();
    if (mounted) {
      setState(() => _isConnected = hasKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () async {
          if (_isConnected) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
          _checkConnection(); // Refresh on return
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('📊', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intervals.icu',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isConnected
                          ? 'View your activities'
                          : 'Connect to import workouts',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _isConnected
                            ? const Color(0xFF22C55E)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _isConnected ? Icons.chevron_right : Icons.link,
                color: _isConnected ? Colors.grey : const Color(0xFF3B82F6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
