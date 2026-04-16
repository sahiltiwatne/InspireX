import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── AdminVerifyIdeasScreen ───────────────────────────────────────────────────
class AdminVerifyIdeasScreen extends StatefulWidget {
  const AdminVerifyIdeasScreen({super.key});

  @override
  State<AdminVerifyIdeasScreen> createState() =>
      _AdminVerifyIdeasScreenState();
}

class _AdminVerifyIdeasScreenState extends State<AdminVerifyIdeasScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      FirebaseFirestore.instance.collectionGroup('ideas').snapshots();

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

                docs.sort((a, b) {
                  final aTime = a.data()['createdAt'] as int? ?? 0;
                  final bTime = b.data()['createdAt'] as int? ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (_search.isNotEmpty) {
                  docs = docs.where((d) {
                    final title =
                    (d.data()['title'] as String? ?? '').toLowerCase();
                    return title.contains(_search.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text('No ideas found.',
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
                  itemBuilder: (_, i) => _IdeaCard(doc: docs[i]),
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
                child: Text('Verify Ideas',
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
          hintText: 'Search by idea title...',
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

// ─── Idea Card ────────────────────────────────────────────────────────────────
class _IdeaCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _IdeaCard({required this.doc});

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return Colors.redAccent;
      case 'on_hold':  return const Color(0xFFF59E0B);
      default:         return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'on_hold':  return 'On Hold';
      default:         return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data         = doc.data();
    final title        = data['title']       as String? ?? 'Untitled';
    final category     = data['category']    as String? ?? '';
    final patented     = data['isPatented']  as bool?   ?? false;
    final price        = data['basePrice']   as int?    ?? 0;
    final status       = data['status']      as String?;
    final hasPatentImg =
        (data['patentImageBase64'] as String?)?.isNotEmpty == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminIdeaDetailScreen(docId: doc.id, data: data),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusLabel(status),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (category.isNotEmpty) ...[
                  _tag(category, _purple),
                  const SizedBox(width: 6),
                ],
                _tag(
                  patented ? 'Patented' : 'Not Patented',
                  patented
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF6B7280),
                ),
                if (hasPatentImg) ...[
                  const SizedBox(width: 6),
                  _tag('📄 Patent Doc', const Color(0xFF3B82F6)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money,
                    size: 14, color: Color(0xFF6B7280)),
                Text('Base: \$$price',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: const Color(0xFF6B7280))),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFD1D5DB), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
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

// ─── Idea Detail Screen ───────────────────────────────────────────────────────
class AdminIdeaDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminIdeaDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminIdeaDetailScreen> createState() =>
      _AdminIdeaDetailScreenState();
}

class _AdminIdeaDetailScreenState extends State<AdminIdeaDetailScreen> {
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── Notification content per status ──────────────────────────────────────
  Map<String, String> _notifContent(String status, String ideaTitle) {
    final reason = _reasonController.text.trim();
    switch (status) {
      case 'approved':
        return {
          'title': '🎉 Congratulations! Idea Approved',
          'body':
          'Your idea "$ideaTitle" has been approved and is now visible to '
              'other users. Track your idea\'s progress in My Ideas!',
        };
      case 'rejected':
        return {
          'title': '❌ Idea Not Approved',
          'body': reason.isNotEmpty
              ? 'Your idea "$ideaTitle" was rejected. Admin note: $reason'
              : 'Your idea "$ideaTitle" was not approved at this time. '
              'Please review and resubmit.',
        };
      case 'on_hold':
        return {
          'title': '⏸️ Idea Placed On Hold',
          'body': reason.isNotEmpty
              ? 'Your idea "$ideaTitle" is on hold. Admin note: $reason'
              : 'Your idea "$ideaTitle" has been placed on hold pending '
              'further review.',
        };
      default:
        return {'title': 'Idea Update', 'body': 'Your idea status changed.'};
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _saving = true);
    try {
      final uid       = widget.data['uid']   as String?;
      final ideaTitle = widget.data['title'] as String? ?? 'Your Idea';
      final reason    = _reasonController.text.trim();

      final update = <String, dynamic>{
        'status':     status,
        'reviewedAt': FieldValue.serverTimestamp(),
      };
      if (reason.isNotEmpty) update['adminReason'] = reason;

      // ── 1. Update the idea doc ────────────────────────────────────────────
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('ideas')
            .doc(widget.docId)
            .update(update);

        // ── 2. Write in-app notification ──────────────────────────────────
        final notifContent = _notifContent(status, ideaTitle);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'type':      status,
          'title':     notifContent['title'],
          'body':      notifContent['body'],
          'ideaTitle': ideaTitle,
          'ideaId':    widget.docId,
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ── 3. Write to top-level approved_ideas (for home-feed) ──────────
        //      Only approved ideas are shown on the public home feed.
        if (status == 'approved') {
          await FirebaseFirestore.instance
              .collection('approved_ideas')
              .doc(widget.docId)
              .set({
            ...widget.data,
            'status':       'approved',
            'uid':          uid,
            'approvedAt':   FieldValue.serverTimestamp(),
            // Reset engagement counters on the public copy
            'likes':        widget.data['likes']      ?? 0,
            'interested':   widget.data['interested'] ?? 0,
            // Remove sensitive base64 patent image from public copy
            'patentImageBase64': FieldValue.delete(),
          });
        } else {
          // If previously approved and now rejected/on_hold, remove from feed
          await FirebaseFirestore.instance
              .collection('approved_ideas')
              .doc(widget.docId)
              .delete()
              .catchError((_) {}); // ignore if doesn't exist
        }
      }

      setState(() => _saving = false);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Idea status updated to $status',
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
                      child: Text('Idea Details',
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
                _infoCard('Idea Information', [
                  _row('Title', d['title']),
                  _row('Category', d['category']),
                  _row('Patented',
                      (d['isPatented'] as bool? ?? false) ? 'Yes' : 'No'),
                  _row('Base Price', '\$${d['basePrice'] ?? 0}'),
                  if ((d['aiSuggestedPrice'] as int?) != null)
                    _row('AI Suggested', '\$${d['aiSuggestedPrice']}'),
                  _row('Bidding Date', d['biddingDate']),
                  _row('Bidding Time', d['biddingTime']),
                ]),
                const SizedBox(height: 14),
                _textCard('Problem Statement', d['problemStatement']),
                const SizedBox(height: 14),
                _textCard('Detailed Solution', d['detailedSolution']),
                const SizedBox(height: 14),
                if (d['isPatented'] == true)
                  _patentImageCard(d['patentImageBase64']),
                const SizedBox(height: 14),

                // ── Reason / Note field ──────────────────────────────────
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
                      const SizedBox(height: 4),
                      Text(
                        'This note will be sent to the user as part of their notification.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF111827)),
                        decoration: InputDecoration(
                          hintText: 'Add a reason for your decision...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB)),
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

                // ── Action buttons ───────────────────────────────────────
                if (_saving)
                  const Center(
                      child: CircularProgressIndicator(color: _purple))
                else
                  Column(
                    children: [
                      _actionButton(
                        label: 'Approve Idea',
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

  Widget _textCard(String title, String? text) {
    if (text == null || text.isEmpty) return const SizedBox();
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text(text,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _patentImageCard(String? base64Str) {
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
                color: Color(0xFFD1D5DB), size: 22),
            const SizedBox(width: 10),
            Text('Patent document not uploaded',
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
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    color: _purple, size: 16),
                const SizedBox(width: 6),
                Text('Patent Certificate',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: double.infinity,
                height: 180,
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
