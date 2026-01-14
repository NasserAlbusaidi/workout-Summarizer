import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/workout.dart';
import '../parsers/fit_parser.dart';
import '../parsers/form_csv_parser.dart';

/// State for the workout analysis
class WorkoutState {
  final bool isLoading;
  final WorkoutAnalysis? analysis;
  final String? error;
  final String? selectedFileName;

  const WorkoutState({
    this.isLoading = false,
    this.analysis,
    this.error,
    this.selectedFileName,
  });

  WorkoutState copyWith({
    bool? isLoading,
    WorkoutAnalysis? analysis,
    String? error,
    String? selectedFileName,
    bool clearAnalysis = false,
    bool clearError = false,
  }) {
    return WorkoutState(
      isLoading: isLoading ?? this.isLoading,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      error: clearError ? null : (error ?? this.error),
      selectedFileName: selectedFileName ?? this.selectedFileName,
    );
  }
}

/// Notifier for managing workout state
class WorkoutNotifier extends StateNotifier<WorkoutState> {
  final FitParser _fitParser = FitParser();
  final FormCsvParser _csvParser = FormCsvParser();

  WorkoutNotifier() : super(const WorkoutState());

  /// Pick and analyze a file
  Future<void> pickAndAnalyze() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Use FileType.any because Android doesn't recognize .fit extension
      // We'll filter by extension after selection
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      final lowerName = fileName.toLowerCase();

      // Validate file extension
      if (!lowerName.endsWith('.fit') && !lowerName.endsWith('.csv')) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please select a .fit or .csv file',
        );
        return;
      }

      state = state.copyWith(selectedFileName: fileName);

      WorkoutAnalysis? analysis;

      if (lowerName.endsWith('.csv')) {
        // FORM CSV
        final content = await _readFileContent(file);
        if (content != null) {
          analysis = _csvParser.parseString(content);
        }
      } else if (lowerName.endsWith('.fit')) {
        // FIT file
        final bytes = await _readFileBytes(file);
        if (bytes != null) {
          analysis = await _fitParser.parseBytes(bytes);
        }
      }

      if (analysis != null) {
        state = state.copyWith(isLoading: false, analysis: analysis);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to parse file. Please check the format.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error: ${e.toString()}');
    }
  }

  Future<String?> _readFileContent(PlatformFile file) async {
    try {
      if (file.bytes != null) {
        return String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        return await File(file.path!).readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<int>?> _readFileBytes(PlatformFile file) async {
    try {
      if (file.bytes != null) {
        return file.bytes!;
      } else if (file.path != null) {
        return await File(file.path!).readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void clearAnalysis() {
    state = state.copyWith(
      clearAnalysis: true,
      clearError: true,
      selectedFileName: null,
    );
  }
}

/// Provider for workout state
final workoutProvider = StateNotifierProvider<WorkoutNotifier, WorkoutState>((
  ref,
) {
  return WorkoutNotifier();
});
