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

final goRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.uri.toString() == '/login';

    if (session == null && !isLoggingIn) {
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
  ],
);
