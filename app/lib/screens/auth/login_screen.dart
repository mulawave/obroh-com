import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/content_ratings_strip.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/gold_text_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection failed. Please check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ObsidianBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Crest ───────────────────────────────────────
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ObrohColors.gold300,
                                ObrohColors.gold500,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ObrohColors.gold500.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: ObrohColors.obsidian950,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 20),

                        ShaderMask(
                          shaderCallback: (bounds) => ObrohColors
                              .goldBorderGradient
                              .createShader(bounds),
                          child: const Text(
                            'OBROH',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'DYNASTY MEMBER PORTAL',
                          style: TextStyle(
                            fontSize: 10,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.35,
                            ),
                            letterSpacing: 3.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 44),

                        // ── Error ──────────────────────────────────────
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: ObrohColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ObrohColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: ObrohColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // ── Email ──────────────────────────────────────
                        GoldTextField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Password ───────────────────────────────────
                        GoldPasswordField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
                        ),
                        const SizedBox(height: 28),

                        // ── Sign In button ─────────────────────────────
                        LoadingButton(
                          onPressed: _handleLogin,
                          loading: _loading,
                          label: 'Sign In',
                          icon: Icons.login_rounded,
                        ),
                        const SizedBox(height: 20),

                        // ── Register link ──────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: ObrohColors.foreground.withValues(
                                  alpha: 0.35,
                                ),
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: const Text('Request Access'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const ContentRatingsStrip(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
