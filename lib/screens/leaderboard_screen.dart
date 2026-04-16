import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Constants (mirrors home_screen.dart) ──────────────────────────────────
const _purple = Color(0xFF7C3AED);
const _purpleLight = Color(0xFF8B5CF6);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd = Color(0xFF3B82F6);
const _bgColor = Color(0xFFF8FAFC);

// ─── Data model ─────────────────────────────────────────────────────────────
class SoldIdea {
  final String id;
  final String title;
  final String category;
  final bool isPatented;
  final int soldPrice;
  final String contributor;
  final String buyer;
  final DateTime soldDate;
  final int rank;

  const SoldIdea({
    required this.id,
    required this.title,
    required this.category,
    required this.isPatented,
    required this.soldPrice,
    required this.contributor,
    required this.buyer,
    required this.soldDate,
    required this.rank,
  });
}

// ─── Sample data ─────────────────────────────────────────────────────────────
final List<SoldIdea> _topSoldIdeas = [
  SoldIdea(
    id: '1',
    title: 'AI Code Review Assistant',
    category: 'AI',
    isPatented: true,
    soldPrice: 520000,
    contributor: 'Alex Kumar',
    buyer: 'Microsoft',
    soldDate: DateTime(2024, 11, 15),
    rank: 1,
  ),
  SoldIdea(
    id: '2',
    title: 'Blockchain-Based Supply Chain Tracker',
    category: 'Blockchain',
    isPatented: true,
    soldPrice: 485000,
    contributor: 'Michael Rodriguez',
    buyer: 'IBM',
    soldDate: DateTime(2024, 11, 10),
    rank: 2,
  ),
  SoldIdea(
    id: '3',
    title: 'Smart Home Energy Optimizer',
    category: 'IoT',
    isPatented: true,
    soldPrice: 445000,
    contributor: 'Emily Johnson',
    buyer: 'Google',
    soldDate: DateTime(2024, 11, 8),
    rank: 3,
  ),
  SoldIdea(
    id: '4',
    title: 'Sustainable Packaging Solution',
    category: 'Sustainability',
    isPatented: false,
    soldPrice: 380000,
    contributor: 'Maria Santos',
    buyer: 'Unilever',
    soldDate: DateTime(2024, 11, 5),
    rank: 4,
  ),
  SoldIdea(
    id: '5',
    title: 'Virtual Reality Therapy Platform',
    category: 'Healthcare',
    isPatented: true,
    soldPrice: 365000,
    contributor: 'Dr. James Wilson',
    buyer: 'Meta',
    soldDate: DateTime(2024, 11, 1),
    rank: 5,
  ),
  SoldIdea(
    id: '6',
    title: 'AI-Powered Meal Planning Assistant',
    category: 'Food',
    isPatented: true,
    soldPrice: 325000,
    contributor: 'Sarah Chen',
    buyer: 'Uber Eats',
    soldDate: DateTime(2024, 10, 28),
    rank: 6,
  ),
  SoldIdea(
    id: '7',
    title: 'Autonomous Delivery Drone Network',
    category: 'Automobile',
    isPatented: true,
    soldPrice: 298000,
    contributor: 'Tech Innovations Inc',
    buyer: 'Amazon',
    soldDate: DateTime(2024, 10, 25),
    rank: 7,
  ),
];

