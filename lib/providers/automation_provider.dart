import 'package:flutter/material.dart';
import 'dart:async';
import '../models/automation_rule.dart';
import '../models/solar_data.dart';
import '../models/smart_device.dart';
import '../services/automation_service.dart';

class AutomationProvider extends ChangeNotifier {
  final AutomationService _automationService = AutomationService();

  List<AutomationRule> _rules = [];
  bool _isAutomationEnabled = true;
  bool _isLoading = false;
  String? _error;
  Timer? _automationTimer;

  List<AutomationRule> get rules => _rules;
  bool get isAutomationEnabled => _isAutomationEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AutomationProvider() {
    _loadRules();
    _startAutomationEngine();
  }

  Future<void> _loadRules() async {
    try {
      _setLoading(true);
      _setError(null);

      final rules = await _automationService.getRules();
      _rules = rules;
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar reglas de automatización: $e');
      _setLoading(false);
    }
  }

  void _startAutomationEngine() {
    _automationTimer?.cancel();
    _automationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isAutomationEnabled) {
        _evaluateRules();
      }
    });
  }

  Future<void> _evaluateRules() async {
    if (!_isAutomationEnabled) return;

    for (final rule in _rules.where((r) => r.isEnabled)) {
      try {
        final shouldTrigger = await _automationService.evaluateRule(rule);
        if (shouldTrigger) {
          await _automationService.executeRule(rule);
          
          // Actualizar estadísticas de la regla
          final updatedRule = rule.copyWith(
            lastTriggered: DateTime.now(),
            timesTriggered: rule.timesTriggered + 1,
          );
          
          final ruleIndex = _rules.indexWhere((r) => r.id == rule.id);
          if (ruleIndex != -1) {
            _rules[ruleIndex] = updatedRule;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error evaluating rule ${rule.name}: $e');
      }
    }
  }

  Future<bool> addRule(AutomationRule rule) async {
    try {
      final success = await _automationService.saveRule(rule);
      if (success) {
        _rules.add(rule);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding rule: $e');
      return false;
    }
  }

  Future<bool> updateRule(AutomationRule rule) async {
    try {
      final success = await _automationService.saveRule(rule);
      if (success) {
        final ruleIndex = _rules.indexWhere((r) => r.id == rule.id);
        if (ruleIndex != -1) {
          _rules[ruleIndex] = rule;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error updating rule: $e');
      return false;
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    try {
      final success = await _automationService.deleteRule(ruleId);
      if (success) {
        _rules.removeWhere((r) => r.id == ruleId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting rule: $e');
      return false;
    }
  }

  Future<bool> toggleRule(String ruleId) async {
    final ruleIndex = _rules.indexWhere((r) => r.id == ruleId);
    if (ruleIndex == -1) return false;

    final rule = _rules[ruleIndex];
    final updatedRule = rule.copyWith(isEnabled: !rule.isEnabled);
    
    return await updateRule(updatedRule);
  }

  void toggleAutomation() {
    _isAutomationEnabled = !_isAutomationEnabled;
    notifyListeners();
  }

  List<AutomationRule> get enabledRules {
    return _rules.where((rule) => rule.isEnabled).toList();
  }

  List<AutomationRule> get excessEnergyRules {
    return _rules.where((rule) => 
      rule.conditions.any((c) => c.trigger == AutomationTrigger.excessEnergy)
    ).toList();
  }

  int get totalTriggersToday {
    final today = DateTime.now();
    return _rules.fold(0, (sum, rule) {
      if (rule.lastTriggered.day == today.day &&
          rule.lastTriggered.month == today.month &&
          rule.lastTriggered.year == today.year) {
        return sum + 1;
      }
      return sum;
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _automationTimer?.cancel();
    super.dispose();
  }
}
