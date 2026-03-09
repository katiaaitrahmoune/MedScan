import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PrescriptionScannerApp());
}

const String kBackendUrl =
    'https://seminationalized-floretty-shirl.ngrok-free.dev';

// ─── Colors ───────────────────────────────────────────────────────────────────
const kBg = Color(0xFF0A0C1A);
const kBlue = Color(0xFF3D52D5);
const kBlueLight = Color(0xFF7B8FF7);
const kCard = Color(0xFF111326);

// ─── Models ───────────────────────────────────────────────────────────────────
class ScannedMedication {
  final String raw;
  final bool matched;
  final String confidence;
  final MedicationDetail? medication;

  ScannedMedication({
    required this.raw,
    required this.matched,
    required this.confidence,
    this.medication,
  });

  factory ScannedMedication.fromJson(Map<String, dynamic> json) {
    return ScannedMedication(
      raw: json['raw'] ?? '',
      matched: json['matched'] ?? false,
      confidence: json['confidence'] ?? '0%',
      medication: json['medication'] != null
          ? MedicationDetail.fromJson(json['medication'])
          : null,
    );
  }
}

class MedicationDetail {
  final String name;
  final List<String> brands;
  final String? category;
  final List<String> dosageForms;
  final List<String> commonDoses;
  final String? detectedDosage;
  final String? notes;

  MedicationDetail({
    required this.name,
    required this.brands,
    this.category,
    required this.dosageForms,
    required this.commonDoses,
    this.detectedDosage,
    this.notes,
  });

  factory MedicationDetail.fromJson(Map<String, dynamic> json) {
    return MedicationDetail(
      name: json['name'] ?? '',
      brands: List<String>.from(json['brands'] ?? []),
      category: json['category'],
      dosageForms: List<String>.from(json['dosage_forms'] ?? []),
      commonDoses: List<String>.from(json['common_doses'] ?? []),
      detectedDosage: json['detectedDosage'],
      notes: json['notes'],
    );
  }
}

// ─── App ─────────────────────────────────────────────────────────────────────
class PrescriptionScannerApp extends StatelessWidget {
  const PrescriptionScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'sans-serif',
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: size.height * 0.2,
            left: size.width * 0.1,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kBlue.withOpacity(0.4),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo box
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: kBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: kBlueLight.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: kBlue.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: kBlueLight,
                        size: 50,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App name
                    const Text(
                      'MedScan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Scan. Identify. Stay safe.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Page dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 5,
                          decoration: BoxDecoration(
                            color: kBlue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;
    }
    final XFile? image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 90,
    );
    if (image != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanScreen(imageFile: File(image.path)),
        ),
      );
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Add prescription',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Take a photo or choose from gallery',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _PickerBtn(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pick(context, ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PickerBtn(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pick(context, ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 1.4,
              height: size.width * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kBlue.withOpacity(0.45),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),

                  // Logo icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: kBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: kBlueLight.withOpacity(0.45), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kBlue.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: kBlueLight,
                      size: 36,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Title
                  const Text(
                    'MedScan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Scan any prescription.\nGet medication info instantly.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // Scan button
                  GestureDetector(
                    onTap: () => _showPicker(context),
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        color: kBlue,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: kBlue.withOpacity(0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Scan Prescription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kBlueLight, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Scan Screen ─────────────────────────────────────────────────────────────
class ScanScreen extends StatefulWidget {
  final File imageFile;
  const ScanScreen({super.key, required this.imageFile});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _loading = true;
  String _status = 'Sending to AI...';
  List<ScannedMedication> _results = [];
  String? _error;
  int _extracted = 0;
  int _matched = 0;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Sending to Gemini AI...';
    });

    try {
      final uri = Uri.parse('$kBackendUrl/api/scan');
      final request = http.MultipartRequest('POST', uri);
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(
        await http.MultipartFile.fromPath(
            'prescription', widget.imageFile.path),
      );

      setState(() => _status = 'Reading handwriting...');

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['results'] as List;
          if (mounted) {
            setState(() {
              _results =
                  list.map((r) => ScannedMedication.fromJson(r)).toList();
              _extracted = data['totalExtracted'] ?? 0;
              _matched = data['totalMatched'] ?? 0;
              _loading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = data['error'];
              _loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Server error ${response.statusCode}';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const Spacer(),
                  if (!_loading && _error == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '$_matched/$_extracted matched',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _error != null
                      ? _buildError()
                      : _results.isEmpty
                          ? _buildEmpty()
                          : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: kBlue.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: kBlueLight.withOpacity(0.3)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: kBlueLight, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 22),
          Text(_status,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Gemini AI is reading the handwriting',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: Colors.redAccent.withOpacity(0.6), size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _scan,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: kBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Try again',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text('No medications detected',
          style: TextStyle(
              color: Colors.white.withOpacity(0.4), fontSize: 15)),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _results.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Results',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    )),
                const SizedBox(height: 5),
                Text('$_matched of $_extracted medications identified',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14)),
              ],
            ),
          );
        }
        return _MedCard(result: _results[i - 1]);
      },
    );
  }
}

// ─── Med Card ─────────────────────────────────────────────────────────────────
class _MedCard extends StatelessWidget {
  final ScannedMedication result;
  const _MedCard({required this.result});

  Color _confColor() {
    final val = int.tryParse(result.confidence.replaceAll('%', '')) ?? 0;
    if (val >= 80) return const Color(0xFF4ADE80);
    if (val >= 50) return const Color(0xFFFBBF24);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final med = result.medication;
    final isMatched = result.matched && med != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMatched
              ? Colors.white.withOpacity(0.09)
              : const Color(0xFFFF9500).withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isMatched ? _buildMatched(med!) : _buildUnmatched(),
      ),
    );
  }

  Widget _buildMatched(MedicationDetail med) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + confidence
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                med.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _confColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _confColor().withOpacity(0.4)),
              ),
              child: Text(
                result.confidence,
                style: TextStyle(
                  color: _confColor(),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),
        Text(
          'Read as: "${result.raw}"',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: 14),
        Divider(color: Colors.white.withOpacity(0.07), height: 1),
        const SizedBox(height: 14),

        if (med.detectedDosage != null)
          _row(Icons.medication_outlined, 'Dosage', med.detectedDosage!),
        if (med.category != null)
          _row(Icons.category_outlined, 'Type', med.category!),
        if (med.dosageForms.isNotEmpty)
          _row(Icons.science_outlined, 'Forms', med.dosageForms.join(', ')),

        if (med.brands.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'BRAND NAMES',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: med.brands.toSet().toList().map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(b,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            )).toList(),
          ),
        ],

        if (med.notes != null && med.notes!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.07), height: 1),
          const SizedBox(height: 10),
          Text(
            med.notes!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 8),
          SizedBox(
            width: 54,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnmatched() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: const Color(0xFFFF9500).withOpacity(0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  color: Color(0xFFFF9500), size: 12),
              SizedBox(width: 5),
              Text('AI PREDICTION',
                  style: TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(result.raw,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(
          'Gemini read this from the prescription but it was not found in our medication database. Please verify with a pharmacist.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              height: 1.5),
        ),
      ],
    );
  }
}