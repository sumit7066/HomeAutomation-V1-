import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  await apiService.init();

  runApp(SmartHomeApp(apiService: apiService));
}

class SmartHomeApp extends StatefulWidget {
  final ApiService apiService;

  const SmartHomeApp({
    super.key,
    required this.apiService,
  });

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.apiService.token != null;
  }

  void _onAuthSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() async {
    await widget.apiService.clearSession();
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartHome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xff667eea),
        scaffoldBackgroundColor: const Color(0xff0d1b2a),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff667eea),
          secondary: Color(0xffe9c46a),
          surface: Color(0xff1b263b),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0d1b2a),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _isAuthenticated
            ? DashboardScreen(
                key: const ValueKey('dashboard'),
                apiService: widget.apiService,
                onLogout: _onLogout,
              )
            : LoginScreen(
                key: const ValueKey('login'),
                apiService: widget.apiService,
                onAuthSuccess: _onAuthSuccess,
              ),
      ),
    );
  }
}
