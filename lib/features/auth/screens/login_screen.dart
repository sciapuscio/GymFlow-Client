import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth_provider.dart';
import '../../../core/constants.dart';
import '../../../core/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _gymCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _obscure = true;

  /// True when the email field currently has the @@ dev prefix.
  bool _devMode = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final isDev = _emailCtrl.text.startsWith('@@');
    if (isDev != _devMode) {
      setState(() => _devMode = isDev);
    }
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onEmailChanged);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _gymCtrl.dispose();
    super.dispose();
  }

  /// Strips the @@ prefix from the email and returns the real address.
  String get _cleanEmail {
    final raw = _emailCtrl.text.trim();
    return raw.startsWith('@@') ? raw.substring(2) : raw;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture provider BEFORE any async gaps
    final auth = context.read<AuthProvider>();

    // ── Environment switch ──────────────────────────────────────────────────
    final isDev = _emailCtrl.text.trim().startsWith('@@');
    AppConstants.setEnvironment(dev: isDev);
    await TokenStorage.writeEnvironment(isDev);
    // ───────────────────────────────────────────────────────────────────────

    final ok = await auth.login(
      email:   _cleanEmail,
      password: _passCtrl.text,
      gymSlug: _gymCtrl.text.trim().toLowerCase(),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al iniciar sesión'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main scrollable form ──────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // ── Logo ──────────────────────────────────────────────
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F5D4), Color(0xFFFF6B35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'GF',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF080810),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'GymFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Color(0xFFF0F0F0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Iniciá sesión con tu cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                    ),
                    const SizedBox(height: 44),

                    // ── Email ─────────────────────────────────────────────
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Color(0xFFF0F0F0)),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'juan@microssfit.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 20, color: Color(0xFF888888)),
                        // Subtle amber tint on the border when in dev mode
                        enabledBorder: _devMode
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                              )
                            : null,
                        focusedBorder: _devMode
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
                              )
                            : null,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresá tu email';
                        final clean = v.trim().startsWith('@@') ? v.trim().substring(2) : v.trim();
                        if (!clean.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Gym slug ──────────────────────────────────────────
                    TextFormField(
                      controller: _gymCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Color(0xFFF0F0F0)),
                      decoration: const InputDecoration(
                        labelText: 'Código del gimnasio',
                        hintText: 'microssfit',
                        prefixIcon: Icon(Icons.fitness_center_outlined, size: 20, color: Color(0xFF888888)),
                        helperText: 'Tu gym te proporciona este código',
                        helperStyle: TextStyle(color: Color(0xFF666666), fontSize: 12),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresá el código del gym';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──────────────────────────────────────────
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Color(0xFFF0F0F0)),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF888888)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF888888),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresá tu contraseña';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // ── Submit ────────────────────────────────────────────
                    ElevatedButton(
                      onPressed: auth.loading ? null : _submit,
                      child: auth.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF080810)),
                              ),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 20),

                    // ── Register link ─────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: RichText(
                          text: const TextSpan(
                            text: '¿No tenés cuenta? ',
                            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Registrate',
                                style: TextStyle(
                                  color: Color(0xFF00F5D4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Términos y condiciones ────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(
                            'https://sistema.gymflow.com.ar/web/terminos.html',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text(
                          'Términos y Condiciones',
                          style: TextStyle(
                            color: Color(0xFF555566),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF555566),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── DEV environment badge (top-right corner) ──────────────────
            if (_devMode)
              Positioned(
                top: 8,
                right: 12,
                child: _DevBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated badge shown when @@ prefix is detected.
class _DevBadge extends StatefulWidget {
  const _DevBadge();

  @override
  State<_DevBadge> createState() => _DevBadgeState();
}

class _DevBadgeState extends State<_DevBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.science_outlined, size: 13, color: Color(0xFF080810)),
            SizedBox(width: 4),
            Text(
              'DESARROLLO',
              style: TextStyle(
                color: Color(0xFF080810),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
