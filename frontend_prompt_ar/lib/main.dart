import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:prompt_ar/screens/welcome/welcome_screen.dart';
import 'package:prompt_ar/screens/ar_view/ar_view_screen.dart';
import 'bloc/ar_bloc/ar_bloc.dart';

void main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exception}");
  };

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file: $e");
    debugPrint("Using default configuration");
  }

  // Run the app
  runApp(const PromptARApp());
}

class PromptARApp extends StatelessWidget {
  const PromptARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptAR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/ar': (context) => const ARViewPage(),
      },
    );
  }
}
