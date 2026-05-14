import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/shimmer_loading.dart';

enum _FieldType { text, dropdown, date }

class _ProfileField {
  final String key;
  final String label;
  final String section;
  final _FieldType type;
  final List<String>? options;
  const _ProfileField({
    required this.key,
    required this.label,
    required this.section,
    this.type = _FieldType.text,
    this.options,
  });
}

const _kProfileFields = [
  _ProfileField(
    key: 'preferredName',
    label: 'Preferred Name',
    section: 'Personal',
  ),
  _ProfileField(
    key: 'gender',
    label: 'Gender',
    section: 'Personal',
    type: _FieldType.dropdown,
    options: ['Male', 'Female', 'Other'],
  ),
  _ProfileField(
    key: 'dateOfBirth',
    label: 'Date of Birth',
    section: 'Personal',
    type: _FieldType.date,
  ),
  _ProfileField(
    key: 'placeOfBirth',
    label: 'Place of Birth',
    section: 'Personal',
  ),
  _ProfileField(key: 'nationality', label: 'Nationality', section: 'Personal'),
  _ProfileField(
    key: 'stateOfOrigin',
    label: 'State of Origin',
    section: 'Personal',
  ),
  _ProfileField(
    key: 'localGovernment',
    label: 'Local Government',
    section: 'Personal',
  ),
  _ProfileField(key: 'religion', label: 'Religion', section: 'Personal'),
  _ProfileField(
    key: 'maritalStatus',
    label: 'Marital Status',
    section: 'Personal',
    type: _FieldType.dropdown,
    options: ['Single', 'Married', 'Divorced', 'Widowed'],
  ),
  _ProfileField(key: 'height', label: 'Height', section: 'Physical'),
  _ProfileField(key: 'lastWeight', label: 'Last Weight', section: 'Physical'),
  _ProfileField(key: 'skinTone', label: 'Skin Tone', section: 'Physical'),
  _ProfileField(
    key: 'bloodGroup',
    label: 'Blood Group',
    section: 'Physical',
    type: _FieldType.dropdown,
    options: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  ),
  _ProfileField(
    key: 'genotype',
    label: 'Genotype',
    section: 'Physical',
    type: _FieldType.dropdown,
    options: ['AA', 'AS', 'SS', 'AC', 'SC'],
  ),
  _ProfileField(key: 'waistSize', label: 'Waist Size', section: 'Physical'),
  _ProfileField(
    key: 'trouserLength',
    label: 'Trouser Length',
    section: 'Physical',
  ),
  _ProfileField(key: 'shoeSize', label: 'Shoe Size', section: 'Physical'),
  _ProfileField(
    key: 'shirtSize',
    label: 'Shirt Size',
    section: 'Physical',
    type: _FieldType.dropdown,
    options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'],
  ),
  _ProfileField(
    key: 'drinkAlcohol',
    label: 'Drink Alcohol',
    section: 'Lifestyle',
    type: _FieldType.dropdown,
    options: ['Yes', 'No', 'Occasionally'],
  ),
  _ProfileField(
    key: 'smoke',
    label: 'Smoke',
    section: 'Lifestyle',
    type: _FieldType.dropdown,
    options: ['Yes', 'No', 'Occasionally'],
  ),
  _ProfileField(key: 'bestMeals', label: 'Best Meals', section: 'Lifestyle'),
  _ProfileField(
    key: 'languages',
    label: 'Languages Spoken',
    section: 'Lifestyle',
  ),
];


class ProfileScreen extends StatefulWidget {
  final String? userId;
  
  const ProfileScreen({super.key, this.userId});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final Map<String, TextEditingController> _extCtrls = {};
  final Map<String, String?> _dropdownValues = {};

