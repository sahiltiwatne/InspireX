import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_screen.dart';
import 'submit_idea_screen.dart';
import 'leaderboard_screen.dart';
import 'all_bidding_screen.dart';
import 'profile_screen.dart';
import 'idea_bidding_screen.dart';
import 'idea_detail_screen.dart';
import 'my_ideas_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Placeholder screen ───────────────────────────────────────────────────────
class LiveBiddingScreen extends StatelessWidget {
  const LiveBiddingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Live Bidding', style: _appBarTextStyle())),
    body: const Center(
        child: Text('Live Bidding Screen – Upcoming / Ongoing / Completed')),
  );
}

TextStyle _appBarTextStyle() => GoogleFonts.plusJakartaSans(
  fontWeight: FontWeight.w600,
  fontSize: 18,
);

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── Dummy seed ideas (same as search_screen) ─────────────────────────────────
final _seedIdeas = [
  {
    'title': 'AI-Powered Meal Planning Assistant',
    'detailedSolution':
    'An intelligent system that creates personalized meal plans based on dietary restrictions, budget, and local ingredient availability.',
    'likes': 245,
    'aiRating': 4.5,
    'category': 'Food',
    'isPatented': true,
    'approvedAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
    'contributorName': 'Rahul Sharma',
    'isSeeded': true,
  },
  {
    'title': 'Blockchain-Based Supply Chain Tracker',
    'detailedSolution':
    'Real-time tracking solution for supply chain management using blockchain technology to ensure transparency and reduce fraud.',
    'likes': 189,
    'aiRating': 4.2,
    'category': 'Blockchain',
    'isPatented': false,
    'approvedAt': DateTime(2024, 1, 2).millisecondsSinceEpoch,
    'contributorName': 'Priya Patel',
    'isSeeded': true,
  },
  {
    'title': 'Smart Home Energy Optimizer',
    'detailedSolution':
    'IoT device that learns your energy consumption patterns and automatically optimizes power usage to reduce bills by up to 40%.',
    'likes': 312,
    'aiRating': 4.8,
    'category': 'IoT',
    'isPatented': true,
    'approvedAt': DateTime(2024, 1, 3).millisecondsSinceEpoch,
    'contributorName': 'Amit Kumar',
    'isSeeded': true,
  },
  {
    'title': 'Virtual Reality Therapy Platform',
    'detailedSolution':
    'VR-based mental health platform providing immersive therapy sessions for anxiety, PTSD, and phobias with licensed therapists.',
    'likes': 278,
    'aiRating': 4.6,
    'category': 'Healthcare',
    'isPatented': false,
    'approvedAt': DateTime(2024, 1, 4).millisecondsSinceEpoch,
    'contributorName': 'Neha Gupta',
    'isSeeded': true,
  },
  {
    'title': 'AI Code Review Assistant',
    'detailedSolution':
    'Automated code review tool powered by machine learning that identifies bugs, security vulnerabilities, and suggests optimizations.',
    'likes': 421,
    'aiRating': 4.9,
    'category': 'AI',
    'isPatented': true,
    'approvedAt': DateTime(2024, 1, 5).millisecondsSinceEpoch,
    'contributorName': 'Vikram Singh',
    'isSeeded': true,
  },
  {
    'title': 'Sustainable Packaging Solution',
    'detailedSolution':
    'Biodegradable packaging material made from agricultural waste that decomposes within 30 days and costs less than plastic.',
    'likes': 356,
    'aiRating': 4.7,
    'category': 'Sustainability',
    'isPatented': false,
    'approvedAt': DateTime(2024, 1, 6).millisecondsSinceEpoch,
    'contributorName': 'Ananya Roy',
    'isSeeded': true,
  },
  {
    'title': 'Smart Restaurant Inventory System',
    'detailedSolution':
    'AI-driven inventory management for restaurants that predicts demand and reduces food waste by 50%.',
    'likes': 198,
    'aiRating': 4.3,
    'category': 'Food',
    'isPatented': false,
    'approvedAt': DateTime(2024, 1, 7).millisecondsSinceEpoch,
    'contributorName': 'Suresh Nair',
    'isSeeded': true,
  },
  {
    'title': 'Autonomous Delivery Drone Network',
    'detailedSolution':
    'Urban delivery system using autonomous drones for last-mile delivery, reducing delivery times by 70%.',
    'likes': 334,
    'aiRating': 4.4,
    'category': 'Automobile',
    'isPatented': true,
    'approvedAt': DateTime(2024, 1, 8).millisecondsSinceEpoch,
    'contributorName': 'Kavya Menon',
    'isSeeded': true,
  },
];

