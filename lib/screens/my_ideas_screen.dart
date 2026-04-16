import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'idea_bidding_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── Feed publishing helper ───────────────────────────────────────────────────
//
// Call this when admin sets status → 'approved'.
// It writes the idea into the shared `approved_ideas` collection so that
// every user (including the submitter) sees it in their Home & Search feed.
//
// Pass [remove: true] when an idea is un-approved (rejected / on_hold)
// to remove it from the public feed.
Future<void> publishToFeed({
  required String docId,
  required Map<String, dynamic> ideaData,
  bool remove = false,
}) async {
  final feedRef = FirebaseFirestore.instance
      .collection('approved_ideas')
      .doc(docId); // use same docId so it's idempotent

  if (remove) {
    await feedRef.delete();
  } else {
    await feedRef.set({
      ...ideaData,
      'approvedAt': FieldValue.serverTimestamp(),
      'isSeeded': false,
    }, SetOptions(merge: true));
  }
}

// ─── MyIdeasScreen ────────────────────────────────────────────────────────────
class MyIdeasScreen extends StatefulWidget {
  const MyIdeasScreen({super.key});

  @override
  State<MyIdeasScreen> createState() => _MyIdeasScreenState();
}

class _MyIdeasScreenState extends State<MyIdeasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  final _tabs = const ['All', 'Approved', 'Pending', 'Rejected', 'On Hold'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _ideasStream {
    if (_uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('ideas')
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filter(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      int tabIndex,
      ) {
    docs.sort((a, b) {
      final aT = a.data()['createdAt'] as int? ?? 0;
      final bT = b.data()['createdAt'] as int? ?? 0;
      return bT.compareTo(aT);
    });

    switch (tabIndex) {
      case 1:
        return docs.where((d) => d.data()['status'] == 'approved').toList();
      case 2:
        return docs
            .where((d) =>
        d.data()['status'] == 'pending_review' ||
            d.data()['status'] == null)
            .toList();
      case 3:
        return docs.where((d) => d.data()['status'] == 'rejected').toList();
      case 4:
        return docs.where((d) => d.data()['status'] == 'on_hold').toList();
      default:
        return docs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          _buildTabBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ideasStream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _purple),
                  );
                }
                if (snap.hasError) {
                  return _ErrorView(message: '${snap.error}');
                }

                final allDocs = snap.data?.docs ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (i) {
                    final filtered = _filter(List.from(allDocs), i);
                    if (filtered.isEmpty) {
                      return _EmptyState(tabLabel: _tabs[i]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 14),
                      itemBuilder: (_, idx) =>
                          _IdeaCard(doc: filtered[idx]),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Ideas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Track and manage your submitted ideas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            _NotificationBell(uid: _uid),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelColor: _purple,
        unselectedLabelColor: const Color(0xFF9CA3AF),
        indicatorColor: _purple,
        indicatorWeight: 2.5,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

// ─── Idea Card ────────────────────────────────────────────────────────────────
class _IdeaCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _IdeaCard({required this.doc});

  // ── Status helpers ────────────────────────────────────────────────────────
  String _statusLabel(String? s) {
    switch (s) {
      case 'approved':      return 'Approved';
      case 'rejected':      return 'Rejected';
      case 'on_hold':       return 'On Hold';
      case 'pending_review':
      default:              return 'Under Review';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return Colors.redAccent;
      case 'on_hold':  return const Color(0xFFF59E0B);
      default:         return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'approved': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      case 'on_hold':  return Icons.pause_circle_outline;
      default:         return Icons.hourglass_top_outlined;
    }
  }

  Color _statusBg(String? s) {
    switch (s) {
      case 'approved': return const Color(0xFFDCFCE7);
      case 'rejected': return const Color(0xFFFFE4E6);
      case 'on_hold':  return const Color(0xFFFFF3CD);
      default:         return const Color(0xFFF1F5F9);
    }
  }

  // ── Publish / unpublish from shared feed ──────────────────────────────────
  Future<void> _syncFeed(String docId, Map<String, dynamic> data) async {
    final status = data['status'] as String?;
    if (status == 'approved') {
      await publishToFeed(docId: docId, ideaData: data);
    } else {
      // If previously approved but now rejected/on_hold, remove from feed
      await publishToFeed(docId: docId, ideaData: data, remove: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d           = doc.data();
    final title       = d['title']       as String? ?? 'Untitled';
    final category    = d['category']    as String? ?? '';
    final patented    = d['isPatented']  as bool?   ?? false;
    final status      = d['status']      as String?;
    final basePrice   = d['basePrice']   as int?    ?? 0;
    final likes       = d['likes']       as int?    ?? 0;
    final interested  = d['interested']  as int?    ?? 0;
    final adminReason = d['adminReason'] as String?;
    final biddingDate = d['biddingDate'] as String?;
    final biddingTime = d['biddingTime'] as String?;

    // ── Auto-publish when card is built and status is approved ────────────
    // This ensures that if admin changes status in Firestore console directly
    // (or via admin panel), the feed stays in sync.
    if (status == 'approved') {
      _syncFeed(doc.id, d);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(status),
                    size: 16, color: _statusColor(status)),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(status),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
                const Spacer(),
                // "Live on Feed" badge for approved ideas
                if (status == 'approved')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live on Feed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (status == 'pending_review' || status == null)
                  _AnimatedDot(),
              ],
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Tags ─────────────────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (category.isNotEmpty)
                      _Tag(
                        label: category,
                        bgColor: const Color(0xFFEDE9FE),
                        textColor: _purple,
                      ),
                    _Tag(
                      icon: patented
                          ? Icons.verified_outlined
                          : Icons.block_outlined,
                      label: patented ? 'Patented' : 'Not Patented',
                      bgColor: patented
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      textColor: patented
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Stats row ─────────────────────────────────────────────
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.thumb_up_alt_outlined,
                      value: '$likes',
                      label: 'Likes',
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.people_outline,
                      value: '$interested',
                      label: 'Interested',
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.attach_money,
                      value: '\$$basePrice',
                      label: 'Base Price',
                    ),
                  ],
                ),

                // ── Bidding schedule ──────────────────────────────────────
                if (status == 'approved' &&
                    (biddingDate != null || biddingTime != null)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(
                          [biddingDate, biddingTime]
                              .where((e) => e != null && e.isNotEmpty)
                              .join('  •  '),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Admin reason (rejected / on_hold) ─────────────────────
                if (adminReason != null &&
                    adminReason.isNotEmpty &&
                    (status == 'rejected' || status == 'on_hold')) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status == 'rejected'
                          ? const Color(0xFFFFE4E6)
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 15,
                          color: status == 'rejected'
                              ? Colors.redAccent
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Note',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: status == 'rejected'
                                      ? Colors.redAccent
                                      : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                adminReason,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: status == 'rejected'
                                      ? const Color(0xFF9B1C1C)
                                      : const Color(0xFF78350F),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── CTA (approved ideas only) ─────────────────────────────
                if (status == 'approved') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_gradientStart, _gradientEnd],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                IdeaBiddingScreen(ideaTitle: title),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'View Bidding',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated "reviewing" dot ─────────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _purple),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tag ──────────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Tag({
    this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Bell ────────────────────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  final String? uid;
  const _NotificationBell({required this.uid});

  Stream<int> get _unreadCount {
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(uid: uid),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: StreamBuilder<int>(
          stream: _unreadCount,
          builder: (_, snap) {
            final count = snap.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: Color(0xFF374151), size: 26),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Notifications Screen ─────────────────────────────────────────────────────
class NotificationsScreen extends StatelessWidget {
  final String? uid;
  const NotificationsScreen({super.key, required this.uid});

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream {
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markRead(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF374151), size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _purple),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none_outlined,
                            size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d    = docs[i].data();
                    final read = d['read'] as bool? ?? false;
                    final type = d['type'] as String? ?? '';

                    Color dotColor;
                    IconData notifIcon;
                    if (type == 'approved') {
                      dotColor  = const Color(0xFF16A34A);
                      notifIcon = Icons.check_circle_outline;
                    } else if (type == 'rejected') {
                      dotColor  = Colors.redAccent;
                      notifIcon = Icons.cancel_outlined;
                    } else if (type == 'on_hold') {
                      dotColor  = const Color(0xFFF59E0B);
                      notifIcon = Icons.pause_circle_outline;
                    } else {
                      dotColor  = _purple;
                      notifIcon = Icons.notifications_outlined;
                    }

                    return GestureDetector(
                      onTap: () {
                        if (!read && uid != null) {
                          _markRead(uid!, docs[i].id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: read
                              ? Colors.white
                              : _purple.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: read
                                ? const Color(0xFFE5E7EB)
                                : _purple.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: dotColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(notifIcon,
                                  size: 18, color: dotColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['title'] as String? ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d['body'] as String? ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: const Color(0xFF6B7280),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!read)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String tabLabel;
  const _EmptyState({required this.tabLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 52, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(
            tabLabel == 'All'
                ? "You haven't submitted any ideas yet"
                : 'No $tabLabel ideas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tabLabel == 'All'
                ? 'Tap the + button on home to get started'
                : 'Check back later',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error: $message',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF6B7280),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}