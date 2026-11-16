import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'help_knowledge_base.dart';

class HelpMessage {
  final String id;
  final String sender; // 'bot' or 'user'
  final String text;
  final HelpTopic? topic;
  final List<HelpTopic>? relatedTopics;
  final DateTime timestamp;

  HelpMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.topic,
    this.relatedTopics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'topic': topic?.toJson(),
        'relatedTopics': relatedTopics?.map((t) => t.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };

  factory HelpMessage.fromJson(Map<String, dynamic> json) => HelpMessage(
        id: json['id'] as String,
        sender: json['sender'] as String,
        text: json['text'] as String,
        topic: json['topic'] != null
            ? HelpTopic.fromJson(json['topic'] as Map<String, dynamic>)
            : null,
        relatedTopics: json['relatedTopics'] != null
            ? (json['relatedTopics'] as List)
                .map((t) => HelpTopic.fromJson(t as Map<String, dynamic>))
                .toList()
            : null,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

class HelpAssistantProvider extends ChangeNotifier {
  static const String _storageKey = 'bt_help_chat_history_v1';

  static HelpMessage get _initialGreeting => HelpMessage(
        id: 'msg_init',
        sender: 'bot',
        text:
            'Hello! I am your BuildTrack Assistant. How can I help you today? Choose any feature below or type your question to get instant step-by-step guidance.',
        timestamp: DateTime.now(),
      );

  final List<HelpMessage> _messages = [_initialGreeting];
  String _selectedCategory = 'all';
  bool _isInitialized = false;

  List<HelpMessage> get messages => List.unmodifiable(_messages);
  String get selectedCategory => _selectedCategory;
  bool get isInitialized => _isInitialized;

  HelpAssistantProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final list = decoded['messages'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          _messages.clear();
          for (final item in list) {
            _messages.add(HelpMessage.fromJson(item as Map<String, dynamic>));
          }
          _selectedCategory = decoded['selectedCategory'] as String? ?? 'all';
          _isInitialized = true;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[HelpAssistant] Error loading stored help session: $e');
    }

    _messages.clear();
    _messages.add(_initialGreeting);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'selectedCategory': _selectedCategory,
        'messages': _messages.map((m) => m.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[HelpAssistant] Error saving help session: $e');
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void selectTopic(HelpTopic topic) {
    final now = DateTime.now();
    final userMsg = HelpMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      sender: 'user',
      text: topic.title,
      timestamp: now,
    );

    final botMsg = HelpMessage(
      id: 'bot_${now.millisecondsSinceEpoch + 1}',
      sender: 'bot',
      text: 'Here is the step-by-step guide for ${topic.title}:',
      topic: topic,
      timestamp: now.add(const Duration(milliseconds: 1)),
    );

    _messages.add(userMsg);
    _messages.add(botMsg);
    notifyListeners();
    _saveToPrefs();
  }

  void askQuestion(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final now = DateTime.now();
    final userMsg = HelpMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      sender: 'user',
      text: clean,
      timestamp: now,
    );

    final results = HelpKnowledgeBase.search(clean, category: _selectedCategory);

    HelpMessage botMsg;
    if (results.isNotEmpty) {
      final best = results.first;
      final related = results.length > 1 ? results.sublist(1, results.length > 4 ? 4 : results.length) : null;

      botMsg = HelpMessage(
        id: 'bot_${now.millisecondsSinceEpoch + 1}',
        sender: 'bot',
        text: 'Here is how to do ${best.title}:',
        topic: best,
        relatedTopics: related,
        timestamp: now.add(const Duration(milliseconds: 1)),
      );
    } else {
      botMsg = HelpMessage(
        id: 'bot_${now.millisecondsSinceEpoch + 1}',
        sender: 'bot',
        text:
            'I could not find an exact match for "$clean". Try browsing categories above or searching keywords like "project", "csv", "material", "labour", "revenue", or "reports".',
        timestamp: now.add(const Duration(milliseconds: 1)),
      );
    }

    _messages.add(userMsg);
    _messages.add(botMsg);
    notifyListeners();
    _saveToPrefs();
  }

  void resetChat() {
    _messages.clear();
    _messages.add(HelpMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'bot',
      text:
          'Conversation reset. How can I help you today? Choose any feature below or type your question.',
      timestamp: DateTime.now(),
    ));
    _selectedCategory = 'all';
    notifyListeners();
    _saveToPrefs();
  }
}
