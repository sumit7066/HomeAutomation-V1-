import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onAuthSuccess;

  const LoginScreen({
    super.key,
    required this.apiService,
    required this.onAuthSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _showServerConfig = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = widget.apiService.baseUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isError
                ? Colors.red.withValues(alpha: 0.9)
                : const Color(0xff667eea).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white24,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // First save Server URL if shown
      if (_showServerConfig) {
        await widget.apiService.updateServerUrl(_serverUrlController.text.trim());
      }

      if (_isLogin) {
        final data = await widget.apiService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await widget.apiService.setSession(data['token'], data['user']);
        _showToast("Welcome back, ${data['user']['name']}!");
      } else {
        final data = await widget.apiService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await widget.apiService.setSession(data['token'], data['user']);
        _showToast("Account created successfully! Welcome, ${data['user']['name']}!");
      }

      widget.onAuthSuccess();
    } catch (e) {
      _showToast(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testServerConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      _showToast("Please enter a Server URL to test", isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    final isOnline = await widget.apiService.testConnection(url);
    setState(() => _isLoading = false);

    if (isOnline) {
      _showToast("Successfully connected to Server!");
    } else {
      _showToast("Failed to connect to Server. Please double check IP and port.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff0d1b2a),
              Color(0xff1b263b),
              Color(0xff415a77),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Logo
                  const Icon(
                    Icons.home_max_outlined,
                    size: 80,
                    color: Color(0xff667eea),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "SmartHome",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your smart home network",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Glassmorphic Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isLogin ? "Welcome Back" : "Create Account",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              if (!_isLogin) ...[
                                _buildTextField(
                                  controller: _nameController,
                                  label: "Full Name",
                                  icon: Icons.person_outline,
                                  validator: (v) => v!.isEmpty ? "Name is required" : null,
                                ),
                                const SizedBox(height: 16),
                              ],

                              _buildTextField(
                                controller: _emailController,
                                label: "Email",
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v!.isEmpty) return "Email is required";
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                    return "Enter a valid email";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildTextField(
                                controller: _passwordController,
                                label: "Password",
                                icon: Icons.lock_outline,
                                obscureText: true,
                                validator: (v) => v!.length < 6 ? "Password must be >= 6 chars" : null,
                              ),
                              const SizedBox(height: 24),

                              // Auth Button
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xff667eea),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _handleAuth,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xff667eea),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        _isLogin ? "Log In" : "Sign Up",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 16),

                              // Toggle Login / Signup
                              GestureDetector(
                                onTap: () => setState(() => _isLogin = !_isLogin),
                                child: Text(
                                  _isLogin
                                      ? "Don't have an account? Sign up"
                                      : "Already have an account? Log in",
                                  style: const TextStyle(
                                    color: Color(0xff90e0ef),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Toggle Server Config Button
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showServerConfig = !_showServerConfig);
                    },
                    icon: Icon(
                      _showServerConfig ? Icons.arrow_drop_up : Icons.settings_outlined,
                      color: Colors.white70,
                    ),
                    label: Text(
                      _showServerConfig ? "Hide Server Settings" : "Server Configuration",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),

                  // Server Config Expandable Panel
                  if (_showServerConfig) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Server IP Address / Domain",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _serverUrlController,
                                      label: "e.g. http://192.168.29.254:3000",
                                      icon: Icons.lan_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _isLoading ? null : _testServerConnection,
                                    tooltip: "Test Connection",
                                    icon: const Icon(Icons.flash_on),
                                    color: Colors.amberAccent,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff667eea), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
