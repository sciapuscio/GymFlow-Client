import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen blocking page shown when the installed app version is
/// below the minimum required by the server. The user CANNOT dismiss it
/// or navigate back — they must update first.
class ForceUpdateScreen extends StatelessWidget {
  final String currentVersion;
  final String minVersion;
  final String? storeUrl;

  const ForceUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.minVersion,
    this.storeUrl,
  });

  Future<void> _openStore() async {
    final url = storeUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // block Android back button
      child: Scaffold(
        backgroundColor: const Color(0xFF080810),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00F5D4).withAlpha(20),
                    border: Border.all(
                      color: const Color(0xFF00F5D4).withAlpha(60),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 48,
                    color: Color(0xFF00F5D4),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Actualización requerida',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF0F0F0),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Tu versión de GymFlow está desactualizada y ya no es compatible con el sistema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: const Color(0xFFF0F0F0).withAlpha(160),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),

                // Version info card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1EFFFFFF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _VersionBadge(
                        label: 'Tu versión',
                        version: currentVersion,
                        accent: const Color(0xFFEF4444),
                      ),
                      Container(width: 1, height: 36, color: const Color(0x1EFFFFFF)),
                      _VersionBadge(
                        label: 'Requerida',
                        version: minVersion,
                        accent: const Color(0xFF00F5D4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: storeUrl != null ? _openStore : null,
                    icon: Icon(
                      Platform.isIOS ? Icons.apple : Icons.shop_rounded,
                      size: 20,
                    ),
                    label: const Text('Actualizar ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5D4),
                      foregroundColor: const Color(0xFF080810),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Actualizá desde la tienda para seguir usando GymFlow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: const Color(0xFFF0F0F0).withAlpha(80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color accent;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFF0F0F0).withAlpha(120),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
