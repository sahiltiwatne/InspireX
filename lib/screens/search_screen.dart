import 'package:flutter/material.dart';
import 'idea_detail_screen.dart';
import 'idea_bidding_screen.dart';
import 'my_ideas_screen.dart';
import 'profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── Category config ──────────────────────────────────────────────────────────
const _categories = [
  'Food', 'AI', 'Automobile', 'Healthcare',
  'Blockchain', 'IoT', 'Sustainability',
];

const _categoryGradients = <String, List<Color>>{
  'Food':          [Color(0xFFF97316), Color(0xFFEA580C)],
  'AI':            [Color(0xFFA855F7), Color(0xFF7C3AED)],
  'Automobile':    [Color(0xFF60A5FA), Color(0xFF2563EB)],
  'Healthcare':    [Color(0xFFF87171), Color(0xFFDC2626)],
  'Blockchain':    [Color(0xFF22D3EE), Color(0xFF0891B2)],
  'IoT':           [Color(0xFF4ADE80), Color(0xFF16A34A)],
  'Sustainability':[Color(0xFF34D399), Color(0xFF059669)],
};

const _tagColors = <String, Color>{
  'Food':          Color(0xFFFFF3E0),
  'AI':            Color(0xFFF3E8FF),
  'Automobile':    Color(0xFFEFF6FF),
  'Healthcare':    Color(0xFFFEF2F2),
  'Blockchain':    Color(0xFFECFEFF),
  'IoT':           Color(0xFFF0FDF4),
  'Sustainability':Color(0xFFECFDF5),
};

const _tagTextColors = <String, Color>{
  'Food':          Color(0xFFE65100),
  'AI':            Color(0xFF6D28D9),
  'Automobile':    Color(0xFF1D4ED8),
  'Healthcare':    Color(0xFFDC2626),
  'Blockchain':    Color(0xFF0E7490),
  'IoT':           Color(0xFF15803D),
  'Sustainability':Color(0xFF047857),
};

// ─── Investor model (local only, not Firestore) ───────────────────────────────
class _Investor {
  final String id;
  final String name;
  final String designation;
  final String company;
  final Color  avatarColor;

  const _Investor({
    required this.id,
    required this.name,
    required this.designation,
    required this.company,
    required this.avatarColor,
  });
}

const _investorAvatarColors = <Color>[
  Color(0xFF7C3AED),
  Color(0xFFEC4899),
  Color(0xFFF97316),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
];

final _investors = <_Investor>[
  _Investor(id: '1', name: 'Rahul Sharma',  designation: 'CEO',                company: 'Flipkart',        avatarColor: _investorAvatarColors[0]),
  _Investor(id: '2', name: 'Priya Patel',   designation: 'Investment Director', company: 'Sequoia Capital', avatarColor: _investorAvatarColors[1]),
  _Investor(id: '3', name: 'Amit Kumar',    designation: 'Managing Partner',    company: 'Accel Partners',  avatarColor: _investorAvatarColors[2]),
  _Investor(id: '4', name: 'Neha Gupta',    designation: 'VP of Investments',   company: 'SoftBank',        avatarColor: _investorAvatarColors[3]),
  _Investor(id: '5', name: 'Vikram Singh',  designation: 'Angel Investor',      company: 'Independent',     avatarColor: _investorAvatarColors[4]),
];

