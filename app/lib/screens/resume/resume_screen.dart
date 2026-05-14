import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/shimmer_loading.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _biography;
  List<Map<String, dynamic>> _books = [];

  bool _loading = true;
  bool _sharing = false;
  bool _openingPdf = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = context.read<AuthService>().token;

    try {
      final results = await Future.wait([
        ApiService.get('/profile', token: token),
        ApiService.get('/portfolio', token: token),
        ApiService.get('/biography', token: token),
        ApiService.get('/books', token: token),
      ]);

      if (!mounted) return;
      final books = _extractBookList(results[3]);

      setState(() {
        _profile = results[0];
        _portfolio = results[1];
        _biography = results[2];
        _books = books;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractBookList(Map<String, dynamic> res) {
    final direct = res['books'];
    if (direct is List) return direct.cast<Map<String, dynamic>>();

    final wrapped = res['data'];
    if (wrapped is List) return wrapped.cast<Map<String, dynamic>>();

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> get _user =>
      (_profile?['user'] as Map<String, dynamic>?) ?? {};

  String? get _portfolioSlug {
    final slug = _portfolio?['slug']?.toString().trim();
    if (slug == null || slug.isEmpty) return null;
    return slug;
  }

  String? get _publicResumeLink {
    final slug = _portfolioSlug;
    if (slug == null) return null;
    return 'https://obroh.com/resume/$slug';
  }

  Future<void> _copyLink() async {
    final link = _publicResumeLink;
    if (link == null) {
      _showInfo('Set your portfolio slug to enable sharing.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showInfo('Public resume link copied.');
  }

  Future<void> _shareLink() async {
    final link = _publicResumeLink;
    if (link == null) {
      _showInfo('Set your portfolio slug to enable sharing.');
      return;
    }

    setState(() => _sharing = true);
    try {
      await Share.share(link, subject: 'My Obroh Resume');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadPdf() async {
    final link = _publicResumeLink;
    if (link == null) {
      _showInfo('Set your portfolio slug to enable PDF download.');
      return;
    }

    setState(() => _openingPdf = true);
    try {
      final uri = Uri.parse(link);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _showInfo('Could not open resume link.');
    } finally {
      if (mounted) setState(() => _openingPdf = false);
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume')),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(height: 110, borderRadius: 16),
              ),
            )
          : FadeTransition(
              opacity: _fade,
              child: RefreshIndicator(
                color: ObrohColors.gold400,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _buildActionsBar(),
                    const SizedBox(height: 14),
                    _buildResumeDocument(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ObrohColors.obsidian800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObrohColors.gold400.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionButton(
            icon: Icons.copy_rounded,
            label: 'Copy Link',
            onTap: _copyLink,
          ),
          _actionButton(
            icon: Icons.share_rounded,
            label: _sharing ? 'Sharing...' : 'Share',
            onTap: _sharing ? null : _shareLink,
          ),
          _actionButton(
            icon: Icons.picture_as_pdf_rounded,
            label: _openingPdf ? 'Opening...' : 'Download PDF',
            onTap: _openingPdf ? null : _downloadPdf,
            filled: true,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled ? ObrohColors.goldGradient : null,
          color: filled ? null : ObrohColors.obsidian900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? ObrohColors.gold500.withValues(alpha: 0.5)
                : ObrohColors.gold400.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? ObrohColors.obsidian950 : ObrohColors.gold400,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled
                    ? ObrohColors.obsidian950
                    : ObrohColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeDocument() {
    final firstName = _user['firstName']?.toString() ?? '';
    final lastName = _user['lastName']?.toString() ?? '';
    final email = _user['email']?.toString() ?? '';
    final phone = _user['phone']?.toString() ?? '';

    final profileInfo = (_profile?['profile'] as Map<String, dynamic>?) ?? {};
    final state = profileInfo['stateOfOrigin']?.toString() ?? '';
    final lga = profileInfo['localGovernment']?.toString() ?? '';

    final profileImage = _user['profileImage']?.toString();
    final summary = _portfolio?['summary']?.toString() ?? '';

    final skills =
        (_portfolio?['skills'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final experiences =
        (_portfolio?['experiences'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final education =
        (_portfolio?['education'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final projects =
        (_portfolio?['projects'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final bioSections =
        (_biography?['sections'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              color: Color(0xFF1E293B),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profileImage != null && profileImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.network(
                      ApiService.imageUrl(profileImage),
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _initialAvatar(firstName, lastName),
                    ),
                  )
                else
                  _initialAvatar(firstName, lastName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName'.trim(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (_user['bio']?.toString().isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _user['bio'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (email.isNotEmpty)
                            _headerInfo(Icons.mail_outline_rounded, email),
                          if (phone.isNotEmpty)
                            _headerInfo(Icons.phone_outlined, phone),
                          if (state.isNotEmpty || lga.isNotEmpty)
                            _headerInfo(
                              Icons.location_on_outlined,
                              '$state${state.isNotEmpty && lga.isNotEmpty ? ', ' : ''}$lga',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.isNotEmpty)
                  _section(
                    icon: Icons.person_outline_rounded,
                    title: 'Professional Summary',
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.6,
                      ),
                    ),
                  ),
                if (bioSections.isNotEmpty)
                  _section(
                    icon: Icons.workspace_premium_outlined,
                    title: 'About Me',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: bioSections.take(2).map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['title']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s['content']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (skills.isNotEmpty)
                  _section(
                    icon: Icons.code_rounded,
                    title: 'Skills',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: skills
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s['name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (_books.isNotEmpty)
                  _section(
                    icon: Icons.menu_book_rounded,
                    title: 'Literary Works',
                    child: Column(
                      children: _books.map((book) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.only(left: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (book['synopsis']
                                            ?.toString()
                                            .isNotEmpty ??
                                        false)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          book['synopsis'].toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF4B5563),
                                            height: 1.45,
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (book['coverImageUrl']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    ApiService.imageUrl(
                                      book['coverImageUrl'].toString(),
                                    ),
                                    width: 42,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (experiences.isNotEmpty)
                  _section(
                    icon: Icons.work_outline_rounded,
                    title: 'Work Experience',
                    child: Column(
                      children: experiences.map((w) {
                        return _timelineBlock(
                          title: w['title']?.toString() ?? '',
                          subtitle: w['company']?.toString() ?? '',
                          dateText: _formatDateRange(
                            w['startDate']?.toString(),
                            w['endDate']?.toString(),
                          ),
                          body: w['description']?.toString(),
                        );
                      }).toList(),
                    ),
                  ),
                if (education.isNotEmpty)
                  _section(
                    icon: Icons.school_outlined,
                    title: 'Education',
                    child: Column(
                      children: education.map((e) {
                        return _timelineBlock(
                          title: e['degree']?.toString() ?? '',
                          subtitle: e['institution']?.toString() ?? '',
                          dateText: _formatYearRange(
                            e['startYear'],
                            e['endYear'],
                          ),
                          body: e['field']?.toString(),
                        );
                      }).toList(),
                    ),
                  ),
                if (projects.isNotEmpty)
                  _section(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Projects',
                    child: Column(
                      children: projects.map((p) {
                        final tags = (p['tags']?.toString() ?? '')
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (p['description']
                                            ?.toString()
                                            .isNotEmpty ??
                                        false)
                                      Text(
                                        p['description'].toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    if (p['url']?.toString().isNotEmpty ??
                                        false)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          p['url'].toString(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF2563EB),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (tags.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: tags
                                              .map(
                                                (t) => Text(
                                                  '#$t',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (p['imageUrl']?.toString().isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      ApiService.imageUrl(
                                        p['imageUrl'].toString(),
                                      ),
                                      width: 62,
                                      height: 62,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String first, String last) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Center(
        child: Text(
          '${first.isNotEmpty ? first[0] : '?'}${last.isNotEmpty ? last[0] : '?'}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _headerInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
        ),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF334155)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _timelineBlock({
    required String title,
    required String subtitle,
    required String dateText,
    String? body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          Text(
            dateText,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          if (body != null && body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                body,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateRange(String? start, String? end) {
    String fmt(String? iso) {
      if (iso == null || iso.isEmpty) return '';
      try {
        final dt = DateTime.parse(iso);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        return iso;
      }
    }

    final s = fmt(start);
    final e = end == null || end.isEmpty ? 'Present' : fmt(end);
    if (s.isEmpty && e.isEmpty) return '';
    if (s.isEmpty) return e;
    if (e.isEmpty) return s;
    return '$s - $e';
  }

  String _formatYearRange(dynamic startYear, dynamic endYear) {
    final s = startYear?.toString() ?? '';
    final e = endYear?.toString() ?? '';
    if (s.isEmpty && e.isEmpty) return '';
    if (s.isEmpty) return e;
    if (e.isEmpty) return '$s - Present';
    return '$s - $e';
  }
}
