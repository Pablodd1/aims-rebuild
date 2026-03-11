import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  // RCM Dashboard Stats
  double _totalOutstanding = 0;
  double _totalCollected = 0;
  int _unsigned = 0;

  final _statusColors = {
    'draft': Colors.grey,
    'submitted': Colors.blue,
    'paid': Colors.green,
    'partially_paid': Colors.orange,
    'denied': Colors.red,
    'void': Colors.black54,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final invoicesRes = await Supabase.instance.client
          .from('invoices')
          .select('*, patients(first_name, last_name)')
          .order('created_at', ascending: false);

      final unsignedRes = await Supabase.instance.client
          .from('medical_notes')
          .select('id')
          .eq('status', 'draft');

      final data = List<Map<String, dynamic>>.from(invoicesRes);

      double outstanding = 0;
      double collected = 0;
      for (final inv in data) {
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
        if (inv['status'] != 'void') {
          outstanding += (total - paid);
          collected += paid;
        }
      }

      setState(() {
        _invoices = data;
        _totalOutstanding = outstanding;
        _totalCollected = collected;
        _unsigned = unsignedRes.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _byStatus(String status) =>
      _invoices.where((i) => i['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Revenue Cycle'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Invoice',
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'RCM Dashboard'),
            Tab(text: 'Invoices'),
            Tab(text: 'Claim Scrubber'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRCMDashboard(),
                _buildInvoiceList(),
                _buildClaimScrubber(),
              ],
            ),
    );
  }

  Widget _buildRCMDashboard() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Revenue Cycle Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // KPI row
        Row(
          children: [
            _kpiCard('A/R Outstanding', '\$${_totalOutstanding.toStringAsFixed(2)}', Colors.orange, Icons.account_balance_wallet),
            const SizedBox(width: 16),
            _kpiCard('Collected (All Time)', '\$${_totalCollected.toStringAsFixed(2)}', Colors.green, Icons.payments),
            const SizedBox(width: 16),
            _kpiCard('Unsigned Notes', '$_unsigned', Colors.red, Icons.warning_amber),
          ],
        ),
        const SizedBox(height: 24),
        // Status breakdown
        const Text('Invoices by Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._statusColors.entries.map((e) {
          final count = _byStatus(e.key).length;
          final total = _byStatus(e.key).fold(0.0, (sum, i) => sum + ((i['total_amount'] as num?)?.toDouble() ?? 0));
          return _statusRow(e.key, count, total, e.value);
        }),
        if (_unsigned > 0) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50], border: Border.all(color: Colors.red[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🚨 $_unsigned unsigned clinical notes represent potential lost revenue. Sign them to enable billing.',
                  style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusRow(String status, int count, double total, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500))),
          Text('$count invoices', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 16),
          Text('\$${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInvoiceList() {
    if (_invoices.isEmpty) {
      return const Center(child: Text('No invoices yet. Create one by completing an appointment.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        final patient = inv['patients'] as Map<String, dynamic>?;
        final name = patient != null
            ? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim()
            : 'Unknown';
        final status = inv['status'] ?? 'draft';
        final color = _statusColors[status] ?? Colors.grey;
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.receipt, color: color)),
            title: Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color), borderRadius: BorderRadius.circular(12)),
                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Total: \$${total.toStringAsFixed(2)} • Paid: \$${paid.toStringAsFixed(2)} • Due: \$${(total - paid).toStringAsFixed(2)}'),
                if ((inv['diagnosis_codes'] as List?)?.isNotEmpty ?? false)
                  Text('DX: ${(inv['diagnosis_codes'] as List).join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClaimScrubber() {
    // Show draft invoices that might have issues
    final drafts = _byStatus('draft');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Claim Scrubber', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Reviews draft invoices for billing errors before submission.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        if (drafts.isEmpty)
          const Center(child: Text('✅ No draft invoices to review. All clear!'))
        else
          ...drafts.map((inv) {
            final issues = <String>[];
            if ((inv['diagnosis_codes'] as List?)?.isEmpty ?? true) issues.add('⚠️ Missing ICD-10 diagnosis code');
            if ((inv['procedure_codes'] as List?)?.isEmpty ?? true) issues.add('⚠️ Missing CPT procedure code');
            if ((inv['total_amount'] as num?)?.toDouble() == 0) issues.add('⚠️ Total amount is \$0.00');
            if (inv['date_of_service'] == null) issues.add('⚠️ Missing date of service');

            final patient = inv['patients'] as Map<String, dynamic>?;
            final name = patient != null
                ? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim()
                : 'Unknown';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: issues.isEmpty ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(issues.isEmpty ? Icons.check_circle : Icons.warning, color: issues.isEmpty ? Colors.green : Colors.orange),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    if (issues.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...issues.map((iss) => Text(iss, style: TextStyle(color: Colors.orange[800], fontSize: 13))),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text('✅ Ready to submit', style: TextStyle(color: Colors.green)),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