// ─── SearchScreen ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;

  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<String> _invitedIds = {};

  bool _drawerOpen = false;
  late AnimationController _drawerController;
  late Animation<double>   _drawerSlide;

  // ── Live stream from the shared approved_ideas collection ─────────────────
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  // ── Drawer helpers ────────────────────────────────────────────────────────
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

  // ── Client-side filtering ─────────────────────────────────────────────────
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var filtered = docs;

    if (_selectedCategory != null) {
      filtered = filtered
          .where((d) => d.data()['category'] == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final data = d.data();
        final title = (data['title'] as String? ?? '').toLowerCase();
        final desc  = (data['detailedSolution'] as String? ??
            data['problemStatement'] as String? ?? '').toLowerCase();
        final cat   = (data['category'] as String? ?? '').toLowerCase();
        return title.contains(q) || desc.contains(q) || cat.contains(q);
      }).toList();
    }

    return filtered;
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  void _onBottomNavTap(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) Navigator.pop(context);
  }

  // ── Invite ────────────────────────────────────────────────────────────────
  void _sendInvite(_Investor investor) {
    setState(() => _invitedIds.add(investor.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Invitation sent to ${investor.name}!',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        backgroundColor: _purple,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Navigate to detail ────────────────────────────────────────────────────
  void _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IdeaDetailScreen(
          ideaId:          doc.id,
          title:           d['title']            as String? ?? '',
          description:     d['detailedSolution'] as String? ??
              d['problemStatement']              as String? ?? '',
          likes:           d['likes']            as int?    ?? 0,
          aiRating:        (d['aiRating']        as num?)?.toDouble() ?? 4.0,
          industry:        d['category']         as String? ?? '',
          isPatented:      d['isPatented']       as bool?   ?? false,
          contributorName: d['contributorName']  as String? ?? 'Innovator',
        ),
      ),
    );
  }

  // ── Navigate to bidding ───────────────────────────────────────────────────
  void _openBidding(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IdeaBiddingScreen(ideaTitle: title),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bgColor,
          body: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _approvedIdeasStream,
                  builder: (_, snap) {
                    // ── Loading ───────────────────────────────────────
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _purple),
                      );
                    }

                    final allDocs  = snap.data?.docs ?? [];
                    final filtered = _filterDocs(allDocs);

                    return ListView(
                      padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildCategorySection(),
                        const SizedBox(height: 20),
                        _buildIdeasSection(filtered),
                        const SizedBox(height: 24),
                        _buildInvestorsSection(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _buildFAB(),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
        ),

        // ── Scrim ─────────────────────────────────────────────────────
        if (_drawerOpen)
          GestureDetector(
            onTap: _closeDrawer,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        // ── Drawer ────────────────────────────────────────────────────
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

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleDrawer,
              child: const Icon(Icons.menu,
                  color: Color(0xFF374151), size: 26),
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
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
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
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 22),
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
                    onTap: () {
                      _closeDrawer();
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                  ),
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
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {
                      _closeDrawer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(uid: null),
                        ),
                      );
                    },
                  ),
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
                    },
                  ),
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
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    const Icon(Icons.logout,
                        color: Colors.redAccent, size: 22),
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

  // ── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText: 'Search for interesting ideas...',
          hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search,
              color: Color(0xFF9CA3AF), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close,
                color: Color(0xFF9CA3AF), size: 20),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Browse by Category',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final colors     = _categoryGradients[cat]!;
            return GestureDetector(
              onTap: () => setState(() =>
              _selectedCategory =
              _selectedCategory == cat ? null : cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Ideas Section ─────────────────────────────────────────────────────────
  Widget _buildIdeasSection(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedCategory != null ? '$_selectedCategory Ideas' : 'All Ideas',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No ideas found.',
                style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
          )
        else
          ...docs.map((doc) {
            final d = doc.data();
            return GestureDetector(
              onTap: () => _openDetail(doc),
              child: _IdeaCardWidget(
                data: d,
                onBidTap: () =>
                    _openBidding(d['title'] as String? ?? ''),
              ),
            );
          }),
      ],
    );
  }

  // ── Investors Section ─────────────────────────────────────────────────────
  Widget _buildInvestorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Investors',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        ..._investors.map((inv) => _InvestorCard(
          investor:  inv,
          isInvited: _invitedIds.contains(inv.id),
          onInvite:  () => _sendInvite(inv),
        )),
      ],
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        bottomAppBarTheme: const BottomAppBarThemeData(height: 64),
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
            height: 64,
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
        onTap: () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
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

// ─── Idea Card (Firestore-backed) ─────────────────────────────────────────────
class _IdeaCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onBidTap;

  const _IdeaCardWidget({
    required this.data,
    required this.onBidTap,
  });

  @override
  Widget build(BuildContext context) {
    final title       = data['title']            as String? ?? 'Untitled';
    final desc        = data['detailedSolution'] as String? ??
        data['problemStatement']                 as String? ?? '';
    final likes       = data['likes']            as int?    ?? 0;
    final aiRating    = (data['aiRating']        as num?)?.toDouble() ?? 4.0;
    final category    = data['category']         as String? ?? '';
    final isPatented  = data['isPatented']       as bool?   ?? false;
    final contributor = data['contributorName']  as String? ?? 'Innovator';

    final tagBg   = _tagColors[category]     ?? const Color(0xFFF3F4F6);
    final tagText = _tagTextColors[category] ?? const Color(0xFF374151);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contributor ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [_gradientStart, _gradientEnd]),
                  ),
                  child:
                  const Icon(Icons.person, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  contributor,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(title,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.45)),
            const SizedBox(height: 12),

            // Likes + AI Rating
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

            // Tags
            Row(
              children: [
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(category,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tagText)),
                  ),
                if (category.isNotEmpty) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                        isPatented
                            ? Icons.verified_outlined
                            : Icons.block_outlined,
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
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bid button
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
                  child: Text('Interested? Start Bidding',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600)),
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
        final half   = !filled && i < rating;
        return Icon(
          half ? Icons.star_half : filled ? Icons.star : Icons.star_border,
          size: 15,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }
}

// ─── Investor Card ────────────────────────────────────────────────────────────
class _InvestorCard extends StatelessWidget {
  final _Investor    investor;
  final bool         isInvited;
  final VoidCallback onInvite;

  const _InvestorCard({
    required this.investor,
    required this.isInvited,
    required this.onInvite,
  });

  String _initials(String name) =>
      name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: investor.avatarColor,
              ),
              child: Center(
                child: Text(
                  _initials(investor.name),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(investor.name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(
                    '${investor.designation} at ${investor.company}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isInvited ? null : onInvite,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isInvited
                      ? null
                      : const LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  color: isInvited ? const Color(0xFFF3F4F6) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInvited
                          ? Icons.check
                          : Icons.person_add_alt_1_outlined,
                      size: 15,
                      color: isInvited
                          ? const Color(0xFF6B7280)
                          : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isInvited ? 'Invited' : 'Connect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isInvited
                            ? const Color(0xFF6B7280)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drawer Item ──────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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