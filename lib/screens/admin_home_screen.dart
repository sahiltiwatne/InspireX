import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_verify_profiles_screen.dart';
import 'admin_verify_ideas_screen.dart';

const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

class AdminHomeScreen extends StatelessWidget {
  final String adminName;
  const AdminHomeScreen({super.key, required this.adminName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_gradientStart, _gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: _purple.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back,',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: Colors.white
                                          .withOpacity(0.85))),
                              Text(adminName,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text('Admin Actions',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Text('Review and manage platform content',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF6B7280))),
                  const SizedBox(height: 20),

                  // Verify Profiles card
                  _AdminActionCard(
                    icon: Icons.people_outline,
                    title: 'Verify Profiles',
                    subtitle:
                    'Review submitted user profiles, check ID & KYC documents, approve or reject accounts.',
                    gradientColors: const [
                      Color(0xFF7C3AED),
                      Color(0xFF8B5CF6)
                    ],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const AdminVerifyProfilesScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Verify Ideas card
                  _AdminActionCard(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Verify Ideas',
                    subtitle:
                    'Review submitted idea submissions, check patent documents, approve or reject ideas for the marketplace.',
                    gradientColors: const [
                      Color(0xFF3B82F6),
                      Color(0xFF06B6D4)
                    ],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const AdminVerifyIdeasScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Stats row
                  Row(
                    children: [
                      _StatCard(
                          label: 'Pending Profiles',
                          icon: Icons.hourglass_empty_outlined,
                          color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: 'Pending Ideas',
                          icon: Icons.pending_outlined,
                          color: const Color(0xFF3B82F6)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text('InspireX',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _purple,
                        letterSpacing: 0.5)),
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Logout',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700)),
                    content: Text('Are you sure you want to logout?',
                        style:
                        GoogleFonts.plusJakartaSans(fontSize: 14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF6B7280))),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/login', (_) => false);
                        },
                        child: Text('Logout',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.logout,
                  color: Colors.redAccent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class _AdminActionCard extends StatelessWidget {
  final IconData        icon;
  final String          title;
  final String          subtitle;
  final List<Color>     gradientColors;
  final VoidCallback    onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Coloured left accent
            Container(
              width: 6,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                            height: 1.4)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right,
                  color: Color(0xFF9CA3AF), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card (live Firestore count) ────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  Stream<int> _countStream() {
    if (label.contains('Profile')) {
      // Count users where profileStatus is null OR 'pending'
      return FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .map((s) => s.docs.where((d) {
        final status = d.data()['profileStatus'] as String?;
        return status == null || status == 'pending';
      }).length);
    } else {
      return FirebaseFirestore.instance
          .collectionGroup('ideas')
          .snapshots()
          .map((s) => s.docs.where((d) {
        final status = d.data()['status'] as String?;
        return status == null ||
            status == 'pending' ||
            status == 'pending_review';
      }).length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: StreamBuilder<int>(
          stream: _countStream(),
          builder: (_, snap) {
            final count = snap.data ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 10),
                Text('$count',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF6B7280))),
              ],
            );
          },
        ),
      ),
    );
  }
}
