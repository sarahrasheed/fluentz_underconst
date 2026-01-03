import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/fluentz_colors.dart';
import '../widgets/auth_feedback.dart';

class AiAssessmentScreen extends StatefulWidget {
  const AiAssessmentScreen({
    super.key,
    required this.userId,
    required this.languageId,
    required this.languageName,
  });

  final int userId;
  final int languageId;
  final String languageName;

  @override
  State<AiAssessmentScreen> createState() => _AiAssessmentScreenState();
}

class _AiAssessmentScreenState extends State<AiAssessmentScreen> {
  static const int _backendPort = 8000;

  bool _loading = false;

  // ✅ Stateless tokens (instead of session_id)
  String? _stateToken; // always required (mcq + writing)
  String? _answerKey; // only for mcq steps (contains correct answer)

  // Current item
  String _type = "mcq"; // "mcq" | "writing"
  int _step = 1;
  String _targetCefr = "B1";
  String _prompt = "";
  Map<String, dynamic> _options = {}; // for mcq
  String? _selectedChoice;

  // Writing
  final _writingCtrl = TextEditingController();
  int _minWords = 320;
  int _maxWords = 420;

  // Result
  Map<String, dynamic>? _finalResult;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _writingCtrl.dispose();
    super.dispose();
  }

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort";
  }

  String _extractDetail(String body,
      {String fallback = "Something went wrong"}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["detail"] != null) {
        final detail = decoded["detail"];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first["msg"] != null)
            return first["msg"].toString();
        }
        return detail.toString();
      }
      if (decoded is Map && decoded["message"] != null) {
        return decoded["message"].toString();
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse("${_baseUrl()}/assessment/ai/start");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "language_id": widget.languageId,
        }),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        showAuthError(
          context,
          _extractDetail(res.body, fallback: "Failed to start assessment"),
        );
        setState(() => _loading = false);
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // ✅ New backend fields
      _stateToken = (data["state_token"] ?? "").toString();
      _answerKey = (data["answer_key"] ?? "").toString();

      _step = (data["step"] ?? 1) as int;
      _targetCefr = (data["target_cefr"] ?? "B1").toString();
      _type = (data["type"] ?? "mcq").toString();
      _prompt = (data["prompt"] ?? "").toString();

      final opts = data["options"];
      _options = (opts is Map<String, dynamic>) ? opts : <String, dynamic>{};
      _selectedChoice = null;

      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthError(
          context, "Cannot reach server. Make sure backend is running.");
    }
  }

  Future<void> _submitMcq() async {
    if ((_stateToken ?? "").isEmpty || (_answerKey ?? "").isEmpty) {
      showAuthError(context, "Assessment state is missing. Please restart.");
      return;
    }

    if (_selectedChoice == null) {
      showAuthError(context, "Please select an answer.");
      return;
    }

    setState(() => _loading = true);

    try {
      final url = Uri.parse("${_baseUrl()}/assessment/ai/answer-mcq");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "state_token": _stateToken,
          "answer_key": _answerKey,
          "choice": _selectedChoice,
        }),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => _loading = false);
        showAuthError(context,
            _extractDetail(res.body, fallback: "Failed to submit answer"));
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final doneCore = (data["done_core"] == true);

      // ✅ Always update state_token (backend sends new one each step)
      _stateToken = (data["state_token"] ?? "").toString();

      // Optional: show prev feedback quickly
      final prevFeedback = (data["prev_feedback"] ?? "").toString();
      if (prevFeedback.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prevFeedback)),
        );
      }

      if (doneCore) {
        // ✅ Writing phase now
        _type = "writing";
        _prompt = (data["prompt"] ?? "").toString();

        // In backend we return "target_cefr" in writing response
        _targetCefr = (data["target_cefr"] ?? "B1").toString();

        final limits = (data["limits"] ?? {}) as Map<String, dynamic>;
        _minWords = (limits["min_words"] ?? _minWords) as int;
        _maxWords = (limits["max_words"] ?? _maxWords) as int;

        _writingCtrl.clear();
        _answerKey = null; // no longer needed in writing
        setState(() => _loading = false);
        return;
      }

      // ✅ Next MCQ
      _type = "mcq";
      _step = (data["step"] ?? _step) as int;
      _targetCefr = (data["target_cefr"] ?? _targetCefr).toString();
      _prompt = (data["prompt"] ?? "").toString();

      final opts = data["options"];
      _options = (opts is Map<String, dynamic>) ? opts : <String, dynamic>{};

      // ✅ New answer_key for next question
      _answerKey = (data["answer_key"] ?? "").toString();

      _selectedChoice = null;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthError(context, "Server error. Please try again.");
    }
  }

  int _countWords(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r"\s+")).where((w) => w.trim().isNotEmpty).length;
  }

  Future<void> _submitWriting() async {
    if ((_stateToken ?? "").isEmpty) {
      showAuthError(context, "Assessment state is missing. Please restart.");
      return;
    }

    final text = _writingCtrl.text.trim();
    final wc = _countWords(text);

    if (wc < _minWords) {
      showAuthError(context,
          "Too short. Please write at least $_minWords words. (Now: $wc)");
      return;
    }
    if (wc > _maxWords) {
      showAuthError(
          context, "Too long. Please stay under $_maxWords words. (Now: $wc)");
      return;
    }

    setState(() => _loading = true);

    try {
      final url = Uri.parse("${_baseUrl()}/assessment/ai/submit-writing");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "state_token": _stateToken,
          "text": text,
        }),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => _loading = false);
        showAuthError(context,
            _extractDetail(res.body, fallback: "Failed to submit writing"));
        return;
      }

      _finalResult = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthError(context, "Server error. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _finalResult != null;

    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        foregroundColor: FluentzColors.navy,
        title: Text(
          "Assessment • ${widget.languageName}",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: isDone ? _buildResult() : _buildCurrentItem(),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FluentzColors.navy.withOpacity(0.10)),
      ),
      child: child,
    );
  }

  Widget _buildCurrentItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _type == "mcq"
                    ? "Question $_step • Target: $_targetCefr"
                    : "Writing • Target: $_targetCefr",
                style: TextStyle(
                  color: FluentzColors.navy.withOpacity(0.70),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _prompt,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: FluentzColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _type == "mcq" ? _buildMcq() : _buildWriting(),
        ),
      ],
    );
  }

  Widget _buildMcq() {
    final entries = _options.entries.toList(); // A,B,C,D

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final key = entries[i].key.toString();
              final value = entries[i].value.toString();
              final selected = _selectedChoice == key;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedChoice = key),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? FluentzColors.lightBlue.withOpacity(0.18)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? FluentzColors.lightBlue
                          : FluentzColors.navy.withOpacity(0.10),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? FluentzColors.lightBlue
                              : FluentzColors.hotYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: FluentzColors.navy,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitMcq,
            style: ElevatedButton.styleFrom(
              backgroundColor: FluentzColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Submit",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWriting() {
    final wc = _countWords(_writingCtrl.text);

    return Column(
      children: [
        Expanded(
          child: _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Write $_minWords–$_maxWords words (now: $wc)",
                  style: TextStyle(
                    color: FluentzColors.navy.withOpacity(0.70),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    controller: _writingCtrl,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: "Write your essay here...",
                      filled: true,
                      fillColor: const Color(0xFFFBFBFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: FluentzColors.navy.withOpacity(0.10)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: FluentzColors.navy.withOpacity(0.10)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: FluentzColors.lightBlue, width: 1.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitWriting,
            style: ElevatedButton.styleFrom(
              backgroundColor: FluentzColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Submit writing",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final r = _finalResult!;
    final finalCefr = (r["final_cefr"] ?? "").toString();
    final writingLevel = (r["writing_level"] ?? "").toString();
    final coreEstimate = (r["core_estimate"] ?? "").toString();
    final writingScore = (r["writing_score"] ?? "").toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "✅ Assessment completed",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: FluentzColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Final CEFR: $finalCefr",
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: FluentzColors.navy),
              ),
              const SizedBox(height: 6),
              Text(
                "Core estimate: $coreEstimate",
                style: TextStyle(color: FluentzColors.navy.withOpacity(0.75)),
              ),
              Text(
                "Writing: $writingLevel (score $writingScore)",
                style: TextStyle(color: FluentzColors.navy.withOpacity(0.75)),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: FluentzColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Back",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}
