// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/shimmer_loading.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _portfolio;
  bool _loading = true;
  bool _busy = false;
  late TabController _tabController;
  int _selectedTab = 0;
  final ImagePicker _imagePicker = ImagePicker();

  // Gallery state
  final List<XFile> _galleryFilesForUpload = [];
  final TextEditingController _galleryCaptionCtrl = TextEditingController();

  // Experience modal state
  final TextEditingController _expTitleCtrl = TextEditingController();
  final TextEditingController _expCompanyCtrl = TextEditingController();
  final TextEditingController _expLocationCtrl = TextEditingController();
  final TextEditingController _expDescriptionCtrl = TextEditingController();
  DateTime? _expStartDate;
  DateTime? _expEndDate;
  final List<XFile> _expFilesForUpload = [];

  // Project modal state
  final TextEditingController _projTitleCtrl = TextEditingController();
  final TextEditingController _projDescriptionCtrl = TextEditingController();
  final TextEditingController _projUrlCtrl = TextEditingController();
  final TextEditingController _projTagsCtrl = TextEditingController();
  final List<XFile> _projFilesForUpload = [];

  // Education modal state
  final TextEditingController _eduInstitutionCtrl = TextEditingController();
  final TextEditingController _eduDegreeCtrl = TextEditingController();
  final TextEditingController _eduFieldCtrl = TextEditingController();
  final TextEditingController _eduStartYearCtrl = TextEditingController();
  final TextEditingController _eduEndYearCtrl = TextEditingController();
  final TextEditingController _eduDescriptionCtrl = TextEditingController();
  final List<XFile> _eduFilesForUpload = [];

  // Skill state
  final TextEditingController _skillNameCtrl = TextEditingController();
  final TextEditingController _skillYearsCtrl = TextEditingController();
  final TextEditingController _skillLevelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _galleryCaptionCtrl.dispose();
    _expTitleCtrl.dispose();
    _expCompanyCtrl.dispose();
    _expLocationCtrl.dispose();
    _expDescriptionCtrl.dispose();
    _projTitleCtrl.dispose();
    _projDescriptionCtrl.dispose();
    _projUrlCtrl.dispose();
    _projTagsCtrl.dispose();
    _eduInstitutionCtrl.dispose();
    _eduDegreeCtrl.dispose();
    _eduFieldCtrl.dispose();
    _eduStartYearCtrl.dispose();
    _eduEndYearCtrl.dispose();
    _eduDescriptionCtrl.dispose();
    _skillNameCtrl.dispose();
    _skillYearsCtrl.dispose();
    _skillLevelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().token;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      _snack('Session expired. Please sign in again.');
      return;
    }
    try {
      final res = await ApiService.get('/portfolio', token: token);
      if (mounted) {
        setState(() {
          _portfolio = (res['portfolio'] is Map<String, dynamic>)
              ? res['portfolio'] as Map<String, dynamic>
              : res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePublic() async {
    if (_portfolio == null || _busy) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final current = _portfolio!['isPublic'] == true;
      await ApiService.put(
        '/portfolio',
        token: token,
        body: {'isPublic': !current},
      );
      await _load();
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSettings() async {
    final p = _portfolio ?? {};
    final headlineCtrl = TextEditingController(
      text: p['headline']?.toString() ?? '',
    );
    final summaryCtrl = TextEditingController(
      text: p['summary']?.toString() ?? '',
    );
    final slugCtrl = TextEditingController(text: p['slug']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: const Text(
          'Portfolio Settings',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(headlineCtrl, 'Headline'),
              const SizedBox(height: 10),
              _field(summaryCtrl, 'Summary', maxLines: 4),
              const SizedBox(height: 10),
              _field(slugCtrl, 'Public Slug'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      await ApiService.put(
        '/portfolio',
        token: token,
        body: {
          'headline': headlineCtrl.text.trim().isEmpty
              ? null
              : headlineCtrl.text.trim(),
          'summary': summaryCtrl.text.trim().isEmpty
              ? null
              : summaryCtrl.text.trim(),
          'slug': slugCtrl.text.trim().isEmpty ? null : slugCtrl.text.trim(),
        },
      );
      await _load();
      _snack('Portfolio settings updated');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============== GALLERY MANAGEMENT ==============

  Future<void> _pickGalleryImages() async {
    final picked = await _imagePicker.pickMultiImage(
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked.isNotEmpty) {
      setState(() => _galleryFilesForUpload.addAll(picked));
    }
  }

  void _removeGalleryFile(int index) {
    setState(() => _galleryFilesForUpload.removeAt(index));
  }

  Future<void> _uploadGalleryImage(XFile file, String token) async {
    final uploadRes = await ApiService.multipartPost(
      '/portfolio/upload',
      fields: {},
      fileField: 'image',
      filePath: file.path,
      token: token,
    );

    final url = uploadRes['url']?.toString();
    if (url == null || url.trim().isEmpty) {
      throw Exception('Image upload did not return a valid URL');
    }

    await ApiService.post(
      '/portfolio/gallery',
      token: token,
      body: {
        'url': url.trim(),
        'caption': _galleryCaptionCtrl.text.trim().isEmpty
            ? null
            : _galleryCaptionCtrl.text.trim(),
      },
    );
  }

  Future<void> _uploadAllGalleryImages() async {
    if (_galleryFilesForUpload.isEmpty) {
      _snack('No images selected');
      return;
    }
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      for (final file in _galleryFilesForUpload) {
        await _uploadGalleryImage(file, token);
      }
      _galleryCaptionCtrl.clear();
      setState(() => _galleryFilesForUpload.clear());
      await _load();
      _snack('Gallery images uploaded');
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGalleryImage(String id) async {
    if (!await _confirmDelete('Delete this gallery image?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete('/portfolio/gallery/$id', token: token);
      await _load();
      _snack('Gallery image deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============== SKILLS MANAGEMENT ==============

  Future<void> _upsertSkill({Map<String, dynamic>? existing}) async {
    _skillNameCtrl.text = existing?['name']?.toString() ?? '';
    _skillYearsCtrl.text = existing?['yearsExperience']?.toString() ?? '';
    _skillLevelCtrl.text = existing?['level']?.toString() ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: Text(
          existing == null ? 'Add Skill' : 'Edit Skill',
          style: const TextStyle(color: ObrohColors.foreground),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_skillNameCtrl, 'Skill Name'),
            const SizedBox(height: 10),
            _field(
              _skillYearsCtrl,
              'Years (optional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _field(_skillLevelCtrl, 'Level (optional)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true || _skillNameCtrl.text.trim().isEmpty) {
      _skillNameCtrl.clear();
      _skillYearsCtrl.clear();
      _skillLevelCtrl.clear();
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      if (existing != null) {
        await ApiService.delete(
          '/portfolio/skills/${existing['id']}',
          token: token,
        );
      }
      await ApiService.post(
        '/portfolio/skills',
        token: token,
        body: {
          'name': _skillNameCtrl.text.trim(),
          'yearsExperience': int.tryParse(_skillYearsCtrl.text.trim()),
          'level': _skillLevelCtrl.text.trim().isEmpty
              ? null
              : _skillLevelCtrl.text.trim(),
        },
      );
      await _load();
      _snack('Skill saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      _skillNameCtrl.clear();
      _skillYearsCtrl.clear();
      _skillLevelCtrl.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSkill(String id) async {
    if (!await _confirmDelete('Delete this skill?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete('/portfolio/skills/$id', token: token);
      await _load();
      _snack('Skill deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============== EXPERIENCE MANAGEMENT ==============

  Future<void> _upsertExperience({Map<String, dynamic>? existing}) async {
    _expTitleCtrl.text = existing?['title']?.toString() ?? '';
    _expCompanyCtrl.text = existing?['company']?.toString() ?? '';
    _expLocationCtrl.text = existing?['location']?.toString() ?? '';
    _expDescriptionCtrl.text = existing?['description']?.toString() ?? '';
    _expStartDate = _parseDate(existing?['startDate']?.toString());
    _expEndDate = _parseDate(existing?['endDate']?.toString());
    _expFilesForUpload.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ObrohColors.obsidian900,
            title: Text(
              existing == null ? 'Add Experience' : 'Edit Experience',
              style: const TextStyle(color: ObrohColors.foreground),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(_expTitleCtrl, 'Role / Title'),
                  const SizedBox(height: 10),
                  _field(_expCompanyCtrl, 'Company'),
                  const SizedBox(height: 10),
                  _field(_expLocationCtrl, 'Location (optional)'),
                  const SizedBox(height: 10),
                  _datePickerRow(
                    label: 'Start Date',
                    value: _expStartDate,
                    onPick: () async {
                      final picked = await _pickDate(_expStartDate);
                      if (picked != null) {
                        setDialogState(() => _expStartDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _datePickerRow(
                    label: 'End Date (optional)',
                    value: _expEndDate,
                    onPick: () async {
                      final picked = await _pickDate(_expEndDate);
                      if (picked != null) {
                        setDialogState(() => _expEndDate = picked);
                      }
                    },
                    onClear: () => setDialogState(() => _expEndDate = null),
                  ),
                  const SizedBox(height: 10),
                  _field(_expDescriptionCtrl, 'Description', maxLines: 3),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Images (optional):',
                          style: TextStyle(
                            color: ObrohColors.foreground,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final files = await _imagePicker.pickMultiImage(
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (files.isNotEmpty) {
                                  setDialogState(
                                    () => _expFilesForUpload.addAll(files),
                                  );
                                }
                              },
                              icon: const Icon(Icons.image_rounded),
                              label: const Text('Pick'),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_expFilesForUpload.length} selected',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ObrohColors.gold400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _expFilesForUpload.clear();
                  Navigator.pop(ctx, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true ||
        _expTitleCtrl.text.trim().isEmpty ||
        _expCompanyCtrl.text.trim().isEmpty ||
        _expStartDate == null) {
      _clearExperienceForm();
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      final body = {
        'title': _expTitleCtrl.text.trim(),
        'company': _expCompanyCtrl.text.trim(),
        'location': _expLocationCtrl.text.trim().isEmpty
            ? null
            : _expLocationCtrl.text.trim(),
        'startDate': _expStartDate!.toIso8601String(),
        'endDate': _expEndDate?.toIso8601String(),
        'description': _expDescriptionCtrl.text.trim().isEmpty
            ? null
            : _expDescriptionCtrl.text.trim(),
      };

      String expId;
      if (existing != null) {
        await ApiService.put(
          '/portfolio/experiences/${existing['id']}',
          token: token,
          body: body,
        );
        expId = existing['id'].toString();
      } else {
        final expRes = await ApiService.post(
          '/portfolio/experiences',
          token: token,
          body: body,
        );
        final createdId = expRes['id']?.toString();
        if (createdId == null || createdId.isEmpty) {
          throw Exception('Failed to create experience');
        }
        expId = createdId;
      }

      // Upload images
      for (final file in _expFilesForUpload) {
        await ApiService.multipartPost(
          '/portfolio/experiences/$expId/images',
          fields: {'caption': ''},
          fileField: 'image',
          filePath: file.path,
          token: token,
        );
      }

      await _load();
      _snack('Experience saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      _clearExperienceForm();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearExperienceForm() {
    _expTitleCtrl.clear();
    _expCompanyCtrl.clear();
    _expLocationCtrl.clear();
    _expDescriptionCtrl.clear();
    _expStartDate = null;
    _expEndDate = null;
    _expFilesForUpload.clear();
  }

  Future<void> _deleteExperience(String id) async {
    if (!await _confirmDelete('Delete this experience?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete('/portfolio/experiences/$id', token: token);
      await _load();
      _snack('Experience deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteExperienceImage(String expId, String imageId) async {
    if (!await _confirmDelete('Delete this image?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete(
        '/portfolio/experiences/$expId/images/$imageId',
        token: token,
      );
      await _load();
      _snack('Image deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============== PROJECTS MANAGEMENT ==============

  Future<void> _upsertProject({Map<String, dynamic>? existing}) async {
    _projTitleCtrl.text = existing?['title']?.toString() ?? '';
    _projDescriptionCtrl.text = existing?['description']?.toString() ?? '';
    _projUrlCtrl.text = existing?['url']?.toString() ?? '';
    _projTagsCtrl.text = existing?['tags'] == null
        ? ''
        : (existing!['tags'] is List
              ? (existing['tags'] as List).join(', ')
              : existing['tags'].toString());
    _projFilesForUpload.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ObrohColors.obsidian900,
            title: Text(
              existing == null ? 'Add Project' : 'Edit Project',
              style: const TextStyle(color: ObrohColors.foreground),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(_projTitleCtrl, 'Title'),
                  const SizedBox(height: 10),
                  _field(_projDescriptionCtrl, 'Description', maxLines: 3),
                  const SizedBox(height: 10),
                  _field(_projUrlCtrl, 'Project URL (optional)'),
                  const SizedBox(height: 10),
                  _field(_projTagsCtrl, 'Tags (comma separated)'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Images (optional):',
                          style: TextStyle(
                            color: ObrohColors.foreground,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final files = await _imagePicker.pickMultiImage(
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (files.isNotEmpty) {
                                  setDialogState(
                                    () => _projFilesForUpload.addAll(files),
                                  );
                                }
                              },
                              icon: const Icon(Icons.image_rounded),
                              label: const Text('Pick'),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_projFilesForUpload.length} selected',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ObrohColors.gold400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _projFilesForUpload.clear();
                  Navigator.pop(ctx, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true || _projTitleCtrl.text.trim().isEmpty) {
      _clearProjectForm();
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      final tagsArray = _projTagsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final body = {
        'title': _projTitleCtrl.text.trim(),
        'description': _projDescriptionCtrl.text.trim().isEmpty
            ? null
            : _projDescriptionCtrl.text.trim(),
        'url': _projUrlCtrl.text.trim().isEmpty
            ? null
            : _projUrlCtrl.text.trim(),
        'tags': tagsArray.isEmpty ? null : tagsArray,
      };

      String projId;
      if (existing != null) {
        await ApiService.put(
          '/portfolio/projects/${existing['id']}',
          token: token,
          body: body,
        );
        projId = existing['id'].toString();
      } else {
        final projRes = await ApiService.post(
          '/portfolio/projects',
          token: token,
          body: body,
        );
        final createdId = projRes['id']?.toString();
        if (createdId == null || createdId.isEmpty) {
          throw Exception('Failed to create project');
        }
        projId = createdId;
      }

      // Upload images
      for (final file in _projFilesForUpload) {
        await ApiService.multipartPost(
          '/portfolio/projects/$projId/images',
          fields: {'caption': ''},
          fileField: 'image',
          filePath: file.path,
          token: token,
        );
      }

      await _load();
      _snack('Project saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      _clearProjectForm();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearProjectForm() {
    _projTitleCtrl.clear();
    _projDescriptionCtrl.clear();
    _projUrlCtrl.clear();
    _projTagsCtrl.clear();
    _projFilesForUpload.clear();
  }

  Future<void> _deleteProject(String id) async {
    if (!await _confirmDelete('Delete this project?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete('/portfolio/projects/$id', token: token);
      await _load();
      _snack('Project deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProjectImage(String projId, String imageId) async {
    if (!await _confirmDelete('Delete this image?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete(
        '/portfolio/projects/$projId/images/$imageId',
        token: token,
      );
      await _load();
      _snack('Image deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============== EDUCATION MANAGEMENT ==============

  Future<void> _upsertEducation({Map<String, dynamic>? existing}) async {
    _eduInstitutionCtrl.text = existing?['institution']?.toString() ?? '';
    _eduDegreeCtrl.text = existing?['degree']?.toString() ?? '';
    _eduFieldCtrl.text = existing?['field']?.toString() ?? '';
    _eduStartYearCtrl.text = existing?['startYear']?.toString() ?? '';
    _eduEndYearCtrl.text = existing?['endYear']?.toString() ?? '';
    _eduDescriptionCtrl.text = existing?['description']?.toString() ?? '';
    _eduFilesForUpload.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ObrohColors.obsidian900,
            title: Text(
              existing == null ? 'Add Education' : 'Edit Education',
              style: const TextStyle(color: ObrohColors.foreground),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(_eduInstitutionCtrl, 'Institution'),
                  const SizedBox(height: 10),
                  _field(_eduDegreeCtrl, 'Degree'),
                  const SizedBox(height: 10),
                  _field(_eduFieldCtrl, 'Field (optional)'),
                  const SizedBox(height: 10),
                  _field(
                    _eduStartYearCtrl,
                    'Start Year',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _eduEndYearCtrl,
                    'End Year (optional)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _eduDescriptionCtrl,
                    'Description (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Images (optional):',
                          style: TextStyle(
                            color: ObrohColors.foreground,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final file = await _imagePicker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (file != null) {
                                  setDialogState(() {
                                    _eduFilesForUpload
                                      ..clear()
                                      ..add(file);
                                  });
                                }
                              },
                              icon: const Icon(Icons.image_rounded),
                              label: const Text('Pick'),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_eduFilesForUpload.length} selected',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ObrohColors.gold400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _eduFilesForUpload.clear();
                  Navigator.pop(ctx, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true ||
        _eduInstitutionCtrl.text.trim().isEmpty ||
        _eduDegreeCtrl.text.trim().isEmpty) {
      _clearEducationForm();
      return;
    }

    final startYear = int.tryParse(_eduStartYearCtrl.text.trim());
    if (startYear == null) {
      _snack('Start year is required');
      _clearEducationForm();
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _busy = true);
    try {
      final body = {
        'institution': _eduInstitutionCtrl.text.trim(),
        'degree': _eduDegreeCtrl.text.trim(),
        'field': _eduFieldCtrl.text.trim().isEmpty
            ? null
            : _eduFieldCtrl.text.trim(),
        'startYear': startYear.toString(),
        'endYear': _eduEndYearCtrl.text.trim().isEmpty
            ? null
            : _eduEndYearCtrl.text.trim(),
        'description': _eduDescriptionCtrl.text.trim().isEmpty
            ? null
            : _eduDescriptionCtrl.text.trim(),
      };

      String eduId;
      if (existing != null) {
        await ApiService.put(
          '/portfolio/education/${existing['id']}',
          token: token,
          body: body,
        );
        eduId = existing['id'].toString();
      } else {
        final eduRes = await ApiService.post(
          '/portfolio/education',
          token: token,
          body: body,
        );
        final createdId = eduRes['id']?.toString();
        if (createdId == null || createdId.isEmpty) {
          throw Exception('Failed to create education');
        }
        eduId = createdId;
      }

      // Upload single image
      if (_eduFilesForUpload.isNotEmpty) {
        await ApiService.multipartPost(
          '/portfolio/education/$eduId/image',
          fields: {'caption': ''},
          fileField: 'image',
          filePath: _eduFilesForUpload.first.path,
          token: token,
        );
      }

      await _load();
      _snack('Education saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      _clearEducationForm();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearEducationForm() {
    _eduInstitutionCtrl.clear();
    _eduDegreeCtrl.clear();
    _eduFieldCtrl.clear();
    _eduStartYearCtrl.clear();
    _eduEndYearCtrl.clear();
    _eduDescriptionCtrl.clear();
    _eduFilesForUpload.clear();
  }

  Future<void> _deleteEducation(String id) async {
    if (!await _confirmDelete('Delete this education?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete('/portfolio/education/$id', token: token);
      await _load();
      _snack('Education deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEducationImage(String eduId) async {
    if (!await _confirmDelete('Delete this education image?')) return;
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiService.delete(
        '/portfolio/education/$eduId/image',
        token: token,
      );
      await _load();
      _snack('Image deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _imagePlaceholder(String message, {String? hint}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported,
              color: ObrohColors.foreground40,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: ObrohColors.foreground40,
              ),
            ),
            if (hint != null && hint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: ObrohColors.foreground.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteImage(String? rawUrl, {required BoxFit fit}) {
    final resolvedUrl = ApiService.imageUrl(rawUrl);
    if (resolvedUrl.isEmpty) {
      return _imagePlaceholder('Missing image URL');
    }
    return Image.network(
      resolvedUrl,
      fit: fit,
      loadingBuilder: (ctx, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ObrohColors.gold400,
            ),
          ),
        );
      },
      errorBuilder: (ctx, err, stack) =>
          _imagePlaceholder('Failed to load image', hint: resolvedUrl),
    );
  }

  // ============== HELPERS ==============

  Future<bool> _confirmDelete(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ObrohColors.obsidian900,
            title: const Text(
              'Confirm Delete',
              style: TextStyle(color: ObrohColors.foreground),
            ),
            content: Text(
              msg,
              style: const TextStyle(color: ObrohColors.foreground),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: ObrohColors.foreground),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: ObrohColors.foreground40),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ObrohColors.foreground20),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ObrohColors.gold400),
        ),
      ),
    );
  }

  Widget _datePickerRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == null
                ? '$label: Not set'
                : '$label: ${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: ObrohColors.foreground.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('Pick')),
        if (onClear != null && value != null)
          TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    final authError =
        msg.toLowerCase().contains('session expired') ||
        msg.toLowerCase().contains('access denied');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: authError
            ? SnackBarAction(
                label: 'Sign In',
                onPressed: () {
                  context.read<AuthService>().logout();
                },
              )
            : null,
        backgroundColor: ObrohColors.obsidian800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: ObrohColors.gold400,
          labelColor: ObrohColors.gold400,
          unselectedLabelColor: ObrohColors.foreground40,
          tabs: const [
            Tab(text: 'Settings'),
            Tab(text: 'Gallery'),
            Tab(text: 'Skills'),
            Tab(text: 'Experience'),
            Tab(text: 'Projects'),
            Tab(text: 'Education'),
          ],
        ),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              onPressed: _busy ? null : _editSettings,
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit Settings',
            ),
        ],
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  ShimmerLoading(height: 100, borderRadius: 16),
                  SizedBox(height: 12),
                  ShimmerLoading(height: 60, borderRadius: 16),
                  SizedBox(height: 12),
                  ShimmerLoading(height: 60, borderRadius: 16),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Settings Tab
                _buildSettingsTab(),
                // Gallery Tab
                _buildGalleryTab(),
                // Skills Tab
                _buildSkillsTab(),
                // Experience Tab
                _buildExperienceTab(),
                // Projects Tab
                _buildProjectsTab(),
                // Education Tab
                _buildEducationTab(),
              ],
            ),
    );
  }

  Widget _buildSettingsTab() {
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _portfolio?['headline']?.toString() ?? 'My Portfolio',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ObrohColors.gold400,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _portfolio?['isPublic'] == true
                            ? ObrohColors.success.withValues(alpha: 0.15)
                            : ObrohColors.foreground.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _portfolio?['isPublic'] == true ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _portfolio?['isPublic'] == true
                              ? ObrohColors.success
                              : ObrohColors.foreground40,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((_portfolio?['summary']?.toString().isNotEmpty ??
                    false)) ...[
                  const SizedBox(height: 8),
                  Text(
                    _portfolio!['summary'].toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: ObrohColors.foreground.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ],
                if ((_portfolio?['slug']?.toString().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  Text(
                    '/portfolio/${_portfolio!['slug']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: ObrohColors.foreground.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          LoadingButton(
            onPressed: _togglePublic,
            loading: _busy,
            label: _portfolio?['isPublic'] == true
                ? 'Make Private'
                : 'Make Public',
            icon: _portfolio?['isPublic'] == true
                ? Icons.lock_rounded
                : Icons.public_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTab() {
    final gallery = _portfolio?['galleryImages'] as List? ?? [];
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Gallery Images',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ObrohColors.gold400,
                  ),
                ),
                const SizedBox(height: 12),
                if (_galleryFilesForUpload.isNotEmpty) ...[
                  Text(
                    '${_galleryFilesForUpload.length} image(s) selected',
                    style: const TextStyle(
                      color: ObrohColors.foreground,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _galleryFilesForUpload.length,
                      itemBuilder: (ctx, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: ObrohColors.obsidian800,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.file(
                                  File(_galleryFilesForUpload[idx].path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeGalleryFile(idx),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ObrohColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: ObrohColors.obsidian950,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: _pickGalleryImages,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Pick Images'),
                ),
                if (_galleryFilesForUpload.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LoadingButton(
                    onPressed: _uploadAllGalleryImages,
                    loading: _busy,
                    label: 'Upload All',
                    icon: Icons.cloud_upload_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (gallery.isEmpty)
            Center(
              child: Text(
                'No gallery images yet.',
                style: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...gallery.map((img) {
              final image = img as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (image['url'] != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: ObrohColors.obsidian800,
                          ),
                          child: _buildRemoteImage(
                            image['url']?.toString(),
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (image['caption'] != null &&
                          image['caption'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          image['caption'].toString(),
                          style: TextStyle(
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              _deleteGalleryImage(image['id'].toString()),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: ObrohColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    final skills = _portfolio?['skills'] as List? ?? [];
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoadingButton(
            onPressed: () => _upsertSkill(),
            loading: _busy,
            label: 'Add Skill',
            icon: Icons.add_rounded,
          ),
          const SizedBox(height: 16),
          if (skills.isEmpty)
            Center(
              child: Text(
                'No skills yet.',
                style: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...skills.map((skill) {
              final s = skill as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ObrohColors.foreground,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _upsertSkill(existing: s),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          ),
                          IconButton(
                            onPressed: () => _deleteSkill(s['id'].toString()),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: ObrohColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (s['level'] != null ||
                          s['yearsExperience'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (s['level'] != null) s['level'].toString(),
                            if (s['yearsExperience'] != null)
                              '${s['yearsExperience']} yrs',
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExperienceTab() {
    final experiences = _portfolio?['experiences'] as List? ?? [];
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoadingButton(
            onPressed: () => _upsertExperience(),
            loading: _busy,
            label: 'Add Experience',
            icon: Icons.add_rounded,
          ),
          const SizedBox(height: 16),
          if (experiences.isEmpty)
            Center(
              child: Text(
                'No experiences yet.',
                style: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...experiences.map((exp) {
              final e = exp as Map<String, dynamic>;
              final images = e['images'] as List? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ObrohColors.foreground,
                                  ),
                                ),
                                if (e['company'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    e['company'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ObrohColors.foreground.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _upsertExperience(existing: e),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteExperience(e['id'].toString()),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: ObrohColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (e['description'] != null &&
                          e['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          e['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (ctx, idx) {
                              final img = images[idx] as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: ObrohColors.obsidian800,
                                      ),
                                      child: _buildRemoteImage(
                                        img['url']?.toString(),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _deleteExperienceImage(
                                          e['id'].toString(),
                                          img['id'].toString(),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: ObrohColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: ObrohColors.obsidian950,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    final projects = _portfolio?['projects'] as List? ?? [];
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoadingButton(
            onPressed: () => _upsertProject(),
            loading: _busy,
            label: 'Add Project',
            icon: Icons.add_rounded,
          ),
          const SizedBox(height: 16),
          if (projects.isEmpty)
            Center(
              child: Text(
                'No projects yet.',
                style: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...projects.map((proj) {
              final p = proj as Map<String, dynamic>;
              final images = p['images'] as List? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['title']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ObrohColors.foreground,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _upsertProject(existing: p),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          ),
                          IconButton(
                            onPressed: () => _deleteProject(p['id'].toString()),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: ObrohColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (p['description'] != null &&
                          p['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          p['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (ctx, idx) {
                              final img = images[idx] as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: ObrohColors.obsidian800,
                                      ),
                                      child: _buildRemoteImage(
                                        img['url']?.toString(),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _deleteProjectImage(
                                          p['id'].toString(),
                                          img['id'].toString(),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: ObrohColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: ObrohColors.obsidian950,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEducationTab() {
    final education = _portfolio?['education'] as List? ?? [];
    return RefreshIndicator(
      color: ObrohColors.gold400,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoadingButton(
            onPressed: () => _upsertEducation(),
            loading: _busy,
            label: 'Add Education',
            icon: Icons.add_rounded,
          ),
          const SizedBox(height: 16),
          if (education.isEmpty)
            Center(
              child: Text(
                'No education yet.',
                style: TextStyle(
                  color: ObrohColors.foreground.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...education.map((edu) {
              final e = edu as Map<String, dynamic>;
              final imageUrl = e['imageUrl']?.toString();
              final years =
                  '${e['startYear'] ?? ''}${e['endYear'] != null ? ' - ${e['endYear']}' : ''}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['degree']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ObrohColors.foreground,
                                  ),
                                ),
                                if (e['institution'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    e['institution'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ObrohColors.foreground.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                                if (years.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    years,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ObrohColors.foreground.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _upsertEducation(existing: e),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          ),
                          IconButton(
                            onPressed: () =>
                                _deleteEducation(e['id'].toString()),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: ObrohColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (e['description'] != null &&
                          e['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          e['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: ObrohColors.foreground.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            SizedBox(
                              height: 80,
                              width: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: ObrohColors.obsidian800,
                                ),
                                child: _buildRemoteImage(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    _deleteEducationImage(e['id'].toString()),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: ObrohColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: ObrohColors.obsidian950,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
