import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── Bid model ────────────────────────────────────────────────────────────────
class _Bid {
  final String   id;
  final String   investorName;
  final int      amount;
  final DateTime timestamp;
  final bool     isMe;

  const _Bid({
    required this.id,
    required this.investorName,
    required this.amount,
    required this.timestamp,
    this.isMe = false,
  });
}

// ─── Avatar colours ───────────────────────────────────────────────────────────
const _avatarColors = [
  Color(0xFFEC4899),
  Color(0xFFF97316),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
];

// ─── IdeaBiddingScreen ────────────────────────────────────────────────────────
class IdeaBiddingScreen extends StatefulWidget {
  final String ideaTitle;
  final bool   isPatented;

  const IdeaBiddingScreen({
    super.key,
    required this.ideaTitle,
    this.isPatented = true,
  });

  @override
  State<IdeaBiddingScreen> createState() => _IdeaBiddingScreenState();
}

class _IdeaBiddingScreenState extends State<IdeaBiddingScreen> {
  Timer? _countdownTimer;
  Timer? _autoBidTimer;
  final ScrollController _scrollController = ScrollController();

  late int        _basePrice;
  late int        _currentPrice;
  int             _timeRemaining = 3600;
  late List<_Bid> _bids;
  bool            _biddingEnded = false;

  final _customAmountController = TextEditingController();
  final List<int> _quickBids = [500, 1000, 1500, 2000, 5000, 10000];

  final List<Map<String, dynamic>> _otherBidders = [
    {'name': 'Michael Chen',   'color': _avatarColors[4]},
    {'name': 'Sarah Williams', 'color': _avatarColors[0]},
    {'name': 'Robert Johnson', 'color': _avatarColors[1]},
    {'name': 'Emily Davis',    'color': _avatarColors[2]},
    {'name': 'David Martinez', 'color': _avatarColors[3]},
  ];

