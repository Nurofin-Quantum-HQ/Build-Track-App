import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'help_knowledge_base.dart';

class HelpLanguage {
  final String code;
  final String label;
  final String name;
  final String nativeName;
  final String greeting;
  final String placeholder;
  final String subtitle;

  const HelpLanguage({
    required this.code,
    required this.label,
    required this.name,
    required this.nativeName,
    required this.greeting,
    required this.placeholder,
    required this.subtitle,
  });
}

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
  static const String _langStorageKey = 'bt_help_lang_v1';

  static const List<HelpLanguage> supportedLanguages = [
    HelpLanguage(
      code: 'en',
      label: 'EN',
      name: 'English',
      nativeName: 'English',
      greeting:
          'Hello! I am your BuildTrack Assistant. How can I help you today? Choose any feature below or type your question in English or regional words to get instant step-by-step guidance.',
      placeholder: "Ask anything (e.g. 'how to upload csv', 'project heg add madodu')...",
      subtitle: 'Step-by-step help for all features',
    ),
    HelpLanguage(
      code: 'kn',
      label: 'KN',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      greeting:
          'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ BuildTrack ಸಹಾಯಕ. ನಿಮಗೆ ಇಂದು ನಾನು ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ? ಕೆಳಗಿನ ಆಯ್ಕೆಗಳನ್ನು ನೋಡಿ ಅಥವಾ ನಿಮ್ಮ ಪ್ರಶ್ನೆಯನ್ನು (ಕನ್ನಡದಲ್ಲಿ ಅಥವಾ ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ) ಟೈಪ್ ಮಾಡಿ.',
      placeholder: "ಏನಾದರೂ ಕೇಳಿ (ಉದಾ: 'ಹೊಸ ಪ್ರಾಜೆಕ್ಟ್', 'project heg add madodu', 'CSV')...",
      subtitle: 'ಎಲ್ಲಾ ಫೀಚರ್‌ಗಳ ಹಂತ-ಹಂತದ ಗೈಡ್',
    ),
    HelpLanguage(
      code: 'hi',
      label: 'HI',
      name: 'Hindi',
      nativeName: 'हिंदी',
      greeting:
          'नमस्ते! मैं आपका BuildTrack सहायक हूँ। आज मैं आपकी क्या सहायता कर सकता हूँ? नीचे दिए गए विकल्पों को चुनें या अपना प्रश्न टाइप करें।',
      placeholder: "कुछ भी पूछें (उदा: 'नया प्रोजेक्ट कैसे जोड़ें', 'bill kaise dale', 'CSV')...",
      subtitle: 'सभी सुविधाओं के लिए चरण-दर-चरण गाइड',
    ),
    HelpLanguage(
      code: 'te',
      label: 'TE',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      greeting:
          'నమస్కారం! నేను మీ BuildTrack సహాయకుడిని. ఈరోజు నేను మీకు ఎలా సహాయపడగలను? క్రింది ఫీచర్లలో ఒకదాన్ని ఎంచుకోండి లేదా మీ ప్రశ్నను టైప్ చేయండి.',
      placeholder: "ఏదైనా అడగండి (ఉదా: 'కొత్త ప్రాజెక్ట్', 'project ela add cheyali', 'CSV')...",
      subtitle: 'అన్ని ఫీచర్లకు స్టెప్-బై-స్టెప్ గైడ్',
    ),
    HelpLanguage(
      code: 'ta',
      label: 'TA',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      greeting:
          'வணக்கம்! நான் உங்கள் BuildTrack உதவியாளர். இன்று உங்களுக்கு நான் எவ்வாறு உதವ முடியும்? கீழே உள்ள ஏதேனும் ஒரு அம்சத்தைத் தேர்வு செய்யவும் அல்லது தட்டச்சு செய்யவும்.',
      placeholder: "ஏதேனும் கேளுங்கள் (उदा: 'புதிய திட்டம்', 'project eppadi add panrathu')...",
      subtitle: 'அனைத்து அம்சங்களுக்கான படிப்படியான வழிகாட்டி',
    ),
    HelpLanguage(
      code: 'ml',
      label: 'ML',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      greeting:
          'നമസ്കാരം! ഞാൻ നിങ്ങളുടെ BuildTrack സഹായിയാണ്. ഇന്ന് ഞാൻ നിങ്ങളെ എങ്ങനെ സഹായിക്കണം? താഴെ പറയുന്നവയിൽ നിന്ന് തിരഞ്ഞെടുക്കുക അല്ലെങ്കിൽ ചോദ്യം ചോദിക്കുക.',
      placeholder: "എന്തും ചോദിക്കാം (ഉദാ: 'പുതിയ പ്രോജക്റ്റ്', 'project engane add cheyyam')...",
      subtitle: 'എല്ലാ ഫീച്ചറുകൾക്കുമുള്ള ഘട്ടം ഘട്ടമായുള്ള ഗൈഡ്',
    ),
  ];

  static HelpLanguage getLanguage(String code) {
    return supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );
  }

  static HelpMessage _makeInitialGreeting(String langCode) {
    final lang = getLanguage(langCode);
    return HelpMessage(
      id: 'msg_init',
      sender: 'bot',
      text: lang.greeting,
      timestamp: DateTime.now(),
    );
  }

  final List<HelpMessage> _messages = [_makeInitialGreeting('en')];
  String _selectedCategory = 'all';
  String _selectedLanguage = 'en';
  bool _isInitialized = false;

  List<HelpMessage> get messages => List.unmodifiable(_messages);
  String get selectedCategory => _selectedCategory;
  String get selectedLanguage => _selectedLanguage;
  bool get isInitialized => _isInitialized;

  HelpLanguage get currentLanguageObj => getLanguage(_selectedLanguage);

  HelpAssistantProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedLanguage = prefs.getString(_langStorageKey) ?? 'en';

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
    _messages.add(_makeInitialGreeting(_selectedLanguage));
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langStorageKey, _selectedLanguage);
      final data = {
        'selectedCategory': _selectedCategory,
        'selectedLanguage': _selectedLanguage,
        'messages': _messages.map((m) => m.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[HelpAssistant] Error saving help session: $e');
    }
  }

  static String getLocalizedGuidePrefix(String lang, String topicTitle) {
    switch (lang) {
      case 'kn':
        return '"$topicTitle" ಗೆ ಹಂತ-ಹಂತದ ಗೈಡ್ ಇಲ್ಲಿದೆ:';
      case 'hi':
        return '"$topicTitle" के लिए चरण-दर-चरण गाइड यहाँ है:';
      case 'te':
        return '"$topicTitle" కోసం స్టెప్-బై-స్టెప్ గైడ్ ఇదిగో:';
      case 'ta':
        return '"$topicTitle"-க்கான படிப்படியான வழிகாட்டி இதோ:';
      case 'ml':
        return '"$topicTitle" നുള്ള ഘട്ടം ഘട്ടമായുള്ള ഗൈഡ് ഇതാ:';
      default:
        return 'Here is the complete step-by-step guide for "$topicTitle":';
    }
  }

  static String getLocalizedFallback(String lang, String clean) {
    switch (lang) {
      case 'kn':
        return '"$clean" ಗೆ ಸಂಬಂಧಿಸಿದ ನಿಖರ ಮಾಹಿತಿ ಸಿಗಲಿಲ್ಲ. ಕೆಳಗಿನ ಆಯ್ಕೆಗಳನ್ನು ಆರಿಸಿ ಅಥವಾ "ಪ್ರಾಜೆಕ್ಟ್", "ಖರ್ಚು", "ಕೂಲಿ", "CSV", "ರೆವಿನ್ಯೂ" ಎಂದು ಹುಡುಕಿ.';
      case 'hi':
        return '"$clean" के लिए कोई सटीक परिणाम नहीं मिला। कृपया नीचे दी गई श्रेणियों में देखें या "प्रोजेक्ट", "सामग्री", "मजदूरी", "CSV" लिखकर खोजें।';
      case 'te':
        return '"$clean" కోసం ఖచ్చితమైన సమాచారం దొరకలేదు. దయచేసి క్రింది కేటగిరీలను చూడండి లేదా "ప్రాజెక్ట్", "ఖర్చు", "కూలీ", "CSV" అని సెర్చ్ చేయండి.';
      case 'ta':
        return '"$clean"-க்கு பொருத்தமான தகவல்கள் கிடைக்கவில்லை. கீழே உள்ள வகைகளைப் பார்க்கவும் அல்லது "திட்டம்", "செலவு", "கூலி", "CSV" எனத் தேடவும்.';
      case 'ml':
        return '"$clean" ന് കൃത്യമായ ഫലം കണ്ടെത്താനായില്ല. ദയവായി താഴെയുള്ള കാറ്റഗറികൾ പരിശോധിക്കുക അല്ലെങ്കിൽ "പ്രോജക്റ്റ്", "ചെലവ്", "കൂലി", "CSV" എന്ന് തിരയുക.';
      default:
        return 'I could not find an exact match for "$clean". Try browsing categories above or searching keywords like "project", "csv", "material", "labour", "revenue", or "reports".';
    }
  }

  static String getLocalizedSwitchedNotice(String lang, String nativeName) {
    switch (lang) {
      case 'kn':
        return 'ಭಾಷೆಯನ್ನು $nativeName ಗೆ ಬದಲಾಯಿಸಲಾಗಿದೆ. ಎಲ್ಲಾ ಹಂತಗಳು ಕನ್ನಡದಲ್ಲಿ ಲಭ್ಯವಿದೆ!';
      case 'hi':
        return 'भाषा बदलकर $nativeName कर दी गई है। सभी चरण हिंदी में उपलब्ध हैं!';
      case 'te':
        return 'భాష $nativeName కు మార్చబడింది. అన్ని దశలు తెలుగులో అందుబాటులో ఉన్నాయి!';
      case 'ta':
        return 'மொழி $nativeName-க்கு மாற்றப்பட்டது. அனைத்து படிகளும் தமிழில் கிடைக்கின்றன!';
      case 'ml':
        return 'ഭാഷ $nativeName-ലേക്ക് മാറ്റി. എല്ലാ ഘട്ടങ്ങളും മലയാളത്തിൽ ലഭ്യമാണ്!';
      default:
        return 'Language switched to $nativeName. You can ask in English, native script, or regional words!';
    }
  }

  void setLanguage(String code) {
    if (_selectedLanguage == code) return;
    _selectedLanguage = code;
    final langObj = currentLanguageObj;

    // Immediately re-localize any open topic messages so the user sees steps in the new language
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.topic != null) {
        final loc = HelpKnowledgeBase.getLocalizedTopic(m.topic!, code);
        final locRelated = m.relatedTopics
            ?.map((t) => HelpKnowledgeBase.getLocalizedTopic(t, code))
            .toList();
        _messages[i] = HelpMessage(
          id: m.id,
          sender: m.sender,
          text: getLocalizedGuidePrefix(code, loc.title),
          topic: loc,
          relatedTopics: locRelated,
          timestamp: m.timestamp,
        );
      }
    }

    if (_messages.length <= 1 && _messages.first.id == 'msg_init') {
      _messages[0] = HelpMessage(
        id: 'msg_init',
        sender: 'bot',
        text: langObj.greeting,
        timestamp: DateTime.now(),
      );
    } else {
      _messages.add(HelpMessage(
        id: 'msg_lang_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'bot',
        text: getLocalizedSwitchedNotice(code, langObj.nativeName),
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
    _saveToPrefs();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
    _saveToPrefs();
  }

  void selectTopic(HelpTopic topic) {
    final localized = HelpKnowledgeBase.getLocalizedTopic(topic, _selectedLanguage);
    final now = DateTime.now();
    final userMsg = HelpMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      sender: 'user',
      text: localized.title,
      timestamp: now,
    );

    final botMsg = HelpMessage(
      id: 'bot_${now.millisecondsSinceEpoch + 1}',
      sender: 'bot',
      text: getLocalizedGuidePrefix(_selectedLanguage, localized.title),
      topic: localized,
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

    final lower = clean.toLowerCase();
    if (lower == 'reset' ||
        lower == 'new chat' ||
        lower == 'clear' ||
        lower == 'clear chat' ||
        lower == 'restart' ||
        lower == 'restart chat') {
      resetChat();
      return;
    }

    final now = DateTime.now();
    final userMsg = HelpMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      sender: 'user',
      text: clean,
      timestamp: now,
    );

    final results = HelpKnowledgeBase.search(clean,
        category: _selectedCategory, langCode: _selectedLanguage);

    HelpMessage botMsg;
    if (results.isNotEmpty) {
      final best = HelpKnowledgeBase.getLocalizedTopic(results.first, _selectedLanguage);
      final related = results.length > 1
          ? results
              .sublist(1, results.length > 4 ? 4 : results.length)
              .map((t) => HelpKnowledgeBase.getLocalizedTopic(t, _selectedLanguage))
              .toList()
          : null;

      botMsg = HelpMessage(
        id: 'bot_${now.millisecondsSinceEpoch + 1}',
        sender: 'bot',
        text: getLocalizedGuidePrefix(_selectedLanguage, best.title),
        topic: best,
        relatedTopics: related,
        timestamp: now.add(const Duration(milliseconds: 1)),
      );
    } else {
      botMsg = HelpMessage(
        id: 'bot_${now.millisecondsSinceEpoch + 1}',
        sender: 'bot',
        text: getLocalizedFallback(_selectedLanguage, clean),
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
      text: currentLanguageObj.greeting,
      timestamp: DateTime.now(),
    ));
    _selectedCategory = 'all';
    notifyListeners();
    _saveToPrefs();
  }
}
