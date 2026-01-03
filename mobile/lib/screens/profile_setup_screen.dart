import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/fluentz_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_feedback.dart';
import 'assessment_welcome_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final int userId;
  final String email;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // Backend
  static const int _backendPort = 8000;

  // Form fields
  DateTime? _dob;
  String? _gender; // "male" | "female" | "other"
  final _photoUrlCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  int? _nativeLanguageId; // required
  int? _targetLanguageId; // required
  final Set<int> _fluentLanguageIds = {}; // optional multi
  final Set<int> _interestIds = {}; // multi bubbles

  // Meta data
  bool _loadingMeta = true;
  bool _submitting = false;

  List<_Lang> _languages = [];
  List<_Interest> _interests = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _photoUrlCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort"; // Android emulator -> host
  }

  String _extractFastApiDetail(String body,
      {String fallback = "Something went wrong."}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["detail"] != null) {
        final detail = decoded["detail"];
        // pydantic errors: {"detail":[{"msg":"..."}]}
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first["msg"] != null)
            return first["msg"].toString();
          return detail.toString();
        }
        return detail.toString();
      }
      if (decoded is Map && decoded["message"] != null) {
        return decoded["message"].toString();
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);

    try {
      final langsUrl = Uri.parse("${_baseUrl()}/meta/languages");
      final interestsUrl = Uri.parse("${_baseUrl()}/meta/interests");

      final langsRes = await http.get(langsUrl);
      final intsRes = await http.get(interestsUrl);

      if (!mounted) return;

      if (langsRes.statusCode != 200) {
        showAuthError(
            context,
            _extractFastApiDetail(langsRes.body,
                fallback: "Failed to load languages."));
        setState(() => _loadingMeta = false);
        return;
      }
      if (intsRes.statusCode != 200) {
        showAuthError(
            context,
            _extractFastApiDetail(intsRes.body,
                fallback: "Failed to load interests."));
        setState(() => _loadingMeta = false);
        return;
      }

      final langsJson = jsonDecode(langsRes.body);
      final intsJson = jsonDecode(intsRes.body);

      final langs = <_Lang>[];
      if (langsJson is List) {
        for (final item in langsJson) {
          if (item is Map) {
            langs.add(_Lang(
              id: (item["id"] as num).toInt(),
              code: (item["code"] ?? "").toString(),
              name: (item["name"] ?? "").toString(),
            ));
          }
        }
      }

      final ints = <_Interest>[];
      if (intsJson is List) {
        for (final item in intsJson) {
          if (item is Map) {
            ints.add(_Interest(
              id: (item["id"] as num).toInt(),
              name: (item["name"] ?? "").toString(),
            ));
          }
        }
      }

      langs.sort((a, b) => a.name.compareTo(b.name));
      ints.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _languages = langs;
        _interests = ints;
        _loadingMeta = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMeta = false);
      showAuthError(
          context, "Cannot reach server. Make sure backend is running.");
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: "Select your date of birth",
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _fmtDob(DateTime? d) {
    if (d == null) return "Select date";
    final y = d.year.toString().padLeft(4, "0");
    final m = d.month.toString().padLeft(2, "0");
    final day = d.day.toString().padLeft(2, "0");
    return "$y-$m-$day";
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: FluentzColors.navy.withOpacity(0.75)),
      filled: true,
      fillColor: const Color(0xFFFBFBFC),
      labelStyle: TextStyle(color: FluentzColors.navy.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FluentzColors.navy.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FluentzColors.navy.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: FluentzColors.lightBlue, width: 1.6),
      ),
    );
  }

  void _toggleFluent(int id) {
    setState(() {
      if (_fluentLanguageIds.contains(id)) {
        _fluentLanguageIds.remove(id);
      } else {
        _fluentLanguageIds.add(id);
      }
    });
  }

  void _toggleInterest(int id) {
    setState(() {
      if (_interestIds.contains(id)) {
        _interestIds.remove(id);
      } else {
        _interestIds.add(id);
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Required: native + target (1 each)
    if (_nativeLanguageId == null) {
      showAuthError(context, "Please select your native language.");
      return;
    }
    if (_targetLanguageId == null) {
      showAuthError(context, "Please select your target language.");
      return;
    }

    // Keep DOB + gender on this page. (Often backend expects them.)
    if (_dob == null) {
      showAuthError(context, "Please select your date of birth.");
      return;
    }
    if (_gender == null) {
      showAuthError(context, "Please select your gender.");
      return;
    }

    // Optional but nice
    final bio = _bioCtrl.text.trim();
    if (bio.isNotEmpty && bio.length < 10) {
      showAuthError(
          context, "Your bio is too short. Write a bit more (10+ characters).");
      return;
    }

    setState(() => _submitting = true);

    try {
      final url = Uri.parse("${_baseUrl()}/profile/complete");
      final payload = {
        "user_id": widget.userId,
        "date_of_birth": _fmtDob(_dob),
        "gender": _gender,
        "short_description": bio,
        "profile_photo_url": _photoUrlCtrl.text.trim(),
        "native_language_id": _nativeLanguageId,
        "fluent_language_ids": _fluentLanguageIds.toList(),
        "target_language_ids": [_targetLanguageId], // exactly 1
        "interest_ids": _interestIds.toList(),
      };

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final targetId = _targetLanguageId!;
        final targetName = _languages.firstWhere((l) => l.id == targetId).name;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AssessmentWelcomeScreen(
              userId: widget.userId,
              languageId: targetId,
              languageName: targetName,
            ),
          ),
        );
        return;
      }

      showAuthError(context,
          _extractFastApiDetail(res.body, fallback: "Profile setup failed."));
    } catch (_) {
      if (!mounted) return;
      showAuthError(
          context, "Cannot reach server. Make sure backend is running.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: "Complete your profile",
      subtitle: "Tell us a bit about you so we can personalize your learning.",
      child: _loadingMeta
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 18),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DOB + Gender
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration:
                              _dec("Date of birth", Icons.cake_outlined),
                          child: Text(
                            _fmtDob(_dob),
                            style: TextStyle(
                              color: _dob == null
                                  ? FluentzColors.navy.withOpacity(0.55)
                                  : FluentzColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: _dec("Gender", Icons.person_outline),
                        items: const [
                          DropdownMenuItem(value: "male", child: Text("Male")),
                          DropdownMenuItem(
                              value: "female", child: Text("Female")),
                          DropdownMenuItem(
                              value: "other", child: Text("Other")),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Photo + Bio
                TextField(
                  controller: _photoUrlCtrl,
                  decoration: _dec(
                      "Profile photo URL (optional)", Icons.image_outlined,
                      hint: "https://..."),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _dec("Bio (optional)", Icons.edit_outlined,
                      hint: "A short description about you..."),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Languages",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: FluentzColors.navy,
                  ),
                ),
                const SizedBox(height: 10),

                // Native (required)
                DropdownButtonFormField<int>(
                  value: _nativeLanguageId,
                  decoration: _dec(
                      "Native language (required)", Icons.language_outlined),
                  items: _languages
                      .map((l) => DropdownMenuItem<int>(
                            value: l.id,
                            child: Text(l.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _nativeLanguageId = v),
                ),

                const SizedBox(height: 12),

                // Target (required) (exactly 1)
                DropdownButtonFormField<int>(
                  value: _targetLanguageId,
                  decoration:
                      _dec("Target language (required)", Icons.flag_outlined),
                  items: _languages
                      .map((l) => DropdownMenuItem<int>(
                            value: l.id,
                            child: Text(l.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _targetLanguageId = v),
                ),

                const SizedBox(height: 14),

                Text(
                  "Fluent languages (optional)",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: FluentzColors.navy.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _languages.map((l) {
                    final selected = _fluentLanguageIds.contains(l.id);
                    return FilterChip(
                      label: Text(l.name),
                      selected: selected,
                      onSelected: (_) => _toggleFluent(l.id),
                      selectedColor: FluentzColors.lightBlue.withOpacity(0.25),
                      checkmarkColor: FluentzColors.navy,
                      labelStyle: TextStyle(
                        color: FluentzColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                          color: FluentzColors.navy.withOpacity(0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Interests",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: FluentzColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select as many as you like.",
                  style: TextStyle(color: FluentzColors.navy.withOpacity(0.7)),
                ),
                const SizedBox(height: 10),

                // Interests as bubbles
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _interests.map((it) {
                    final selected = _interestIds.contains(it.id);
                    return FilterChip(
                      label: Text(it.name),
                      selected: selected,
                      onSelected: (_) => _toggleInterest(it.id),
                      selectedColor: FluentzColors.hotYellow.withOpacity(0.28),
                      checkmarkColor: FluentzColors.navy,
                      labelStyle: const TextStyle(
                        color: FluentzColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                      side: BorderSide(
                          color: FluentzColors.navy.withOpacity(0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FluentzColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Save & continue",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                ),
              ],
            ),
    );
  }
}

// Simple models for meta endpoints
class _Lang {
  final int id;
  final String code;
  final String name;
  _Lang({required this.id, required this.code, required this.name});
}

class _Interest {
  final int id;
  final String name;
  _Interest({required this.id, required this.name});
}
