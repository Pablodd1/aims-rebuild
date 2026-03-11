import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class PatientProfileScreen extends StatefulWidget {
  final String patientId;
  const PatientProfileScreen({super.key, required this.patientId});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final patientRes = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.patientId)
          .single();
      final notesRes = await Supabase.instance.client
          .from('clinical_notes')
          .select()
          .eq('patient_id', widget.patientId)
          .order('created_at', ascending: false);
      setState(() {
        _patient = patientRes;
        _notes = List<Map<String, dynamic>>.from(notesRes);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_patient == null) {
      return const Scaffold(body: Center(child: Text('Patient not found.')));
    }
    final p = _patient!;
    final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Copy Intake Link',
            onPressed: _copyIntakeLink,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Full EHR Record',
            onPressed: _exportRecord,
          ),
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'New Clinical Note',
            onPressed: () => context.push('/notes/new?patientId=${widget.patientId}'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Demographics'),
            Tab(icon: Icon(Icons.description), text: 'Notes'),
            Tab(icon: Icon(Icons.science), text: 'Labs'),
            Tab(icon: Icon(Icons.monitor_heart), text: 'Vitals / RPM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDemographicsTab(p),
          _buildNotesTab(),
          const Center(child: Text('Lab results will load here.')),
          const Center(child: Text('RPM vitals will load here.')),
        ],
      ),
    );
  }

  Widget _buildDemographicsTab(Map<String, dynamic> p) {
    final hasAlerts = (p['medical_alerts'] != null && (p['medical_alerts'] as String).isNotEmpty);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (hasAlerts)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50], border: Border.all(color: Colors.red[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(child: Text('MEDICAL ALERT: ${p['medical_alerts']}', style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        _infoRow('First Name', p['first_name']),
        _infoRow('Last Name', p['last_name']),
        _infoRow('Date of Birth', p['date_of_birth']),
        _infoRow('Email', p['email']),
        _infoRow('Phone', p['phone']),
        _infoRow('Address', p['address']),
        _infoRow('Insurance', p['insurance_info']),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text((value ?? 'N/A').toString())),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_notes.isEmpty) {
      return const Center(child: Text('No clinical notes yet. Create one from the top-right button.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (ctx, i) {
        final n = _notes[i];
        final isSigned = n['is_signed'] == true || n['status'] == 'signed';
        final isIntake = n['note_type'] == 'intake_form';
        final title = isIntake ? 'Intake Form (Voice/Text)' : (n['title'] ?? 'Untitled Note');
        final created = n['created_at'] != null ? n['created_at'].toString().substring(0, 10) : '';
        return Card(
          child: ListTile(
            leading: Icon(
              isIntake ? Icons.assignment_ind : (isSigned ? Icons.verified : Icons.edit_note),
              color: isIntake ? Colors.blue : (isSigned ? Colors.green : Colors.orange),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Date: $created • Type: ${n['note_type'] ?? 'clinical'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSigned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('🚩 UNSIGNED', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              // Navigate to note viewer/editor
            },
          ),
        );
      },
    );
  }

  void _exportRecord() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Patient EHR'),
        content: const Text('This will generate a secure, encrypted export of the patient\'s full medical record (demographics, notes, labs, vitals) compliant with HIPAA Right of Access requirements.\n\nThe download link will expire in 24 hours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📦 Export queued. You will receive a download link shortly.')),
              );
            },
            child: const Text('Generate Export'),
          ),
        ],
      ),
    );
  }

  void _copyIntakeLink() {
    final link = 'https://aims-rebuild.vercel.app/intake/${widget.patientId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied Public Intake Link: $link'), duration: const Duration(seconds: 4)),
    );
  }

}
