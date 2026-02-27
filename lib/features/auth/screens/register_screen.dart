import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gymCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _gymCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      gymSlug: _gymCtrl.text.trim().toLowerCase(),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al registrarse'),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF888888)),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Crear cuenta', style: TextStyle(fontSize: 16, color: Color(0xFFF0F0F0))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingresá tus datos\npara comenzar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF0F0F0),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 32),

                // Nombre
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Color(0xFFF0F0F0)),
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline, size: 20, color: Color(0xFF888888)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá tu nombre' : null,
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Color(0xFFF0F0F0)),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 20, color: Color(0xFF888888)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresá tu email';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Gym slug
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá el código del gym' : null,
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Color(0xFFF0F0F0)),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 6 caracteres',
                    helperStyle: const TextStyle(color: Color(0xFF666666), fontSize: 12),
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
                    if (v == null || v.isEmpty) return 'Ingresá una contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(color: Color(0xFFF0F0F0)),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline, size: 20, color: Color(0xFF888888)),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF080810))),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: RichText(
                      text: const TextSpan(
                        text: '¿Ya tenés cuenta? ',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Iniciá sesión',
                            style: TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
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
