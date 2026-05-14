import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/content_ratings_strip.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/gold_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final msg = await context.read<AuthService>().register(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );
      setState(() => _success = msg);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection failed. Please check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ObsidianBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _success != null
                ? _buildSuccess()
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join the Dynasty',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ObrohColors.gold400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submit your membership request to the Council of Elders.',
                          style: TextStyle(
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.4,
                            ),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ObrohColors.error.withValues(alpha: 0.1),
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
                          const SizedBox(height: 16),
                        ],

                        // Name row
                        Row(
                          children: [
                            Expanded(
                              child: GoldTextField(
                                controller: _firstNameCtrl,
                                label: 'First Name',
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GoldTextField(
                                controller: _lastNameCtrl,
                                label: 'Last Name',
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        GoldTextField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        GoldTextField(
                          controller: _phoneCtrl,
                          label: 'Phone (optional)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        GoldTextField(
                          controller: _locationCtrl,
                          label: 'Location (optional)',
                          prefixIcon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        GoldPasswordField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'At least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        GoldPasswordField(
                          controller: _confirmCtrl,
                          label: 'Confirm Password',
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          validator: (v) {
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        LoadingButton(
                          onPressed: _handleRegister,
                          loading: _loading,
                          label: 'Submit Registration',
                          icon: Icons.person_add_rounded,
                        ),
                        const SizedBox(height: 24),
                        const ContentRatingsStrip(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ObrohColors.success.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: ObrohColors.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Registration Submitted!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ObrohColors.gold400,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _success!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ObrohColors.foreground.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        LoadingButton(
          onPressed: () => Navigator.pop(context),
          label: 'Back to Login',
          icon: Icons.arrow_back_rounded,
        ),
      ],
    );
  }
}
