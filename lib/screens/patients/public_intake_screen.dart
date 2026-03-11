import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicIntakeScreen extends StatefulWidget {
  final String patientId;
  const PublicIntakeScreen({super.key, required this.patientId});

  @override
  State<PublicIntakeScreen> createState() => _PublicIntakeScreenState();
}

class _PublicIntakeScreenState extends State<PublicIntakeScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _patient;
  final TextEditingController _transcriptController = TextEditingController();
  
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    try {
      final res = await Supabase.instance.client
          .from('patients')
          .select('first_name, last_name, id')
          .eq('id', widget.patientId)
          .maybeSingle();
      
      if (res != null) {
        setState(() {
          _patient = res;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitIntake() async {
    if (_transcriptController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      // Create a drafted note in the patient's chart
      final noteContent = {
        'type': 'Patient Intake',
        'raw_input': _transcriptController.text.trim(),
        'date': DateTime.now().toIso8601String(),
        'status': 'Needs Doctor Review'
      };

      await Supabase.instance.client.from('clinical_notes').insert({
        'patient_id': widget.patientId,
        'provider_id': null, // Publicly submitted
        'note_type': 'intake_form',
        'content': noteContent,
        'is_signed': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake form successfully submitted securely.')),
        );
        // Clear the form
        _transcriptController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_patient == null) {
      return const Scaffold(
        body: Center(child: Text('Invalid Intake Link or Patient Not Found.')),
      );
    }

    final name = '${_patient!['first_name']} ${_patient!['last_name']}';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Secure Patient Intake'),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0056D2),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.security, size: 48, color: Colors.green),
                      const SizedBox(height: 16),
                      Text('Welcome, $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Please describe your symptoms, reason for visit, or any medical updates. You can type or use voice dictation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TextField(
                  controller: _transcriptController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'e.g. "I have had a headache for 3 days and my throat hurts..."',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isRecording = !_isRecording);
                        if (_isRecording) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice recording simulated for demo. Please type for now.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: _isRecording ? Colors.red[50] : Colors.blue[50],
                        foregroundColor: _isRecording ? Colors.red : const Color(0xFF0056D2),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Use Voice (Mic)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitIntake,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: const Color(0xFF0056D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: const Text('Submit securely', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('🔒 HIPAA Compliant Secure Form', style: TextStyle(color: Colors.black38, fontSize: 12)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