// ─── LeaderboardScreen ───────────────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  bool _drawerOpen = false;
  late AnimationController _drawerController;
  late Animation<double> _drawerSlide;

  static const double _navHeight = 64.0;

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
    if (index == 3) return; // already on leaderboard
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 1. Scaffold ───────────────────────────────────────────────────
        Scaffold(
          backgroundColor: _bgColor,
          body: _buildMainContent(),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _buildFAB(),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
        ),

        // ── 2. Scrim ──────────────────────────────────────────────────────
        if (_drawerOpen)
          GestureDetector(
            onTap: _closeDrawer,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        // ── 3. Drawer ─────────────────────────────────────────────────────
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                ..._topSoldIdeas.map((idea) => _SoldIdeaCard(idea: idea)),
                const SizedBox(height: 8),
                _buildMarketInsights(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Hamburger → opens drawer (not back navigation)
          GestureDetector(
            onTap: _toggleDrawer,
            child:
            const Icon(Icons.menu, color: Color(0xFF374151), size: 26),
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
          Container(
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
            child:
            const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Left Drawer (identical to home_screen.dart) ───────────────────────────
  Widget _buildDrawer() {
    return Material(
      elevation: 16,
      child: SizedBox(
        width: 280,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
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
                                    color: Colors.white70,
                                    fontSize: 13)),
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

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () {
                      _closeDrawer();
                      Navigator.popUntil(
                          context, (route) => route.isFirst);
                    },
                  ),
                  _DrawerItem(
                      icon: Icons.trending_up_outlined,
                      label: 'My Ideas',
                      onTap: _closeDrawer),
                  _DrawerItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: _closeDrawer),
                  _DrawerItem(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      onTap: _closeDrawer),
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

  // ── Bottom Navigation — Leaderboard tab highlighted ───────────────────────
  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        bottomAppBarTheme:
        const BottomAppBarThemeData(height: _navHeight),
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
                    selected: false,
                    onTap: () => _onBottomNavTap(0)),
                _BottomNavItem(
                    icon: Icons.search,
                    label: 'Search',
                    selected: false,
                    onTap: () => _onBottomNavTap(1)),
                const Expanded(child: SizedBox()), // FAB notch space
                _BottomNavItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Leaderboard',
                    selected: true, // ← highlighted
                    onTap: () => _onBottomNavTap(3)),
                _BottomNavItem(
                    icon: Icons.gavel_outlined,
                    label: 'Bidding',
                    selected: false,
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

  // ── Trophy header ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.emoji_events,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 14),
        Text(
          'Top Sold Ideas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Celebrating the most successful innovations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Market Insights card ──────────────────────────────────────────────────
  Widget _buildMarketInsights() {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Insights',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _InsightRow(label: 'Total Ideas Sold', value: '127'),
          const SizedBox(height: 12),
          _InsightRow(
              label: 'Average Sold Price', value: '\$346,000'),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'Highest Bid',
            value: '\$520,000',
            valueColor: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}

// ─── Sold Idea Card ──────────────────────────────────────────────────────────
class _SoldIdeaCard extends StatelessWidget {
  final SoldIdea idea;
  const _SoldIdeaCard({required this.idea});

  LinearGradient _rankGradient() {
    if (idea.rank == 1) {
      return const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (idea.rank == 2) {
      return const LinearGradient(
        colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (idea.rank == 3) {
      return const LinearGradient(
        colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [_gradientStart, _gradientEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = idea.rank <= 3;
    final formattedDate =
        '${idea.soldDate.month}/${idea.soldDate.day}/${idea.soldDate.year}';
    final formattedPrice =
        '\$${idea.soldPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isTopThree
            ? Border.all(
            color: _purpleLight.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            // ── Rank badge + title ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _rankGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '#${idea.rank}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              idea.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                              softWrap: true,
                            ),
                          ),
                          if (isTopThree) ...[
                            const SizedBox(width: 4),
                            const Text('🏆',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ${idea.contributor}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Details ─────────────────────────────────────────────────────
            _DetailRow(
              label: 'Category:',
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  idea.category,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _purple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            _DetailRow(
              label: 'Patent Status:',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    idea.isPatented
                        ? Icons.verified_outlined
                        : Icons.block_outlined,
                    size: 16,
                    color: idea.isPatented
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    idea.isPatented ? 'Patented' : 'Not Patented',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: idea.isPatented
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _DetailRow(
              label: 'Buyer:',
              child: Text(
                idea.buyer,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 10),

            _DetailRow(
              label: 'Sold Date:',
              child: Text(
                formattedDate,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Sold Price banner ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFBBF7D0), width: 1),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sold Price',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF166534),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedPrice,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Row ───────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: child),
      ],
    );
  }
}

// ─── Insight Row ─────────────────────────────────────────────────────────────
class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InsightRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// ─── Drawer Item ─────────────────────────────────────────────────────────────
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

// ─── Bottom Nav Item ─────────────────────────────────────────────────────────
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
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
                color:
                selected ? _purple : const Color(0xFF9CA3AF)),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? _purple : const Color(0xFF9CA3AF),
                fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}