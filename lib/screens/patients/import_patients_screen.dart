import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

/// CSV Import screen for Front Desk to bulk-import patients from legacy EHR systems.
/// Expected CSV headers: first_name,last_name,email,phone,date_of_birth,address,insurance_info,medical_alerts
class ImportPatientsScreen extends StatefulWidget {
  const ImportPatientsScreen({super.key});

  @override
  State<ImportPatientsScreen> createState() => _ImportPatientsScreenState();
}

class _ImportPatientsScreenState extends State<ImportPatientsScreen> {
  final _csvController = TextEditingController();
  bool _isImporting = false;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errors = [];

  Future<void> _importCsv() async {
    final raw = _csvController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste CSV data first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _isImporting = true; _successCount = 0; _errorCount = 0; _errors = []; });

    final lines = const LineSplitter().convert(raw);
    if (lines.length < 2) {
      setState(() { _isImporting = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV must have a header row and at least one data row.'), backgroundColor: Colors.red),
      );
      return;
    }

    final headers = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
    final requiredHeaders = ['first_name', 'last_name'];
    for (final rh in requiredHeaders) {
      if (!headers.contains(rh)) {
        setState(() { _isImporting = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Missing required CSV header: $rh'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim()).toList();
      if (values.length != headers.length) {
        _errors.add('Row ${i + 1}: Column count mismatch (expected ${headers.length}, got ${values.length})');
        _errorCount++;
        continue;
      }
      final row = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        final val = values[j];
        row[headers[j]] = val.isEmpty ? null : val;
      }
      // Validate required
      if ((row['first_name'] ?? '').toString().isEmpty || (row['last_name'] ?? '').toString().isEmpty) {
        _errors.add('Row ${i + 1}: Missing first_name or last_name');
        _errorCount++;
        continue;
      }
      row['created_by'] = userId;

      try {
        await Supabase.instance.client.from('patients').insert(row);
        _successCount++;
      } catch (e) {
        _errors.add('Row ${i + 1}: $e');
        _errorCount++;
      }
    }

    setState(() => _isImporting = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Successfully imported: $_successCount patients'),
              if (_errorCount > 0) ...[
                Text('❌ Errors: $_errorCount', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(_errors.join('\n'), style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); context.pop(); },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Patients (CSV)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 CSV Format Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Required headers: first_name, last_name'),
                  Text('Optional headers: email, phone, date_of_birth, address, insurance_info, medical_alerts'),
                  SizedBox(height: 8),
                  Text('Example:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('first_name,last_name,email,phone,date_of_birth\nJohn,Doe,john@email.com,555-1234,1985-03-15\nJane,Smith,jane@email.com,555-5678,1990-07-22',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Paste CSV Data Below:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _csvController,
              maxLines: 15,
              decoration: const InputDecoration(
                hintText: 'first_name,last_name,email,phone,date_of_birth\nJohn,Doe,john@email.com,...',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _importCsv,
              icon: _isImporting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload),
              label: Text(_isImporting ? 'Importing...' : 'Import Patients'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF0056D2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
