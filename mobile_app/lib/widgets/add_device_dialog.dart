import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class AddDeviceDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onSuccess;

  const AddDeviceDialog({
    super.key,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  int _step = 1;
  String _deviceToken = '';
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rmacController = TextEditingController();
  int _relayCount = 8;

  @override
  void dispose() {
    _nameController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _rmacController.dispose();
    super.dispose();
  }

  Future<void> _generateToken() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await widget.apiService.createDeviceToken(
        name: _nameController.text.trim(),
        wifiSSID: _ssidController.text.trim(),
        wifiPassword: _passwordController.text.trim(),
        relayCount: _relayCount,
        remoteMac: _rmacController.text.trim(),
      );

      setState(() {
        _deviceToken = res['device']['token'];
        _step = 2;
      });
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: _deviceToken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Token copied to clipboard!"),
        backgroundColor: Color(0xff667eea),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        backgroundColor: const Color(0xff1b263b).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Add New Device",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: _step == 1 ? _buildStep1() : _buildStep2(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(
            controller: _nameController,
            label: "Device Name (e.g. Living Room)",
            hint: "Living Room Relays",
            validator: (v) => v!.isEmpty ? "Device name is required" : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _ssidController,
            label: "WiFi SSID",
            hint: "Home Network Name",
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _passwordController,
            label: "WiFi Password",
            hint: "Network Password",
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _rmacController,
            label: "Remote MAC Address (Optional)",
            hint: "XX:XX:XX:XX:XX:XX",
          ),
          const SizedBox(height: 16),
          const Text(
            "Relay Count",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _relayCount,
            dropdownColor: const Color(0xff0d1b2a),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            items: [1, 2, 4, 8, 12, 16].map((int val) {
              return DropdownMenuItem<int>(
                value: val,
                child: Text("$val Relay${val > 1 ? 's' : ''}"),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _relayCount = val);
            },
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xff667eea),
                  ),
                )
              : ElevatedButton(
                  onPressed: _generateToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    "Generate Token",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 64,
        ),
        const SizedBox(height: 16),
        const Text(
          "Device Added Successfully!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Enter this token in your ESP32 configuration portal:",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            _deviceToken,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _copyToken,
          icon: const Icon(Icons.copy, size: 18),
          label: const Text("Copy Token"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xff667eea), width: 1.5),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
