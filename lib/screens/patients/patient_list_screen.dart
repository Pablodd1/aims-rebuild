import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await Supabase.instance.client
          .from('patients')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _patients = List<Map<String, dynamic>>.from(data);
        _filtered = _patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = _patients.where((p) {
        final first = (p['first_name'] ?? '').toString().toLowerCase();
        final last = (p['last_name'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        return first.contains(q) || last.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Patients (CSV)',
            onPressed: () => context.push('/patients/import'),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Patient',
            onPressed: () => context.push('/patients/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _onSearch,
            ),
          ),
          // Patient count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_filtered.length} patients', style: TextStyle(color: Colors.grey[600])),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadPatients,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : _filtered.isEmpty
                        ? const Center(child: Text('No patients found. Tap + to add one.'))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final p = _filtered[i];
                              return _PatientTile(patient: p);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientTile({required this.patient});

  @override
  Widget build(BuildContext context) {
    final name = '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim();
    final dob = patient['date_of_birth'] ?? 'N/A';
    final phone = patient['phone'] ?? '';
    final hasAlerts = (patient['medical_alerts'] != null && (patient['medical_alerts'] as String).isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0056D2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(name.isNotEmpty ? name : 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hasAlerts) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: patient['medical_alerts'],
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              ),
            ],
          ],
        ),
        subtitle: Text('DOB: $dob • $phone'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              tooltip: 'Export Patient Record',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting patient record...')),
                );
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/patients/${patient['id']}'),
      ),
    );
  }
}