  bool _loadingProfile = true;
  bool _savingBasic = false;
  bool _savingExtended = false;
  bool _uploadingAvatar = false;
  String? _savedMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    for (final f in _kProfileFields) {
      if (f.type == _FieldType.text || f.type == _FieldType.date) {
        _extCtrls[f.key] = TextEditingController();
      }
    }
    _populateBasic();
    _loadExtendedProfile();
  }

  void _populateBasic() {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    _firstNameCtrl.text = user.firstName;
    _lastNameCtrl.text = user.lastName;
    _bioCtrl.text = user.bio ?? '';
    _phoneCtrl.text = user.phone ?? '';
    _locationCtrl.text = user.location ?? '';
    _usernameCtrl.text = user.username ?? '';
  }

  Future<void> _loadExtendedProfile() async {
    setState(() => _loadingProfile = true);
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final res = await ApiService.get('/profile', token: token);
      final profileData = (res['profile'] as Map<String, dynamic>?) ?? {};
      for (final f in _kProfileFields) {
        final val = profileData[f.key]?.toString();
        if (f.type == _FieldType.dropdown) {
          setState(() => _dropdownValues[f.key] = val);
        } else {
          _extCtrls[f.key]?.text = val ?? '';
        }
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: _loadExtendedProfile,
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingProfile = false);
      _animCtrl.forward();
    }
  }

  Future<void> _saveBasic() async {
    setState(() {
      _savingBasic = true;
      _savedMessage = null;
    });
    try {
      final authService = context.read<AuthService>();
      final token = authService.token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _savingBasic = false);
        return;
      }
      await ApiService.put(
        '/profile/user',
        token: token,
        body: {
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
        },
      );
      await authService.refreshUser();
      if (mounted) {
        setState(() => _savedMessage = 'Basic info saved!');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _savedMessage = null);
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _saveBasic);
    } catch (_) {
      _showSnack('Failed to save.', isError: true);
    } finally {
      if (mounted) setState(() => _savingBasic = false);
    }
  }

  Future<void> _saveExtended() async {
    setState(() {
      _savingExtended = true;
      _savedMessage = null;
    });
    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _savingExtended = false);
        return;
      }
      final body = <String, dynamic>{};
      for (final f in _kProfileFields) {
        if (f.type == _FieldType.dropdown) {
          final v = _dropdownValues[f.key];
          if (v != null && v.isNotEmpty) body[f.key] = v;
        } else {
          final v = _extCtrls[f.key]?.text.trim();
          if (v != null && v.isNotEmpty) body[f.key] = v;
        }
      }
      await ApiService.put('/profile', token: token, body: body);
      if (mounted) {
        setState(() => _savedMessage = 'Profile details saved!');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _savedMessage = null);
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _saveExtended);
    } catch (_) {
      _showSnack('Failed to save.', isError: true);
    } finally {
      if (mounted) setState(() => _savingExtended = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final authService = context.read<AuthService>();
      final token = authService.token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _uploadingAvatar = false);
        return;
      }
      await ApiService.multipartPost(
        '/profile/avatar',
        fields: {},
        fileField: 'avatar',
        filePath: picked.path,
        token: token,
      );
      await authService.refreshUser();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e);
    } catch (_) {
      _showSnack('Failed to upload avatar.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? ObrohColors.error : ObrohColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _selectDate(String key) async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(_extCtrls[key]?.text ?? '') ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: ObrohColors.gold400,
            onPrimary: ObrohColors.obsidian950,
            surface: ObrohColors.obsidian800,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _extCtrls[key]?.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _bioCtrl,
      _phoneCtrl,
      _locationCtrl,
      _usernameCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _extCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_savedMessage != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ObrohColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ObrohColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _savedMessage!,
                    style: const TextStyle(
                      color: ObrohColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loadingProfile
          ? _buildShimmer()
          : FadeTransition(
              opacity: _fade,
              child: RefreshIndicator(
                color: ObrohColors.gold400,
                onRefresh: _loadExtendedProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarHeader(
                        user: user,
                        uploading: _uploadingAvatar,
                        onTap: _pickAvatar,
                      ),
                      _sectionHeader('Basic Information', Icons.person_rounded),
                      _buildBasicSection(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: LoadingButton(
                          onPressed: _saveBasic,
                          loading: _savingBasic,
                          label: 'Save Basic Info',
                          icon: Icons.save_rounded,
                        ),
                      ),
                      ..._buildExtendedSections(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: LoadingButton(
                          onPressed: _saveExtended,
                          loading: _savingExtended,
                          label: 'Save Profile Details',
                          icon: Icons.save_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBasicSection() {
    return _SectionCard(
      child: Column(
        children: [
          _rowField(_firstNameCtrl, 'First Name', Icons.badge_rounded),
          _div(),
          _rowField(_lastNameCtrl, 'Last Name', Icons.badge_outlined),
          _div(),
          _rowField(_usernameCtrl, 'Username', Icons.alternate_email_rounded),
          _div(),
          _rowField(
            _phoneCtrl,
            'Phone',
            Icons.phone_rounded,
            keyboard: TextInputType.phone,
          ),
          _div(),
          _rowField(_locationCtrl, 'Location', Icons.location_on_rounded),
          _div(),
          _textAreaField(_bioCtrl, 'About / Bio', Icons.notes_rounded),
        ],
      ),
    );
  }

  List<Widget> _buildExtendedSections() {
    const sections = ['Personal', 'Physical', 'Lifestyle'];
    const icons = {
      'Personal': Icons.info_rounded,
      'Physical': Icons.accessibility_new_rounded,
      'Lifestyle': Icons.favorite_rounded,
    };
    return sections.expand<Widget>((section) {
      final fields = _kProfileFields
          .where((f) => f.section == section)
          .toList();
      return [
        _sectionHeader(section, icons[section] ?? Icons.circle),
        _SectionCard(
          child: Column(
            children: fields.asMap().entries.map((e) {
              final isLast = e.key == fields.length - 1;
              final f = e.value;
              return Column(
                children: [
                  if (f.type == _FieldType.dropdown)
                    _dropdownField(f.key, f.label, f.options!)
                  else if (f.type == _FieldType.date)
                    _dateField(f.key, f.label)
                  else
                    _rowField(_extCtrls[f.key]!, f.label, null),
                  if (!isLast) _div(),
                ],
              );
            }).toList(),
          ),
        ),
      ];
    }).toList();
  }

  Widget _buildShimmer() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: const [
        ShimmerLoading(height: 130, borderRadius: 16),
        SizedBox(height: 16),
        ShimmerLoading(height: 300, borderRadius: 16),
        SizedBox(height: 16),
        ShimmerLoading(height: 280, borderRadius: 16),
        SizedBox(height: 16),
        ShimmerLoading(height: 200, borderRadius: 16),
      ],
    ),
  );

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Row(
      children: [
        Icon(icon, color: ObrohColors.gold400, size: 15),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: ObrohColors.foreground.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );

  Widget _rowField(
    TextEditingController ctrl,
    String label,
    IconData? icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: ObrohColors.gold400.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextFormField(
              controller: ctrl,
              keyboardType: keyboard,
              style: const TextStyle(
                color: ObrohColors.foreground,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textAreaField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: ObrohColors.gold400.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: 3,
            style: const TextStyle(color: ObrohColors.foreground, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tell the family about yourself...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField(String key, String label, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DropdownButtonFormField<String>(
        initialValue: _dropdownValues[key],
        dropdownColor: ObrohColors.obsidian800,
        style: const TextStyle(color: ObrohColors.foreground, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: ObrohColors.foreground.withValues(alpha: 0.4),
            fontSize: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(
                  o,
                  style: const TextStyle(color: ObrohColors.foreground),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _dropdownValues[key] = v),
        hint: Text(
          'Select $label',
          style: TextStyle(
            color: ObrohColors.foreground.withValues(alpha: 0.3),
            fontSize: 13,
          ),
        ),
        icon: Icon(
          Icons.expand_more_rounded,
          color: ObrohColors.foreground.withValues(alpha: 0.3),
          size: 20,
        ),
      ),
    );
  }

  Widget _dateField(String key, String label) {
    final val = _extCtrls[key]?.text ?? '';
    return InkWell(
      onTap: () => _selectDate(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: ObrohColors.gold400.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: ObrohColors.foreground.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    val.isNotEmpty ? val : 'Tap to select',
                    style: TextStyle(
                      fontSize: 14,
                      color: val.isNotEmpty
                          ? ObrohColors.foreground
                          : ObrohColors.foreground.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: ObrohColors.foreground.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _div() => Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: ObrohColors.gold400.withValues(alpha: 0.06),
  );
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: ObrohColors.obsidian800.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ObrohColors.gold400.withValues(alpha: 0.1)),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
  );
}

// ─── Avatar Header ────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final dynamic user;
  final bool uploading;
  final VoidCallback onTap;
  const _AvatarHeader({
    required this.user,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 260,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 132,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ObrohColors.gold400.withValues(alpha: 0.14),
                    ObrohColors.gold500.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                  color: ObrohColors.gold400.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              top: 68,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ObrohColors.gold200,
                      ObrohColors.gold400,
                      ObrohColors.gold600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ObrohColors.gold400.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.2),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    color: ObrohColors.obsidian900.withValues(alpha: 0.94),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          uploading
                              ? Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ObrohColors.obsidian800,
                                    border: Border.all(
                                      color: ObrohColors.gold400.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          ObrohColors.gold400,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : AvatarCircle(
                                  imageUrl: user?.profileImage,
                                  initials: user?.initials ?? '??',
                                  size: 96,
                                ),
                          GestureDetector(
                            onTap: uploading ? null : onTap,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    ObrohColors.gold400,
                                    ObrohColors.gold600,
                                  ],
                                ),
                                border: Border.all(
                                  color: ObrohColors.obsidian950,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: ObrohColors.obsidian950,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (user?.fullName != null)
                        Text(
                          user.fullName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ObrohColors.foreground,
                            letterSpacing: 0.4,
                          ),
                        ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                      if (user?.badges != null &&
                          (user.badges as List).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: (user.badges as List)
                              .map<Widget>(
                                (b) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ObrohColors.gold400.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: ObrohColors.gold400.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    b.label ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: ObrohColors.gold400,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