// ─── Seed helper — runs once; skips if seed docs already exist ────────────────
Future<void> _seedApprovedIdeasIfEmpty() async {
  final col = FirebaseFirestore.instance.collection('approved_ideas');
  final existing = await col
      .where('isSeeded', isEqualTo: true)
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) return; // already seeded
  final batch = FirebaseFirestore.instance.batch();
  for (final idea in _seedIdeas) {
    batch.set(col.doc(), idea);
  }
  await batch.commit();
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int  _selectedIndex = 0;
  bool _drawerOpen    = false;

  late AnimationController _drawerController;
  late Animation<double>   _drawerSlide;

  static const double _navHeight = 64.0;
  static const double _fabSize   = 52.0;

  // ── Stream: approved_ideas ordered newest first ───────────────────────────
  final Stream<QuerySnapshot<Map<String, dynamic>>> _approvedIdeasStream =
  FirebaseFirestore.instance
      .collection('approved_ideas')
      .orderBy('approvedAt', descending: true)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _drawerSlide = CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeInOut,
    );
    // Seed dummy ideas into Firestore if the collection is empty
    _seedApprovedIdeasIfEmpty();
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
    _drawerOpen
        ? _drawerController.forward()
        : _drawerController.reverse();
  }

  void _closeDrawer() {
    if (_drawerOpen) {
      setState(() => _drawerOpen = false);
      _drawerController.reverse();
    }
  }

  void _onBottomNavTap(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 1:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen()));
        break;
      case 2:
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmitIdeaScreen()));
        break;
      case 3:
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        break;
      case 4:
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllBiddingScreen()));
        break;
      default:
        setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bgColor,
          body: _buildMainContent(),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _buildFAB(),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
        ),
        if (_drawerOpen)
          GestureDetector(
            onTap: _closeDrawer,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
        AnimatedBuilder(
          animation: _drawerSlide,
          builder: (_, __) => Transform.translate(
            offset: Offset((_drawerSlide.value - 1) * 280, 0),
            child: _buildDrawer(),
          ),
        ),
      ],
    );
  }

  // ── Main scrollable content ───────────────────────────────────────────────
  Widget _buildMainContent() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _approvedIdeasStream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _purple),
                  );
                }

                final docs = snap.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      'Discover Ideas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore innovative startup concepts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 52, color: Color(0xFFD1D5DB)),
                            const SizedBox(height: 12),
                            Text(
                              'No ideas yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to submit an idea!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...docs.map((doc) {
                        final d = doc.data();
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IdeaDetailScreen(
                                ideaId:          doc.id,
                                title:           d['title']       as String? ?? '',
                                description:     d['detailedSolution'] as String? ??
                                    d['problemStatement'] as String? ?? '',
                                likes:           d['likes']       as int?    ?? 0,
                                aiRating:        (d['aiRating']   as num?)?.toDouble() ?? 4.0,
                                industry:        d['category']    as String? ?? '',
                                isPatented:      d['isPatented']  as bool?   ?? false,
                                contributorName: d['contributorName'] as String? ?? 'Innovator',
                              ),
                            ),
                          ),
                          child: _IdeaCardWidget(
                            data: d,
                            docId: doc.id,
                            onBidTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IdeaBiddingScreen(
                                    ideaTitle: d['title'] as String? ?? ''),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Custom AppBar ─────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleDrawer,
            child: const Icon(Icons.menu, color: Color(0xFF374151), size: 26),
          ),
          Expanded(
            child: Center(
              child: Text(
                'InspireX',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _purple,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Left Drawer ───────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Material(
      elevation: 16,
      child: SizedBox(
        width: 280,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.25),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('John Doe',
                                style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text('Investor',
                                style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _closeDrawer,
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _DrawerItem(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      onTap: _closeDrawer),
                  _DrawerItem(
                      icon: Icons.trending_up_outlined,
                      label: 'My Ideas',
                      onTap: () {
                        _closeDrawer();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyIdeasScreen()),
                        );
                      }),
                  _DrawerItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {
                        _closeDrawer();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(uid: null),
                          ),
                        );
                      }),
                  _DrawerItem(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      onTap: () {
                        _closeDrawer();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      }),
                  _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: _closeDrawer),
                  _DrawerItem(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: _closeDrawer),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            InkWell(
              onTap: () async {
                _closeDrawer();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 12),
                    Text('Logout',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        bottomAppBarTheme: const BottomAppBarThemeData(height: _navHeight),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          color: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: _navHeight,
            child: Row(
              children: [
                _BottomNavItem(
                    icon: Icons.home,
                    label: 'Home',
                    selected: _selectedIndex == 0,
                    onTap: () => _onBottomNavTap(0)),
                _BottomNavItem(
                    icon: Icons.search,
                    label: 'Search',
                    selected: _selectedIndex == 1,
                    onTap: () => _onBottomNavTap(1)),
                const Expanded(child: SizedBox()),
                _BottomNavItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Leaderboard',
                    selected: _selectedIndex == 3,
                    onTap: () => _onBottomNavTap(3)),
                _BottomNavItem(
                    icon: Icons.gavel_outlined,
                    label: 'Bidding',
                    selected: _selectedIndex == 4,
                    onTap: () => _onBottomNavTap(4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Transform.translate(
      offset: const Offset(0, 12),
      child: GestureDetector(
        onTap: () => _onBottomNavTap(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _fabSize,
              height: _fabSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x557C3AED),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 7),
            const Text(
              'Submit',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Idea Card Widget (Firestore-backed) ──────────────────────────────────────
class _IdeaCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onBidTap;

  const _IdeaCardWidget({
    required this.data,
    required this.docId,
    required this.onBidTap,
  });

  @override
  Widget build(BuildContext context) {
    final title      = data['title']            as String? ?? 'Untitled';
    final desc       = data['detailedSolution'] as String? ??
        data['problemStatement']                as String? ?? '';
    final likes      = data['likes']            as int?    ?? 0;
    final aiRating   = (data['aiRating']        as num?)?.toDouble() ?? 4.0;
    final industry   = data['category']         as String? ?? '';
    final isPatented = data['isPatented']       as bool?   ?? false;
    final contributor = data['contributorName'] as String? ?? 'Innovator';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contributor row ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                    ),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  contributor,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),

            // ── Likes + Rating ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.thumb_up_alt_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text('$likes',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                Text('AI Rating:',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: const Color(0xFF6B7280))),
                const SizedBox(width: 4),
                _StarRating(rating: aiRating),
                const SizedBox(width: 4),
                Text(aiRating.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 10),

            // ── Tags ────────────────────────────────────────────────────
            Row(
              children: [
                if (industry.isNotEmpty)
                  _Tag(
                    label: industry,
                    color: const Color(0xFFFFF3E0),
                    textColor: const Color(0xFFE65100),
                  ),
                if (industry.isNotEmpty) const SizedBox(width: 8),
                _PatentTag(isPatented: isPatented),
              ],
            ),
            const SizedBox(height: 14),

            // ── CTA ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 46,
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
                  onPressed: onBidTap,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Interested? Start Bidding',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w600),
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

// ─── Star Rating ──────────────────────────────────────────────────────────────
class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half   = !filled && (i < rating);
        return Icon(
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          size: 15,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }
}

// ─── Tag ──────────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Tag(
      {required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor)),
    );
  }
}

// ─── Patent Tag ───────────────────────────────────────────────────────────────
class _PatentTag extends StatelessWidget {
  final bool isPatented;
  const _PatentTag({required this.isPatented});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPatented
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPatented ? Icons.verified_outlined : Icons.block_outlined,
            size: 13,
            color: isPatented
                ? const Color(0xFF2E7D32)
                : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(
            isPatented ? 'Patented' : 'Not Patented',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isPatented
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Drawer Item ──────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _purple, size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF374151),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Nav Item ──────────────────────────────────────────────────────────
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BottomNavItem(
      {required this.icon,
        required this.label,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 28,
                color: selected ? _purple : const Color(0xFF9CA3AF)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? _purple : const Color(0xFF9CA3AF),
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}
