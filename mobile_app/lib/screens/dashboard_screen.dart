import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../widgets/device_card.dart';
import '../widgets/add_device_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _devices = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchDevices(showLoader: true);
    // Poll devices every 3 seconds, matching the React client
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchDevices(showLoader: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDevices({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final devices = await widget.apiService.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If unauthorized, trigger logout
      if (e.toString().contains('authenticate') || e.toString().contains('Unauthorized')) {
        _pollingTimer?.cancel();
        widget.onLogout();
      }
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleRelay(String deviceId, int relayIndex, bool state) async {
    // Optimistic UI update: Toggle switch state locally first
    setState(() {
      _devices = _devices.map((device) {
        if (device['_id'] == deviceId) {
          final Map<String, dynamic> updatedRelays = Map<String, dynamic>.from(device['relays'] ?? {});
          updatedRelays[relayIndex.toString()] = state;
          return {
            ...device,
            'relays': updatedRelays,
          };
        }
        return device;
      }).toList();
    });

    try {
      final success = await widget.apiService.controlRelay(deviceId, relayIndex, state);
      if (!success) throw Exception("Server rejected control command");
    } catch (e) {
      // Revert: fetch devices again from backend
      _showToast("Failed to update relay: ${e.toString().replaceAll('Exception: ', '')}", isError: true);
      _fetchDevices(showLoader: false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isError ? Colors.redAccent.withValues(alpha: 0.9) : const Color(0xff667eea).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAddDeviceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddDeviceDialog(
        apiService: widget.apiService,
        onSuccess: () => _fetchDevices(showLoader: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.apiService.user?['name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b2a),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.house_siding, color: Color(0xff667eea)),
            const SizedBox(width: 8),
            const Text(
              "SmartHome",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Center(
            child: Text(
              "Hi, $userName",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            tooltip: "Logout",
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff0d1b2a),
              Color(0xff1b263b),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => _fetchDevices(showLoader: false),
          color: const Color(0xff667eea),
          backgroundColor: const Color(0xff0d1b2a),
          child: _isLoading
              ? const Center(
                  child: SpinKitFadingCircle(
                    color: Color(0xff667eea),
                    size: 60.0,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    // Dashboard Header Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "My Devices",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Manage your smart home network",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAddDeviceDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Device"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Devices Grid / Empty State
                    _devices.isEmpty ? _buildEmptyState() : _buildDevicesList(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.developer_board,
            size: 80,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            "No devices found",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "Click the 'Add Device' button to connect your first ESP32 board.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return DeviceCard(
          key: ValueKey(device['_id']),
          device: device,
          onToggle: _toggleRelay,
        );
      },
    );
  }
}
