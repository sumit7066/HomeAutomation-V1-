import 'dart:ui';
import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final Function(String deviceId, int relayIndex, bool state) onToggle;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final String deviceId = device['_id'] ?? '';
    final String name = device['name'] ?? 'Smart Device';
    final String token = device['token'] ?? '';
    final String status = device['status'] ?? 'offline';
    final bool isOnline = status == 'online';
    final int relayCount = device['relayCount'] ?? 8;
    
    // Extract relays map from API response. It could be Map<String, dynamic> or similar.
    final Map<String, dynamic> relays = device['relays'] != null 
        ? Map<String, dynamic>.from(device['relays']) 
        : {};

    final String tokenPreview = token.length >= 8 ? token.substring(0, 8) : token;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: $tokenPreview...",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(isOnline),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Relays Grid/List
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: relayCount,
                  itemBuilder: (context, index) {
                    final bool state = relays[index.toString()] == true;
                    return _buildRelayItem(index, state, isOnline, deviceId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline 
            ? const Color(0xff2a9d8f).withValues(alpha: 0.2) 
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline 
              ? const Color(0xff2a9d8f).withValues(alpha: 0.4) 
              : Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 13,
            color: isOnline ? const Color(0xff2a9d8f) : Colors.white60,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              color: isOnline ? const Color(0xff2a9d8f) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayItem(int index, bool state, bool isOnline, String deviceId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: state && isOnline
            ? const Color(0xff667eea).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state && isOnline
              ? const Color(0xff667eea).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Relay ${index + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state ? "ON" : "OFF",
                  style: TextStyle(
                    color: state && isOnline ? const Color(0xffe9c46a) : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: state,
              activeThumbColor: const Color(0xff667eea),
              activeTrackColor: const Color(0xff667eea).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.white60,
              inactiveTrackColor: Colors.white10,
              onChanged: isOnline 
                  ? (value) => onToggle(deviceId, index, value) 
                  : null, // Disabled if offline
            ),
          ),
        ],
      ),
    );
  }
}
