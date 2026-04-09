import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔐 HIPAA COMPLIANCE NOTE:
  // These are your Supabase Anon Key and URL. They are safe to include in the client app.
  // NEVER include your Service Role key in this file.
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://zcndcexalrxcgskkxiwq.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjbmRjZXhhbHJ4Y2dza2t4aXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxODQwOTAsImV4cCI6MjA4ODc2MDA5MH0._l6uKhaV5Lg7uZ-sPMJaiUUrn2p_2erEKenuMLZHd1w'),
  );

  runApp(const ProviderScope(child: AimsApp()));
}

class AimsApp extends StatelessWidget {
  const AimsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AIMS Medical Platform',
      routerConfig: goRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0056D2), // Medical Blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0056D2), // Medical Blue
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
    );
  }
}

