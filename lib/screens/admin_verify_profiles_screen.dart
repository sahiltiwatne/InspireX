import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── AdminVerifyProfilesScreen ────────────────────────────────────────────────
class AdminVerifyProfilesScreen extends StatefulWidget {
  const AdminVerifyProfilesScreen({super.key});

  @override
  State<AdminVerifyProfilesScreen> createState() =>
      _AdminVerifyProfilesScreenState();
}

class _AdminVerifyProfilesScreenState
    extends State<AdminVerifyProfilesScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // No where(), no orderBy() → zero index requirements
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      FirebaseFirestore.instance.collection('users').snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _purple));
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snap.error}',
                        style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF6B7280), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                var docs = snap.data?.docs ?? [];

                // Sort client-side: newest first
                docs.sort((a, b) {
                  final aRaw = a.data()['createdAt'];
                  final bRaw = b.data()['createdAt'];
                  final aTime = aRaw is Timestamp
                      ? aRaw.millisecondsSinceEpoch
                      : (aRaw as int? ?? 0);
                  final bTime = bRaw is Timestamp
                      ? bRaw.millisecondsSinceEpoch
                      : (bRaw as int? ?? 0);
                  return bTime.compareTo(aTime);
                });

                // Search filter (client-side)
                if (_search.isNotEmpty) {
                  docs = docs.where((d) {
                    final name =
                    (d.data()['fullName'] as String? ?? '').toLowerCase();
                    return name.contains(_search.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text('No profiles found.',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF9CA3AF))),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProfileCard(doc: docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF374151), size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text('Verify Profiles',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827))),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _search = v),
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF9CA3AF)),
          prefixIcon:
          const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          suffixIcon: _search.isNotEmpty
              ? GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _search = '');
              },
              child: const Icon(Icons.close,
                  color: Color(0xFF9CA3AF), size: 18))
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _purple, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ProfileCard({required this.doc});

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return Colors.redAccent;
      case 'on_hold':  return const Color(0xFFF59E0B);
      default:         return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved': return 'Verified';
      case 'rejected': return 'Rejected';
      case 'on_hold':  return 'On Hold';
      default:         return 'Pending';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'approved': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      case 'on_hold':  return Icons.pause_circle_outline;
      default:         return Icons.hourglass_empty_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data   = doc.data();
    final name   = data['fullName']      as String? ?? 'Unknown';
    final email  = data['email']         as String? ?? '';
    final role   = data['role']          as String? ?? 'contributor';
    final mobile = data['mobile']        as String? ?? '';
    final status = data['profileStatus'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminProfileDetailScreen(docId: doc.id, data: data),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(email,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chipTag(_roleLabel(role), _purple),
                      const SizedBox(width: 6),
                      if (mobile.isNotEmpty)
                        Text(mobile,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
            ),

            // Status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(_statusIcon(status),
                    color: _statusColor(status), size: 18),
                const SizedBox(height: 4),
                Text(_statusLabel(status),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status))),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFD1D5DB), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'investor': return 'Investor';
      case 'both':     return 'Both';
      default:         return 'Contributor';
    }
  }

  Widget _chipTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Profile Detail Screen ────────────────────────────────────────────────────
class AdminProfileDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminProfileDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminProfileDetailScreen> createState() =>
      _AdminProfileDetailScreenState();
}

class _AdminProfileDetailScreenState
    extends State<AdminProfileDetailScreen> {
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{
        'profileStatus': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      };
      if (_reasonController.text.trim().isNotEmpty) {
        update['adminReason'] = _reasonController.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.docId)
          .update(update);

      setState(() => _saving = false);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile status updated to $status',
            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        backgroundColor: _purple,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update: $e',
            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF374151), size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Profile Details',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827))),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _infoCard('Personal Details', [
                  _row('Full Name', d['fullName']),
                  _row('Email', d['email']),
                  _row('Mobile', d['mobile']),
                  _row('Location', d['location']),
                  _row('Role', d['role']),
                ]),
                const SizedBox(height: 14),

                _infoCard('KYC Details', [
                  _row('Bank Account', d['bankAccount']),
                  _row('IFSC Code', d['ifsc']),
                  _row('Bank Name', d['bankName']),
                ]),
                const SizedBox(height: 14),

                _docImageCard('Aadhaar Card', d['aadhaarBase64']),
                const SizedBox(height: 14),
                _docImageCard('PAN Card', d['panBase64']),
                const SizedBox(height: 14),

                if ((d['domains'] as List?)?.isNotEmpty == true)
                  _infoCard('Interested Domains', [
                    _domainsRow(
                        List<String>.from(d['domains'] ?? [])),
                  ]),
                const SizedBox(height: 14),

                // Reason input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reason / Note (optional)',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: const Color(0xFF111827)),
                        decoration: InputDecoration(
                          hintText:
                          'Add a reason for approval/rejection...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _purple, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                if (_saving)
                  const Center(
                      child: CircularProgressIndicator(color: _purple))
                else
                  Column(
                    children: [
                      _actionButton(
                        label: 'Approve',
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF16A34A),
                        onTap: () => _updateStatus('approved'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButtonSmall(
                              label: 'On Hold',
                              icon: Icons.pause_circle_outline,
                              color: const Color(0xFFF59E0B),
                              onTap: () => _updateStatus('on_hold'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButtonSmall(
                              label: 'Reject',
                              icon: Icons.cancel_outlined,
                              color: Colors.redAccent,
                              onTap: () => _updateStatus('rejected'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text('$value',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  Widget _domainsRow(List<String> domains) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: domains
          .map((d) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(d,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _purple)),
      ))
          .toList(),
    );
  }

  Widget _docImageCard(String label, String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.image_not_supported_outlined,
                color: Color(0xFFD1D5DB), size: 24),
            const SizedBox(width: 10),
            Text('$label not uploaded',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: const Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    try {
      final bytes = base64Decode(base64Str.replaceAll(RegExp(r'\s'), ''));
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox();
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _actionButtonSmall({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
