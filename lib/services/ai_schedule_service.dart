import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/task_model.dart';
import '../models/schedule_analysis.dart';

class AiScheduleService extends ChangeNotifier {
  ScheduleAnalysis? _currentAnalysis;
  bool _isLoading = false;
  String? _errorMessage;


  final String _apiKey = '';

  ScheduleAnalysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> analyzeSchedule(List<TaskModel> tasks) async {
    if (_apiKey.isEmpty || tasks.isEmpty) {
      if (_apiKey.isEmpty) _errorMessage = 'API Key is missing';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final taskJson = jsonEncode(tasks.map((e) => e.toJson()).toList());

      final prompt = '''
You are an expert student scheduling assistant. The user has provided the following tasks in JSON format:

$taskJson

Please provide exactly 4 sections of markdown text:
1. ### Detected conflicts
List any scheduling conflicts or state that there are none.
2. ### Ranked Tasks
Ranks which tasks need attention first.
3. ### Recommended Schedule 
Provide a revised daily timeline view adjusting the task times.
4. ### Explanation 
Explain why this recommendation was made.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null) {
        _currentAnalysis = _parseResponse(response.text!);
      } else {
        _errorMessage = 'AI returned an empty response.';
      }
    } catch (e) {
      _errorMessage = 'Failed to analyze: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

ScheduleAnalysis _parseResponse(String fullText) {
  String conflicts = '';
  String rankedTasks = '';
  String recommendedSchedule = '';
  String explanation = '';

  final sections = fullText.split('###');
  for (var section in sections) {
    final trimmedSection = section.trim();
    if (trimmedSection.startsWith('Detected conflicts')) {
      conflicts = trimmedSection.replaceFirst('Detected conflicts', '').trim();
    } else if (trimmedSection.startsWith('Ranked Tasks')) {
      rankedTasks = trimmedSection.replaceFirst('Ranked Tasks', '').trim();
    } else if (trimmedSection.startsWith('Recommended Schedule')) {
      recommendedSchedule = trimmedSection.replaceFirst('Recommended Schedule', '').trim();
    } else if (trimmedSection.startsWith('Explanation')) {
      explanation = trimmedSection.replaceFirst('Explanation', '').trim();
    }
  }

  return ScheduleAnalysis(
    conflicts: conflicts.isEmpty ? 'No conflicts detected.' : conflicts,
    rankedTasks: rankedTasks.isEmpty ? 'No ranking provided.' : rankedTasks,
    recommendedSchedule: recommendedSchedule.isEmpty ? 'No schedule generated.' : recommendedSchedule,
    explanation: explanation.isEmpty ? 'No explanation provided.' : explanation,
  );
}
