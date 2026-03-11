import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
    _selectedDay = _focusedDay;
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

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _appointments.where((a) {
      final dStr = a['appointment_date'];
      if (dStr == null) return false;
      final d = DateTime.tryParse(dStr);
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Appointments Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Calendar',
            onPressed: _loadAppointments,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Appointment',
            onPressed: () => _showNewAppointmentDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFF0056D2),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.deepOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildApptList(_getEventsForDay(_selectedDay ?? _focusedDay)),
                ),
              ],
            ),
    );
  }

  Widget _buildApptList(List<Map<String, dynamic>> appts) {
    if (appts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No appointments scheduled for this date.', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
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
        final timeStr = dt != null
            ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : '';
        final status = a['status'] ?? 'scheduled';
        final statusColor = _statusColors[status] ?? Colors.grey;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.15),
              child: Icon(_visitTypeIcon(a['visit_type']), color: statusColor),
            ),
            title: Row(
              children: [
                Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if ((a['reason'] ?? '').isNotEmpty)
                  Text(a['reason'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) => _updateStatus(a['id'], val),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                  ],
                ),
              ),
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
