import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  final _statusColors = {
    'scheduled': Colors.blue,
    'confirmed': Colors.green,
    'checked_in': Colors.teal,
    'in_progress': Colors.orange,
    'completed': Colors.grey,
    'cancelled': Colors.red,
    'no_show': Colors.deepOrange,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('appointments')
          .select('*, patients(first_name, last_name, phone)')
          .order('appointment_date', ascending: true);
      setState(() {
        _appointments = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _todayAppts {
    final today = DateTime.now();
    return _appointments.where((a) {
      final d = DateTime.tryParse(a['appointment_date'] ?? '');
      return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }

  List<Map<String, dynamic>> get _upcomingAppts {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _appointments.where((a) {
      final d = DateTime.tryParse(a['appointment_date'] ?? '');
      return d != null && d.isAfter(tomorrow);
    }).toList();
  }

  List<Map<String, dynamic>> get _pastAppts {
    final today = DateTime.now();
    return _appointments.where((a) {
      final d = DateTime.tryParse(a['appointment_date'] ?? '');
      return d != null && d.isBefore(DateTime(today.year, today.month, today.day));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Appointment',
            onPressed: () => _showNewAppointmentDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Today (${_todayAppts.length})'),
            const Tab(text: 'Upcoming'),
            const Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApptList(_todayAppts),
                _buildApptList(_upcomingAppts),
                _buildApptList(_pastAppts),
              ],
            ),
    );
  }

  Widget _buildApptList(List<Map<String, dynamic>> appts) {
    if (appts.isEmpty) {
      return const Center(child: Text('No appointments in this period.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appts.length,
      itemBuilder: (ctx, i) {
        final a = appts[i];
        final patient = a['patients'] as Map<String, dynamic>?;
        final name = patient != null
            ? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim()
            : 'Unknown Patient';
        final dateStr = a['appointment_date'] ?? '';
        final dt = DateTime.tryParse(dateStr);
        final formattedDate = dt != null
            ? '${dt.month}/${dt.day}/${dt.year} at ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : dateStr;
        final status = a['status'] ?? 'scheduled';
        final statusColor = _statusColors[status] ?? Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.15),
              child: Icon(_visitTypeIcon(a['visit_type']), color: statusColor),
            ),
            title: Row(
              children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(formattedDate, style: const TextStyle(fontSize: 13)),
                ]),
                if ((a['reason'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(a['reason'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) => _updateStatus(a['id'], val),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'confirmed', child: Text('✅ Confirm')),
                const PopupMenuItem(value: 'checked_in', child: Text('🏥 Check In')),
                const PopupMenuItem(value: 'in_progress', child: Text('▶️ In Progress')),
                const PopupMenuItem(value: 'completed', child: Text('✔️ Complete')),
                const PopupMenuItem(value: 'no_show', child: Text('🚫 No Show')),
                const PopupMenuItem(value: 'cancelled', child: Text('❌ Cancel')),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _visitTypeIcon(String? type) {
    switch (type) {
      case 'telemedicine': return Icons.videocam;
      case 'phone': return Icons.phone;
      case 'home': return Icons.home;
      default: return Icons.local_hospital;
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('appointments')
          .update({'status': status})
          .eq('id', id);
      await _loadAppointments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showNewAppointmentDialog() {
    final reasonCtrl = TextEditingController();
    String selectedType = 'office';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Visit')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Visit Type'),
              items: const [
                DropdownMenuItem(value: 'office', child: Text('Office Visit')),
                DropdownMenuItem(value: 'telemedicine', child: Text('Telemedicine')),
                DropdownMenuItem(value: 'phone', child: Text('Phone Call')),
              ],
              onChanged: (v) { if (v != null) selectedType = v; },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
        ],
      ),
    );
  }
}
