import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/help_assistant/help_assistant_provider.dart';
import 'package:buildtrack_mobile/common/help_assistant/help_knowledge_base.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submitQuery(HelpAssistantProvider provider) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    provider.askQuestion(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HelpAssistantProvider>();
    final bt = context.bt;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12151D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: bt.signature,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.smart_toy_rounded, color: bt.onAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BuildTrack Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: bt.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: bt.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'HELP',
                        style: TextStyle(
                          color: bt.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Step-by-step help for all features',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            tooltip: 'Reset Conversation',
            onPressed: () => provider.resetChat(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Category Filters Carousel ──
            Container(
              height: 44,
              color: const Color(0xFF141720),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: HelpKnowledgeBase.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final cat = HelpKnowledgeBase.categories[idx];
                  final active = provider.selectedCategory == cat.id;
                  return InkWell(
                    onTap: () => provider.setCategory(cat.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? bt.accent : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active ? bt.accent : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          color: active ? bt.onAccent : Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(color: Color(0x1FFFFFFF), height: 1),

            // ── Chat Messages Scroll Area ──
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: provider.messages.length,
                itemBuilder: (context, idx) {
                  final msg = provider.messages[idx];
                  return _buildMessageItem(context, msg, provider, bt);
                },
              ),
            ),

            // ── Popular Topic Chips Carousel ──
            Container(
              color: const Color(0xFF10131A),
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _getVisibleTopics(provider).map((topic) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          provider.selectTopic(topic);
                          _scrollToBottom();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, color: bt.accent, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                topic.title,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Text Input Bar ──
            Container(
              color: const Color(0xFF10131A),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29), // Solid dark slate input container
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              focusNode: _focusNode,
                              cursorColor: bt.accent,
                              style: const TextStyle(
                                color: Colors.white, // Crisp, highly visible white text
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false, // Ensures it does NOT inherit white card fill from app theme
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                hintText: 'Ask anything (e.g. how to add project, csv)...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13,
                                ),
                              ),
                              onSubmitted: (_) => _submitQuery(provider),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bt.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send_rounded, color: bt.onAccent, size: 20),
                      onPressed: () => _submitQuery(provider),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<HelpTopic> _getVisibleTopics(HelpAssistantProvider provider) {
    final cat = provider.selectedCategory;
    if (cat == 'all') {
      return HelpKnowledgeBase.topics.take(8).toList();
    }
    return HelpKnowledgeBase.topics.where((t) => t.category == cat).take(8).toList();
  }

  Widget _buildMessageItem(
    BuildContext context,
    HelpMessage msg,
    HelpAssistantProvider provider,
    BtTheme bt,
  ) {
    final isBot = msg.sender == 'bot';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(Icons.smart_toy_rounded, color: bt.accent, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Speech bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBot ? const Color(0xFF1A1E29) : bt.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isBot ? 2 : 14),
                      bottomRight: Radius.circular(isBot ? 14 : 2),
                    ),
                    border: isBot ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isBot ? Colors.white : bt.onAccent,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),

                // Structured Topic Card
                if (msg.topic != null) ...[
                  const SizedBox(height: 8),
                  _buildTopicCard(context, msg.topic!, bt),
                ],

                // Related Topics Suggestions
                if (msg.relatedTopics != null && msg.relatedTopics!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: msg.relatedTopics!.map((t) {
                      return InkWell(
                        onTap: () {
                          provider.selectTopic(t);
                          _scrollToBottom();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            t.title,
                            style: TextStyle(color: bt.accent, fontSize: 11),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, HelpTopic topic, BtTheme bt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bt.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: bt.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, color: bt.accent, size: 12),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Path: ${topic.breadcrumbs}',
                    style: TextStyle(
                      color: bt.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            topic.summary,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 10),

          // Steps list
          Column(
            children: List.generate(topic.steps.length, (idx) {
              final step = topic.steps[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bt.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: bt.onAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // Pro Tip
          if (topic.tips != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFBBF24), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tip: ${topic.tips}',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Take Me There Button
          if (topic.route.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bt.accent,
                  foregroundColor: bt.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  topic.actionLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, topic.route);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
