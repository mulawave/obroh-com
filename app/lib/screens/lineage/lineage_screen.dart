import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/request_guard.dart';
import '../../theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/gold_card.dart';
import '../../widgets/shimmer_loading.dart';

class LineageScreen extends StatefulWidget {
  const LineageScreen({super.key});

  @override
  State<LineageScreen> createState() => _LineageScreenState();
}

class _LineageScreenState extends State<LineageScreen> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _tree = [];
  List<_PathNode> _pathToRoot = [];
  List<Map<String, dynamic>> _requests = [];

  bool _loading = true;
  bool _showFullTree = false;
  bool _submittingRequest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = context.read<AuthService>().token;
    RequestGuard.requireSessionOrReauth(context, token);
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.get('/auth/me', token: token),
        ApiService.get('/family-tree', token: token),
        ApiService.get('/lineage/child-requests/mine', token: token),
      ]);

      final meRes = results[0];
      final treeRes = results[1];
      final reqRes = results[2];

      final me =
          (meRes['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final tree =
          (treeRes['tree'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      final requests =
          (reqRes['requests'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];

      final branchId = me['branchId']?.toString();
      final path = branchId == null
          ? <_PathNode>[]
          : _findPathToRoot(tree, branchId).asMap().entries.map((e) {
              return _PathNode(node: e.value, level: e.key);
            }).toList();

      if (mounted) {
        setState(() {
          _me = me;
          _tree = tree;
          _requests = requests;
          _pathToRoot = path;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(context, e, onRetry: _load);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _findPathToRoot(
    List<Map<String, dynamic>> nodes,
    String targetId, {
    List<Map<String, dynamic>> currentPath = const [],
  }) {
    for (final node in nodes) {
      final nodeId = node['id']?.toString();
      final nextPath = [...currentPath, node];
      if (nodeId == targetId) {
        return nextPath;
      }

      final children =
          (node['children'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      if (children.isNotEmpty) {
        final result = _findPathToRoot(
          children,
          targetId,
          currentPath: nextPath,
        );
        if (result.isNotEmpty) return result;
      }
    }
    return [];
  }

  bool _canManageRequest(String status) {
    return status == 'pending' || status == 'rejected';
  }

  Future<void> _openChildRequestForm({Map<String, dynamic>? existing}) async {
    final firstNameCtrl = TextEditingController(
      text: existing?['firstName']?.toString() ?? '',
    );
    final lastNameCtrl = TextEditingController(
      text: existing?['lastName']?.toString() ?? '',
    );
    final branchCtrl = TextEditingController(
      text: existing?['branch']?.toString() ?? '',
    );
    final dateCtrl = TextEditingController(
      text: existing?['dateOfBirth']?.toString() ?? '',
    );
    String? gender = existing?['gender']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: ObrohColors.obsidian900,
            title: Text(
              existing == null
                  ? 'Register Child Request'
                  : 'Edit Child Request',
              style: TextStyle(color: ObrohColors.foreground),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(firstNameCtrl, 'First Name *'),
                  const SizedBox(height: 10),
                  _dialogField(lastNameCtrl, 'Last Name *'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    style: const TextStyle(color: ObrohColors.foreground),
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (optional)',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        dateCtrl.text = date.toIso8601String().split('T').first;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    dropdownColor: ObrohColors.obsidian900,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (value) => setDialogState(() => gender = value),
                  ),
                  const SizedBox(height: 10),
                  _dialogField(branchCtrl, 'Branch (optional)'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(existing == null ? 'Submit Request' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final firstName = firstNameCtrl.text.trim();
    final lastName = lastNameCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First and last name are required.')),
        );
      }
      return;
    }

    setState(() => _submittingRequest = true);
    try {
      if (!mounted) return;
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) {
        if (mounted) setState(() => _submittingRequest = false);
        return;
      }

      final payload = {
        'firstName': firstName,
        'lastName': lastName,
        if (dateCtrl.text.trim().isNotEmpty)
          'dateOfBirth': dateCtrl.text.trim(),
        'gender': gender,
        if (branchCtrl.text.trim().isNotEmpty) 'branch': branchCtrl.text.trim(),
      };

      if (existing == null) {
        await ApiService.post(
          '/lineage/child-request',
          token: token,
          body: payload,
        );
      } else {
        await ApiService.patch(
          '/lineage/child-request/${existing['id']}',
          token: token,
          body: payload,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Child request submitted successfully.'
                : 'Child request updated and resubmitted.',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _openChildRequestForm(existing: existing),
      );
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  }

  Future<void> _cancelChildRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObrohColors.obsidian900,
        title: const Text(
          'Cancel Request',
          style: TextStyle(color: ObrohColors.foreground),
        ),
        content: const Text(
          'This will remove the child registration request.',
          style: TextStyle(color: ObrohColors.foreground60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = context.read<AuthService>().token;
      RequestGuard.requireSessionOrReauth(context, token);
      if (token == null) return;
      await ApiService.delete(
        '/lineage/child-request/${request['id']}',
        token: token,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request cancelled.')));
      }
    } on ApiException catch (e) {
      await RequestGuard.handleApiException(
        context,
        e,
        onRetry: () => _cancelChildRequest(request),
      );
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: ObrohColors.foreground),
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = _me?['branch'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('My Lineage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submittingRequest ? null : () => _openChildRequestForm(),
        backgroundColor: ObrohColors.gold400,
        foregroundColor: ObrohColors.obsidian950,
        icon: _submittingRequest
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_submittingRequest ? 'Submitting...' : 'Register Child'),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerLoading(height: 120, borderRadius: 16),
                SizedBox(height: 12),
                ShimmerLoading(height: 160, borderRadius: 16),
                SizedBox(height: 12),
                ShimmerLoading(height: 180, borderRadius: 16),
              ],
            )
          : RefreshIndicator(
              color: ObrohColors.gold400,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GoldCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvatarCircle(
                          imageUrl: _me?['profileImage']?.toString(),
                          initials:
                              '${(_me?['firstName']?.toString() ?? '?')[0]}${(_me?['lastName']?.toString() ?? '?')[0]}',
                          size: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_me?['firstName'] ?? ''} ${_me?['lastName'] ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ObrohColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                branch == null
                                    ? 'Not assigned to any branch yet.'
                                    : 'Assigned Branch: ${branch['name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ObrohColors.foreground.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPathCard(),
                  const SizedBox(height: 14),
                  _buildTreeCard(),
                  const SizedBox(height: 14),
                  _buildRequestsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPathCard() {
    return GoldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Connection to Main Branch',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ObrohColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          if (_pathToRoot.isEmpty)
            Text(
              'No branch path available yet. Contact an administrator to assign your branch.',
              style: TextStyle(
                fontSize: 12,
                color: ObrohColors.foreground.withValues(alpha: 0.5),
              ),
            )
          else
            ..._pathToRoot.map((p) {
              final isFirst = p.level == 0;
              final isLast = p.level == _pathToRoot.length - 1;
              final patriarch = p.node['patriarch'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLast
                      ? ObrohColors.gold400.withValues(alpha: 0.12)
                      : ObrohColors.obsidian700.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLast
                        ? ObrohColors.gold400.withValues(alpha: 0.35)
                        : ObrohColors.gold400.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ObrohColors.gold400.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Text(
                          '${p.level + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ObrohColors.gold400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.node['name'] ?? ''}'
                            '${isFirst ? ' (Main Branch)' : ''}'
                            '${isLast && !isFirst ? ' (Your Branch)' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ObrohColors.foreground,
                            ),
                          ),
                          if (patriarch != null)
                            Text(
                              'Patriarch: ${patriarch['firstName']} ${patriarch['lastName']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: ObrohColors.foreground.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTreeCard() {
    return GoldCard(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showFullTree = !_showFullTree),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_rounded,
                    color: ObrohColors.gold400,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Complete Family Tree',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ObrohColors.foreground,
                      ),
                    ),
                  ),
                  Icon(
                    _showFullTree
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ObrohColors.foreground,
                  ),
                ],
              ),
            ),
          ),
          if (_showFullTree) ...[
            const SizedBox(height: 6),
            if (_tree.isEmpty)
              Text(
                'Family tree is currently unavailable.',
                style: TextStyle(
                  fontSize: 12,
                  color: ObrohColors.foreground.withValues(alpha: 0.45),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      children: _tree
                          .map(
                            (node) => _TreeNodeTile(
                              node: node,
                              depth: 0,
                              myBranchId: _me?['branchId']?.toString(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestsCard() {
    return GoldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Child Registration Requests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ObrohColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          if (_requests.isEmpty)
            Text(
              'No requests yet. Use Register Child to submit one.',
              style: TextStyle(
                fontSize: 12,
                color: ObrohColors.foreground.withValues(alpha: 0.5),
              ),
            )
          else
            ..._requests.map((r) {
              final status = (r['status']?.toString() ?? 'pending')
                  .toLowerCase();
              final canManage = _canManageRequest(status);
              final color = status == 'approved'
                  ? ObrohColors.success
                  : status == 'rejected'
                  ? ObrohColors.error
                  : ObrohColors.gold400;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ObrohColors.obsidian700.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
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
                                '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ObrohColors.foreground,
                                ),
                              ),
                              if (r['branch']?.toString().isNotEmpty ?? false)
                                Text(
                                  'Branch: ${r['branch']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ObrohColors.foreground.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _submittingRequest
                                ? null
                                : () => _openChildRequestForm(existing: r),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _submittingRequest
                                ? null
                                : () => _cancelChildRequest(r),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                            ),
                            label: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TreeNodeTile extends StatefulWidget {
  final Map<String, dynamic> node;
  final int depth;
  final String? myBranchId;

  const _TreeNodeTile({
    required this.node,
    required this.depth,
    required this.myBranchId,
  });

  @override
  State<_TreeNodeTile> createState() => _TreeNodeTileState();
}

class _TreeNodeTileState extends State<_TreeNodeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final children =
        (widget.node['children'] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final patriarch = widget.node['patriarch'] as Map<String, dynamic>?;
    final isMine =
        widget.myBranchId != null &&
        widget.node['id']?.toString() == widget.myBranchId;

    return Container(
      margin: EdgeInsets.only(left: widget.depth * 12.0, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? ObrohColors.gold400.withValues(alpha: 0.12)
            : ObrohColors.obsidian700.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? ObrohColors.gold400.withValues(alpha: 0.4)
              : ObrohColors.gold400.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ObrohColors.goldGradient,
                ),
                child: Icon(
                  widget.depth == 0
                      ? Icons.workspace_premium_rounded
                      : Icons.account_tree_rounded,
                  size: 18,
                  color: ObrohColors.obsidian950,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.node['name']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ObrohColors.foreground,
                      ),
                    ),
                    if (patriarch != null)
                      Text(
                        'Patriarch: ${patriarch['firstName']} ${patriarch['lastName']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: ObrohColors.foreground.withValues(alpha: 0.5),
                        ),
                      ),
                    Text(
                      '${widget.node['memberCount'] ?? 0} members',
                      style: TextStyle(
                        fontSize: 10,
                        color: ObrohColors.foreground.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMine)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ObrohColors.gold400.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 9,
                      color: ObrohColors.gold400,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (children.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: ObrohColors.foreground,
                  ),
                ),
            ],
          ),
          if (widget.node['description']?.toString().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              widget.node['description'].toString(),
              style: TextStyle(
                fontSize: 11,
                color: ObrohColors.foreground.withValues(alpha: 0.58),
                height: 1.4,
              ),
            ),
          ],
          if (_expanded && children.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...children.map(
              (c) => _TreeNodeTile(
                node: c,
                depth: widget.depth + 1,
                myBranchId: widget.myBranchId,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PathNode {
  final Map<String, dynamic> node;
  final int level;

  const _PathNode({required this.node, required this.level});
}
