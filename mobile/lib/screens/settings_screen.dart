import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/intervals_service.dart';
import 'activities_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _intervalsService = IntervalsService();
  final _apiKeyController = TextEditingController();
  final _athleteIdController = TextEditingController();

  bool _isLoading = false;
  bool _isConnected = false;
  String? _athleteName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final hasKey = await _intervalsService.hasApiKey();
    if (hasKey) {
      final athlete = await _intervalsService.validateAndGetAthlete();
      if (athlete != null && mounted) {
        setState(() {
          _isConnected = true;
          _athleteName = athlete['name'] ?? 'Connected';
        });
      }
    }
  }

  Future<void> _connect() async {
    final apiKey = _apiKeyController.text.trim();
    final athleteId = _athleteIdController.text.trim();

    if (apiKey.isEmpty) {
      setState(() => _error = 'Please enter your API key');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Save temporarily to test connection
    await _intervalsService.saveApiKey(
      apiKey,
      athleteId.isEmpty ? 'i0' : athleteId,
    );

    final athlete = await _intervalsService.validateAndGetAthlete();

    if (mounted) {
      if (athlete != null) {
        setState(() {
          _isLoading = false;
          _isConnected = true;
          _athleteName = athlete['name'] ?? 'Connected';
        });

        // Navigate to activities
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
          );
        }
      } else {
        await _intervalsService.clearApiKey();
        setState(() {
          _isLoading = false;
          _error = 'Invalid API key or athlete ID';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _intervalsService.clearApiKey();
    setState(() {
      _isConnected = false;
      _athleteName = null;
      _apiKeyController.clear();
      _athleteIdController.clear();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _athleteIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intervals.icu Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('📊', style: TextStyle(fontSize: 24)),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _isConnected
                                ? 'Connected as $_athleteName'
                                : 'Connect to import workouts',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _isConnected
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isConnected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF22C55E),
                        size: 28,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (!_isConnected) ...[
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📝 How to get your API key:',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Go to intervals.icu\n'
                        '2. Settings → Developer Settings\n'
                        '3. Copy your API key',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[400],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // API Key input
                Text(
                  'API Key',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Paste your API key here',
                    filled: true,
                    fillColor: const Color(0xFF27272A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.key, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 16),

                // Athlete ID input (optional)
                Text(
                  'Athlete ID (optional)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _athleteIdController,
                  decoration: InputDecoration(
                    hintText: 'Leave empty to use your account',
                    filled: true,
                    fillColor: const Color(0xFF27272A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Connect button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _connect,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Connect'),
                  ),
                ),
              ] else ...[
                // Connected state - show activities button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivitiesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('View Activities'),
                  ),
                ),

                const SizedBox(height: 16),

                // Disconnect button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _disconnect,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Support the Developer section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEAB308).withValues(alpha: 0.15),
                      const Color(0xFFEC4899).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text('☕', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'Support the Developer',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you find this app useful, consider buying me a coffee!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://paypal.me/bahole');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.favorite,
                          color: Color(0xFFEC4899),
                        ),
                        label: const Text('Buy Me a Coffee'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // App info
              Center(
                child: Text(
                  'Workout Analyzer v1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
