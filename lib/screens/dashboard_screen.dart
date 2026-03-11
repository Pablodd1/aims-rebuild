import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIMS Clinical Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Secure Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0056D2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.account_circle, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('Provider', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(user?.email ?? 'Unknown', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () { Navigator.pop(context); context.go('/dashboard'); },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Patients'),
              onTap: () { Navigator.pop(context); context.push('/patients'); },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import Patients (CSV)'),
              onTap: () { Navigator.pop(context); context.push('/patients/import'); },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Appointments'),
              onTap: () { Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Triage & Intake Hub'),
              onTap: () { Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Clinical Settings'),
              onTap: () { Navigator.pop(context); },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.email ?? 'Provider'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('AIMS Enterprise EHR • ${DateTime.now().toString().substring(0, 10)}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 32),
            // Quick Actions Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _DashboardCard(
                    icon: Icons.people,
                    title: 'Patient Registry',
                    subtitle: 'View, search & manage patients',
                    color: const Color(0xFF0056D2),
                    onTap: () => context.push('/patients'),
                  ),
                  _DashboardCard(
                    icon: Icons.note_add,
                    title: 'AI Scribe',
                    subtitle: 'New clinical note with ambient AI',
                    color: Colors.teal,
                    onTap: () => context.push('/notes/new?patientId='),
                  ),
                  _DashboardCard(
                    icon: Icons.upload_file,
                    title: 'Import Patients',
                    subtitle: 'Bulk CSV upload from legacy EHR',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/patients/import'),
                  ),
                  _DashboardCard(
                    icon: Icons.calendar_today,
                    title: 'Appointments',
                    subtitle: 'Schedule & manage visits',
                    color: Colors.orange,
                    onTap: () {},
                  ),
                  _DashboardCard(
                    icon: Icons.science,
                    title: 'Lab Interpreter',
                    subtitle: 'AI-powered lab analysis',
                    color: Colors.indigo,
                    onTap: () {},
                  ),
                  _DashboardCard(
                    icon: Icons.monitor_heart,
                    title: 'RPM Vitals',
                    subtitle: 'Bluetooth device monitoring',
                    color: Colors.red,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
