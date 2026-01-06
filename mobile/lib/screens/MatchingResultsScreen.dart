import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/fluentz_colors.dart';
import '../widgets/auth_feedback.dart';

class MatchingResultsScreen extends StatefulWidget {
  const MatchingResultsScreen({super.key, required this.userId});
  final int userId;

  @override
  State<MatchingResultsScreen> createState() => _MatchingResultsScreenState();
}

class _MatchingResultsScreenState extends State<MatchingResultsScreen> {
  static const int _backendPort = 8000;

  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort";
  }

  String _extractDetail(String body,
      {String fallback = "Something went wrong"}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["detail"] != null)
        return decoded["detail"].toString();
      if (decoded is Map && decoded["message"] != null)
        return decoded["message"].toString();
    } catch (_) {}
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);

    try {
      final url = Uri.parse("${_baseUrl()}/matching/recommend");
      final res = await http.post(
        url,
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId}),
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        showAuthError(context,
            _extractDetail(res.body, fallback: "Failed to load matches"));
        setState(() => _loading = false);
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data["recommended_matches"] as List?) ?? [];

      _matches = list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthError(
          context, "Cannot reach server. Make sure backend is running.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        foregroundColor: FluentzColors.navy,
        title: const Text("Your Matches",
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadMatches,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      "No matches found.\n\n(Usually this means: no users satisfy the language condition yet.)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: FluentzColors.navy.withOpacity(0.75),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _MatchCard(m: _matches[i]),
                ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final name = (m["name"] ?? "Unknown").toString();
    final age = (m["age"] ?? "unknown").toString();
    final score = (m["score"] ?? 0).toString();
    final interests =
        (m["interests"] is List) ? (m["interests"] as List).join(", ") : "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FluentzColors.navy.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: FluentzColors.navy)),
          const SizedBox(height: 6),
          Text("Age: $age",
              style: TextStyle(color: FluentzColors.navy.withOpacity(0.75))),
          Text("Score: $score",
              style: TextStyle(color: FluentzColors.navy.withOpacity(0.75))),
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Interests: $interests",
                style: TextStyle(color: FluentzColors.navy.withOpacity(0.8))),
          ],
        ],
      ),
    );
  }
}