  @override
  void initState() {
    super.initState();
    _basePrice    = widget.isPatented ? 150000 : 85000;
    _currentPrice = _basePrice;

    final now = DateTime.now();
    _bids = [
      _Bid(id: '1', investorName: 'Michael Chen',   amount: 5000,  timestamp: now.subtract(const Duration(minutes: 3))),
      _Bid(id: '2', investorName: 'Sarah Williams', amount: 10000, timestamp: now.subtract(const Duration(minutes: 2))),
      _Bid(id: '3', investorName: 'Robert Johnson', amount: 2000,  timestamp: now.subtract(const Duration(minutes: 1, seconds: 30))),
      _Bid(id: '4', investorName: 'Emily Davis',    amount: 15000, timestamp: now.subtract(const Duration(minutes: 1))),
      _Bid(id: '5', investorName: 'David Martinez', amount: 8000,  timestamp: now.subtract(const Duration(seconds: 30))),
    ];
    _currentPrice = _basePrice + _bids.fold(0, (sum, b) => sum + b.amount);

    _startCountdown();
    _startAutoBids();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoBidTimer?.cancel();
    _scrollController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _biddingEnded = true;
          _countdownTimer?.cancel();
          _autoBidTimer?.cancel();
        }
      });
    });
  }

  void _startAutoBids() {
    _autoBidTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _biddingEnded) return;
      final bidder = (_otherBidders..shuffle()).first;
      final amounts = [500, 1000, 2000, 3000, 5000];
      final amount  = (amounts..shuffle()).first as int;
      _addBid(bidder['name'] as String, amount,
          isMe: false, color: bidder['color'] as Color);
    });
  }

  void _addBid(String name, int amount,
      {bool isMe = false, Color? color}) {
    final bid = _Bid(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      investorName: name,
      amount: amount,
      timestamp: DateTime.now(),
      isMe: isMe,
    );
    setState(() {
      _bids.add(bid);
      _currentPrice += amount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _placeBid(int amount) {
    if (_biddingEnded) return;
    _addBid('You', amount, isMe: true);
  }

  void _showCustomAmountDialog() {
    _customAmountController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Enter Custom Amount',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827))),
            const SizedBox(height: 10),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0',
                hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _purple, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextButton(
                  onPressed: () {
                    final val = int.tryParse(
                        _customAmountController.text.trim());
                    if (val != null && val > 0) {
                      Navigator.pop(context);
                      _placeBid(val);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Place Bid',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(1, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _initials(String name) =>
      name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

  Color _colorFor(String name) {
    final idx = name.hashCode.abs() % _avatarColors.length;
    return _avatarColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          _buildInfoStrip(),
          Expanded(child: _buildBidFeed()),
          if (!_biddingEnded) _buildQuickBidPanel(),
          if (_biddingEnded)  _buildEndedBanner(),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF374151), size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.ideaTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,           // ↓ was 18
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ── Timer + price strip ───────────────────────────────────────────────────
  Widget _buildInfoStrip() {
    final isUrgent = _timeRemaining < 600 && !_biddingEnded;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        children: [
          // Timer row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_outlined,
                  color: isUrgent ? Colors.redAccent : _purple, size: 16), // ↓ was 20
              const SizedBox(width: 5),
              Column(
                children: [
                  Text('Time Remaining',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,           // ↓ was 12
                          color: const Color(0xFF6B7280))),
                  Text(
                    _biddingEnded ? 'Ended' : _formatTime(_timeRemaining),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,               // ↓ was 20
                      fontWeight: FontWeight.w700, // ↓ was w800
                      color: _biddingEnded
                          ? const Color(0xFF6B7280)
                          : isUrgent
                          ? Colors.redAccent
                          : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Current bid card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // ↓ was 12/16
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _purple.withOpacity(0.06),
                  _gradientEnd.withOpacity(0.06),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('Current Bid',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,           // ↓ was 13
                        color: const Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(
                  '\$${_currentPrice.toLocaleString()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,               // ↓ was 26
                    fontWeight: FontWeight.w700, // ↓ was w800
                    color: _purple,
                  ),
                ),
                Text(
                  'Base: \$${_basePrice.toLocaleString()}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,             // ↓ was 12
                      color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bid feed ──────────────────────────────────────────────────────────────
  Widget _buildBidFeed() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: _bids.length,
      itemBuilder: (_, i) => _buildBidBubble(_bids[i]),
    );
  }

  Widget _buildBidBubble(_Bid bid) {
    final isMe = bid.isMe;
    final avatarColor = isMe ? _purple : _colorFor(bid.investorName);
    final timeStr = '${bid.timestamp.hour.toString().padLeft(2, '0')}:'
        '${bid.timestamp.minute.toString().padLeft(2, '0')} '
        '${bid.timestamp.hour < 12 ? 'AM' : 'PM'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // ↓ was 12
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar left (others)
          if (!isMe) ...[
            Container(
              width: 34,                          // ↓ was 40
              height: 34,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: avatarColor),
              child: Center(
                child: Text(_initials(bid.investorName),
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,             // ↓ was 13
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 7),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),  // ↓ was 14/12
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(isMe ? 14 : 3),
                  bottomRight: Radius.circular(isMe ? 3 : 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    bid.investorName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,               // ↓ was 13
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+\$${bid.amount.toLocaleString()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,               // ↓ was 16
                      fontWeight: FontWeight.w700, // ↓ was w800
                      color: isMe
                          ? Colors.white
                          : const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,               // ↓ was 11
                      color: isMe
                          ? Colors.white.withOpacity(0.65)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar right (me)
          if (isMe) ...[
            const SizedBox(width: 7),
            Container(
              width: 34,                          // ↓ was 40
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 17),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick bid panel ───────────────────────────────────────────────────────
  Widget _buildQuickBidPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18), // ↓ was 16/12/20
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Quick Bid',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,                   // ↓ was 13
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 2.8,              // ↓ was 2.6 (slightly less tall)
            children: _quickBids.map((amount) {
              return GestureDetector(
                onTap: () => _placeBid(amount),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '+\$${amount.toLocaleString()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,             // ↓ was 13
                        fontWeight: FontWeight.w600, // ↓ was w700
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            height: 42,                         // ↓ was 46
            child: TextButton(
              onPressed: _showCustomAmountDialog,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF374151),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Custom Amount',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,             // ↓ was 14
                      fontWeight: FontWeight.w500, // ↓ was w600
                      color: const Color(0xFF374151))),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bidding ended banner ──────────────────────────────────────────────────
  Widget _buildEndedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), // ↓ was 16/28
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),  // ↓ was 14
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gavel, color: _purple, size: 18), // ↓ was 20
                const SizedBox(width: 7),
                Text('Bidding has ended!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,           // ↓ was 15
                        fontWeight: FontWeight.w600, // ↓ was w700
                        color: _purple)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Final Price: \$${_currentPrice.toLocaleString()}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,                     // ↓ was 18
              fontWeight: FontWeight.w700,       // ↓ was w800
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Int extension ────────────────────────────────────────────────────────────
extension _IntFormat on int {
  String toLocaleString() {
    final str = toString();
    final buffer = StringBuffer();
    final start = str.length % 3;
    if (start > 0) {
      buffer.write(str.substring(0, start));
      if (str.length > start) buffer.write(',');
    }
    for (int i = start; i < str.length; i += 3) {
      buffer.write(str.substring(i, i + 3));
      if (i + 3 < str.length) buffer.write(',');
    }
    return buffer.toString();
  }
}