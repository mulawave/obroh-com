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
  final _additionalInfoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  int _step = 1;
  String _selectedBranch = '';
  String _selectedRelationship = '';
  bool _agreeTerms = false;

  List<_RegistrationBranch> _branches = const [];
  bool _loadingBranches = true;
  String? _branchesError;

  int _captchaA = 0;
  int _captchaB = 0;

  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
    _loadRegistrationBranches();
  }

  void _generateCaptcha() {
    final seed = DateTime.now().microsecondsSinceEpoch;
    _captchaA = (seed % 9) + 1;
    _captchaB = ((seed ~/ 10) % 9) + 1;
    _captchaCtrl.clear();
  }

  Future<void> _loadRegistrationBranches() async {
    try {
      final res = await ApiService.get('/family-tree/registration-branches');
      final raw = (res['branches'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _branches = raw
            .map((b) => _RegistrationBranch.fromJson(b))
            .toList(growable: false);
        _branchesError = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _branches = const [];
        _branchesError = e.message;
      });
    } catch (_) {
      setState(() {
        _branches = const [];
        _branchesError = 'Unable to load lineage branches right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingBranches = false);
      }
    }
  }

  bool _validateCurrentStep() {
    setState(() => _error = null);

    if (_step == 1) {
      if (_firstNameCtrl.text.trim().isEmpty ||
          _lastNameCtrl.text.trim().isEmpty ||
          _emailCtrl.text.trim().isEmpty ||
          !_emailCtrl.text.contains('@')) {
        setState(
          () => _error = 'Please complete all required personal details.',
        );
        return false;
      }
      return true;
    }

    if (_step == 2) {
      return true;
    }

    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Password is required.');
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return false;
    }
    if (_confirmCtrl.text != _passwordCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return false;
    }
    if (!_agreeTerms) {
      setState(
        () => _error = 'You must agree to the terms and privacy policy.',
      );
      return false;
    }
    final expected = _captchaA + _captchaB;
    final parsed = int.tryParse(_captchaCtrl.text.trim());
    if (parsed != expected) {
      setState(
        () => _error = 'Security check failed. Please solve the challenge.',
      );
      return false;
    }

    return true;
  }

  Future<void> _handleContinueOrSubmit() async {
    if (!_validateCurrentStep()) return;
    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }

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
        branch: _selectedBranch,
        relationship: _selectedRelationship,
        additionalInfo: _additionalInfoCtrl.text.trim(),
      );
      setState(() {
        _success = msg;
        _step = 4;
      });
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
    _additionalInfoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _captchaCtrl.dispose();
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
            child: _step == 4 && _success != null
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

                        _buildStepIndicator(),
                        const SizedBox(height: 20),

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

                        if (_step == 1) _buildStepOne(),
                        if (_step == 2) _buildStepTwo(),
                        if (_step == 3) _buildStepThree(),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            if (_step > 1) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() => _step -= 1),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: ObrohColors.gold400.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    foregroundColor: ObrohColors.foreground60,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Back'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: LoadingButton(
                                onPressed: _handleContinueOrSubmit,
                                loading: _loading,
                                label: _step < 3
                                    ? 'Continue'
                                    : 'Submit Request',
                                icon: _step < 3
                                    ? Icons.arrow_forward_rounded
                                    : Icons.person_add_rounded,
                              ),
                            ),
                          ],
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

  Widget _buildStepIndicator() {
    Widget stepChip(int number, String label) {
      final isCurrent = _step == number;
      final isDone = _step > number;
      final bg = isCurrent
          ? ObrohColors.gold400.withValues(alpha: 0.14)
          : isDone
          ? ObrohColors.gold400.withValues(alpha: 0.08)
          : ObrohColors.obsidian800;
      final fg = isCurrent || isDone
          ? ObrohColors.gold300
          : ObrohColors.foreground40;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ObrohColors.gold400.withValues(
              alpha: isCurrent ? 0.35 : 0.15,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDone)
              const Icon(
                Icons.check_circle,
                size: 14,
                color: ObrohColors.gold300,
              )
            else
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: fg,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        stepChip(1, 'Personal Info'),
        stepChip(2, 'Lineage Details'),
        stepChip(3, 'Security'),
      ],
    );
  }

  Widget _buildStepOne() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GoldTextField(
                controller: _firstNameCtrl,
                label: 'First Name',
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GoldTextField(
                controller: _lastNameCtrl,
                label: 'Last Name',
                textInputAction: TextInputAction.next,
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
        ),
        const SizedBox(height: 16),
        GoldTextField(
          controller: _phoneCtrl,
          label: 'Phone Number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        GoldTextField(
          controller: _locationCtrl,
          label: 'Current Location',
          prefixIcon: Icons.location_on_outlined,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ObrohColors.gold400.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ObrohColors.gold400.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            'Lineage Verification: This helps the Council of Elders verify your connection to the Obroh dynasty.',
            style: TextStyle(color: ObrohColors.foreground60, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Family Branch',
          style: TextStyle(
            color: ObrohColors.foreground60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedBranch.isEmpty ? null : _selectedBranch,
          dropdownColor: ObrohColors.obsidian900,
          decoration: InputDecoration(
            filled: true,
            fillColor: ObrohColors.obsidian800.withValues(alpha: 0.85),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ObrohColors.gold400.withValues(alpha: 0.2),
              ),
            ),
          ),
          hint: Text(
            _loadingBranches
                ? 'Loading lineage branches...'
                : 'Select your family branch',
            style: TextStyle(color: ObrohColors.foreground40),
          ),
          items: [
            ..._branches.map((branch) {
              final indent = branch.level > 0 ? '${'  ' * branch.level}- ' : '';
              return DropdownMenuItem<String>(
                value: branch.id,
                child: Text(
                  '$indent${branch.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const DropdownMenuItem<String>(
              value: '__unknown__',
              child: Text(
                'Unknown / Need Assistance',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: _loadingBranches
              ? null
              : (v) => setState(() => _selectedBranch = v ?? ''),
        ),
        if (_branchesError != null) ...[
          const SizedBox(height: 8),
          Text(
            _branchesError!,
            style: TextStyle(
              color: ObrohColors.gold300.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Relationship to Dynasty',
          style: TextStyle(
            color: ObrohColors.foreground60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedRelationship.isEmpty
              ? null
              : _selectedRelationship,
          dropdownColor: ObrohColors.obsidian900,
          decoration: InputDecoration(
            filled: true,
            fillColor: ObrohColors.obsidian800.withValues(alpha: 0.85),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ObrohColors.gold400.withValues(alpha: 0.2),
              ),
            ),
          ),
          hint: Text(
            'Select relationship',
            style: TextStyle(color: ObrohColors.foreground40),
          ),
          items: const [
            DropdownMenuItem<String>(
              value: 'direct',
              child: Text('Direct Descendant'),
            ),
            DropdownMenuItem<String>(
              value: 'marriage',
              child: Text('By Marriage'),
            ),
            DropdownMenuItem<String>(
              value: 'extended',
              child: Text('Extended Family'),
            ),
            DropdownMenuItem<String>(
              value: 'researcher',
              child: Text('Genealogy Researcher'),
            ),
          ],
          onChanged: (v) => setState(() => _selectedRelationship = v ?? ''),
        ),
        const SizedBox(height: 16),
        GoldTextField(
          controller: _additionalInfoCtrl,
          label: 'Additional Information',
          hint:
              'Share details that may help verify your lineage (parent names, village of origin, known relatives)...',
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    return Column(
      children: [
        GoldPasswordField(
          controller: _passwordCtrl,
          label: 'Password',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        GoldPasswordField(
          controller: _confirmCtrl,
          label: 'Confirm Password',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: CheckboxListTile(
            value: _agreeTerms,
            onChanged: (v) => setState(() => _agreeTerms = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I agree to the Terms of Service and Privacy Policy, and confirm my information is accurate.',
              style: TextStyle(
                color: ObrohColors.foreground.withValues(alpha: 0.65),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ObrohColors.obsidian800.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ObrohColors.gold400.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Check',
                style: TextStyle(
                  color: ObrohColors.gold300,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Solve: $_captchaA + $_captchaB = ?',
                        style: const TextStyle(
                          color: ObrohColors.foreground,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _generateCaptcha,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: ObrohColors.gold300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GoldTextField(
                controller: _captchaCtrl,
                label: 'Your Answer',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleContinueOrSubmit(),
              ),
            ],
          ),
        ),
      ],
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
          label: 'Go to Sign In',
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }
}

class _RegistrationBranch {
  final String id;
  final String name;
  final int level;

  const _RegistrationBranch({
    required this.id,
    required this.name,
    required this.level,
  });

  factory _RegistrationBranch.fromJson(Map<String, dynamic> json) {
    return _RegistrationBranch(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      level: int.tryParse(json['level']?.toString() ?? '0') ?? 0,
    );
  }
}
