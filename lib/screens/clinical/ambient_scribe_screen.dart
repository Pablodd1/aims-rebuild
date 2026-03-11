import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ambient AI Medical Scribe Screen
/// Records audio, sends transcript to Supabase Edge Function,
/// receives structured SOAP note with ICD-10 and CPT codes.
class AmbientScribeScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  const AmbientScribeScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<AmbientScribeScreen> createState() => _AmbientScribeScreenState();
}

class _AmbientScribeScreenState extends State<AmbientScribeScreen> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // AI-generated SOAP note fields
  Map<String, dynamic>? _soapResult;
  String? _errorMessage;
  String? _sessionId;

  // Simulated transcript (in production, use speech_to_text or deepgram stream)
  final _manualTranscriptController = TextEditingController();
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _manualTranscriptController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Create a scribe session in Supabase
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final res = await Supabase.instance.client.from('scribe_sessions').insert({
        'patient_id': widget.patientId,
        'provider_id': userId,
        'status': 'recording',
      }).select().single();
      _sessionId = res['id'];
    } catch (_) {}

    setState(() { _isRecording = true; _elapsedSeconds = 0; });
    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    _pulseController.stop();
    setState(() { _isRecording = false; _isProcessing = true; _errorMessage = null; });

    // In production, the real audio is transcribed here.
    // For now, use the manual transcript input if provided.
    final transcript = _manualTranscriptController.text.trim();
    if (transcript.isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'No transcript available. Please enter the consultation notes manually below.';
        _showManualInput = true;
      });
      return;
    }

    await _processThroughAI(transcript);
  }

  Future<void> _processThroughAI(String transcript) async {
    setState(() { _isProcessing = true; _errorMessage = null; });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final res = await Supabase.instance.client.functions.invoke(
        'generate-soap-note',
        body: {
          'transcript': transcript,
          'patientId': widget.patientId,
          'sessionId': _sessionId,
        },
        headers: { 'Authorization': 'Bearer ${session?.accessToken}' },
      );

      if (res.status != 200) {
        throw Exception('AI returned status ${res.status}');
      }

      setState(() {
        _soapResult = res.data as Map<String, dynamic>;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'AI Processing failed: $e\n\nYou can still manually complete the note below.';
        _showManualInput = true;
      });
    }
  }

  Future<void> _saveToNote() async {
    if (_soapResult == null) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('medical_notes').insert({
        'patient_id': widget.patientId,
        'doctor_id': userId,
        'title': 'AI Scribe Note - ${DateTime.now().toString().substring(0, 10)}',
        'type': 'soap',
        'status': 'draft',
        'hpi': _soapResult!['hpi'],
        'review_of_systems': _soapResult!['review_of_systems'],
        'physical_exam': _soapResult!['physical_exam'],
        'assessment_and_plan': _soapResult!['assessment_and_plan'],
        'ai_suggested_icd10': _soapResult!['suggested_icd10'],
        'ai_suggested_cpt': _soapResult!['suggested_cpt'],
        'content': _soapResult!['assessment_and_plan'] ?? '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Note saved as Draft. Go sign it from the Patient Profile.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Scribe — ${widget.patientName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recording Status Card
            _buildRecordingCard(),
            const SizedBox(height: 24),

            // Manual transcript input (fallback)
            if (_showManualInput || !_isRecording && _soapResult == null)
              _buildManualInput(),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.orange[900])),
              ),
            ],

            // AI Result
            if (_soapResult != null) ...[
              const SizedBox(height: 24),
              _buildSoapResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            if (_isRecording)
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                  child: const Icon(Icons.mic, size: 40, color: Colors.red),
                ),
              )
            else
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.teal[50], shape: BoxShape.circle),
                child: const Icon(Icons.mic_none, size: 40, color: Colors.teal),
              ),
            const SizedBox(height: 16),
            if (_isRecording)
              Text(_formatTime(_elapsedSeconds), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.red))
            else if (_isProcessing)
              const Column(children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 12),
                Text('AI is generating SOAP note...', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ])
            else
              const Text('Ready to Record', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording && !_isProcessing && _soapResult == null)
                  ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Ambient Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                if (_isRecording)
                  ElevatedButton.icon(
                    onPressed: _stopAndProcess,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & Generate SOAP Note'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Transcript / Dictation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Paste or type the consultation transcript, then tap Generate.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: _manualTranscriptController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Patient presents with...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _processThroughAI(_manualTranscriptController.text.trim()),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate SOAP Note with AI'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoapResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green[200]!), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('SOAP Note Generated — Review and Save as Draft', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 16),
        _soapSection('Chief Complaint', _soapResult!['chief_complaint']),
        _soapSection('HPI', _soapResult!['hpi']),
        _soapSection('Review of Systems', _soapResult!['review_of_systems']),
        _soapSection('Physical Exam', _soapResult!['physical_exam']),
        _soapSection('Assessment & Plan', _soapResult!['assessment_and_plan']),
        _codingSection(),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saveToNote,
          icon: const Icon(Icons.save),
          label: const Text('Save as Draft Clinical Note'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0056D2), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _soapSection(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
            const SizedBox(height: 8),
            Text((value ?? 'Not documented').toString()),
          ],
        ),
      ),
    );
  }

  Widget _codingSection() {
    final icd = List<String>.from(_soapResult!['suggested_icd10'] ?? []);
    final cpt = List<String>.from(_soapResult!['suggested_cpt'] ?? []);
    final emLevel = _soapResult!['em_level'] ?? '';

    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI-Suggested Billing Codes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056D2))),
            const SizedBox(height: 8),
            const Text('⚠️ Provider must verify before submitting claim.', style: TextStyle(fontSize: 12, color: Colors.orange)),
            const SizedBox(height: 12),
            if (icd.isNotEmpty) ...[
              const Text('ICD-10 Diagnoses:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: icd.map((c) => Chip(label: Text(c), backgroundColor: Colors.blue[100])).toList()),
            ],
            if (cpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('CPT Procedures:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: cpt.map((c) => Chip(label: Text(c), backgroundColor: Colors.green[100])).toList()),
            ],
            if (emLevel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Text('Suggested E&M Level: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(emLevel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
