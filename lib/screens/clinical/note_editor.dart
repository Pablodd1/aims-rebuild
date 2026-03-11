import 'package:flutter/material.dart';

class NoteEditorScreen extends StatefulWidget {
  final String patientId;
  final String? noteId; // Null if creating new

  const NoteEditorScreen({super.key, required this.patientId, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hpiController = TextEditingController();
  final _rosController = TextEditingController();
  final _examController = TextEditingController();
  final _planController = TextEditingController();

  // "Red Flags" Validation Tracking
  bool _attemptedSignature = false;
  bool _isSigned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Scribe: SOAP Note'),
        actions: [
          _buildSignatureAction(),
        ],
      ),
      // Advanced EHR Workflow: Split screen to see PREVIOUS notes while writing NEW notes
      body: Row(
        children: [
          // LEFT PANEL: The Current Note Editor
          Expanded(
            flex: 2,
            child: Form(
              key: _formKey,
              autovalidateMode: _attemptedSignature 
                  ? AutovalidateMode.always 
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  _buildSectionCard(
                    title: 'History of Present Illness (HPI)',
                    controller: _hpiController,
                    isRequired: true,
                    isSigned: _isSigned,
                  ),
                  _buildSectionCard(
                    title: 'Review of Systems (ROS)',
                    controller: _rosController,
                    isRequired: false, // Optional example
                    isSigned: _isSigned,
                  ),
                  _buildSectionCard(
                    title: 'Physical Exam',
                    controller: _examController,
                    isRequired: true,
                    isSigned: _isSigned,
                  ),
                  _buildSectionCard(
                    title: 'Assessment & Plan',
                    controller: _planController,
                    isRequired: true,
                    isSigned: _isSigned,
                  ),
                ],
              ),
            ),
          ),
          
          // RIGHT PANEL: Patient History (Previous Notes)
          const VerticalDivider(width: 1),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                   Container(
                     padding: const EdgeInsets.all(16),
                     color: Colors.grey[200],
                     width: double.infinity,
                     child: const Text(
                       'Historical Encounters',
                       style: TextStyle(fontWeight: FontWeight.bold),
                     ),
                   ),
                   const Expanded(
                     child: Center(
                       child: Text('Previous notes dynamically load here...'),
                     ),
                   )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Signature Logic & Enforcing Red Flags
  Widget _buildSignatureAction() {
    if (_isSigned) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(child: Text('SIGNED & LOCKED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
      );
    }
    
    return TextButton.icon(
      onPressed: () {
        setState(() => _attemptedSignature = true);
        if (_formKey.currentState!.validate()) {
          // Trigger the Supabase Signature and Lock the note
          _showSignatureDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛑 Red Flags Detected: Missing Form Information. Please complete all required sections.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      icon: const Icon(Icons.edit_document, color: Colors.white),
      label: const Text('Sign Note', style: TextStyle(color: Colors.white)),
    );
  }

  void _showSignatureDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalize Medical Note?'),
        content: const Text('By signing this note, it will be cryptographically locked into the DB audit trail. Any future edits will require a formal Addendum.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isSigned = true);
              // TODO: Trigger Supabase update: status='signed', signed_at=NOW()
            },
            child: const Text('Confirm & Sign'),
          )
        ],
      ),
    );
  }

  // Builder for individual text areas with inline Red Flags
  Widget _buildSectionCard({
    required String title,
    required TextEditingController controller,
    required bool isRequired,
    required bool isSigned,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (isRequired) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              maxLines: null,
              minLines: 3,
              readOnly: isSigned,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                fillColor: isSigned ? Colors.grey[100] : null,
                filled: isSigned,
                hintText: isSigned ? 'Locked' : 'Start typing or use the AI ambient transcriber...',
              ),
              validator: (val) {
                if (isRequired && (val == null || val.trim().isEmpty)) {
                  return '🚨 REQUIRED FIELD: This section cannot be blank for an E&M code claim.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
