import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/patients/patient_list_screen.dart';
import 'screens/patients/patient_profile_screen.dart';
import 'screens/patients/add_patient_screen.dart';
import 'screens/patients/import_patients_screen.dart';
import 'screens/clinical/note_editor.dart';
import 'screens/clinical/ambient_scribe_screen.dart';
import 'screens/appointments/appointments_screen.dart';
import 'screens/billing/billing_screen.dart';

import 'screens/patients/public_intake_screen.dart';

class AimsRouter {
  static bool isDemoMode = false;
}

final goRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (AimsRouter.isDemoMode) return null; // Bypass for demo
    
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.uri.toString() == '/login';
    final isPublicIntake = state.uri.toString().startsWith('/intake/');

    if (session == null && !isLoggingIn && !isPublicIntake) {
      return '/login';
    }
    if (session != null && isLoggingIn) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    // Patient Routes
    GoRoute(
      path: '/patients',
      builder: (context, state) => const PatientListScreen(),
    ),
    GoRoute(
      path: '/intake/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PublicIntakeScreen(patientId: id);
      },
    ),
    GoRoute(
      path: '/patients/new',
      builder: (context, state) => const AddPatientScreen(),
    ),
    GoRoute(
      path: '/patients/import',
      builder: (context, state) => const ImportPatientsScreen(),
    ),
    GoRoute(
      path: '/patients/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PatientProfileScreen(patientId: id);
      },
    ),
    // Clinical Note Routes
    GoRoute(
      path: '/notes/new',
      builder: (context, state) {
        final patientId = state.uri.queryParameters['patientId'] ?? '';
        return NoteEditorScreen(patientId: patientId);
      },
    ),
    // Ambient Scribe
    GoRoute(
      path: '/scribe',
      builder: (context, state) {
        final patientId = state.uri.queryParameters['patientId'] ?? '';
        final patientName = state.uri.queryParameters['name'] ?? 'Patient';
        return AmbientScribeScreen(patientId: patientId, patientName: patientName);
      },
    ),
    // Appointments
    GoRoute(
      path: '/appointments',
      builder: (context, state) => const AppointmentsScreen(),
    ),
    // Billing
    GoRoute(
      path: '/billing',
      builder: (context, state) => const BillingScreen(),
    ),
  ],
);
