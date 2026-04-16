import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

// ─── Fallback content for seeded/dummy ideas ──────────────────────────────────
const _fallbackProblem =
    'Current solutions in this space are either too expensive, lack scalability, '
    "or don't address the core pain points of end users. There's a significant "
    'gap in the market for an accessible, user-friendly solution.';

const _fallbackSolution =
    'This innovative approach combines cutting-edge technology with practical '
    'implementation. The solution has been tested with focus groups and shows '
    'promising results. Key features include automated workflows, real-time '
    'analytics, and seamless integration capabilities.';

const _fallbackBiddingTime = 'Tomorrow at 3:00 - 4:00 PM';

// ─── IdeaDetailScreen ─────────────────────────────────────────────────────────
class IdeaDetailScreen extends StatefulWidget {
  final String ideaId;
  final String title;
  final String description;
  final int    likes;
  final double aiRating;
  final String industry;
  final bool   isPatented;
  final String contributorName;

  const IdeaDetailScreen({
    super.key,
    required this.ideaId,
    required this.title,
    required this.description,
    required this.likes,
    required this.aiRating,
    required this.industry,
    required this.isPatented,
    required this.contributorName,
  });

  @override
  State<IdeaDetailScreen> createState() => _IdeaDetailScreenState();
}

class _IdeaDetailScreenState extends State<IdeaDetailScreen> {
  bool _isLiked      = false;
  bool _isInterested = false;
  late int _likeCount;
  late int _interestedCount;

  // ── Fields populated from Firestore ───────────────────────────────────────
  String  _problemStatement  = '';
  String  _detailedSolution  = '';
  String  _biddingSchedule   = '';
  int     _basePrice         = 0;
  bool    _isLoading         = true;

  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _likeCount       = widget.likes;
    _interestedCount = 0;
    _loadIdeaData();
  }

  // ── Load full idea data from Firestore ────────────────────────────────────
  Future<void> _loadIdeaData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('approved_ideas')
          .doc(widget.ideaId)
          .get();

      if (!doc.exists || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final d = doc.data()!;

      // ── Interaction state ────────────────────────────────────────────
      final likedBy      = List<String>.from(d['likedBy']      ?? []);
      final interestedBy = List<String>.from(d['interestedBy'] ?? []);

      // ── Content fields ────────────────────────────────────────────────
      final problem  = d['problemStatement'] as String? ?? '';
      final solution = d['detailedSolution'] as String? ?? '';
      final isSeeded = d['isSeeded']         as bool?   ?? false;

      // Build bidding schedule string
      final bDate = d['biddingDate'] as String? ?? '';
      final bTime = d['biddingTime'] as String? ?? '';
      final String schedule;
      if (bDate.isNotEmpty && bTime.isNotEmpty) {
        schedule = '$bDate  •  $bTime';
      } else if (bDate.isNotEmpty) {
        schedule = bDate;
      } else if (bTime.isNotEmpty) {
        schedule = bTime;
      } else {
        schedule = _fallbackBiddingTime;
      }

      // Base price: use stored value, fall back to patent-based default
      final storedPrice = d['basePrice'] as int? ?? 0;
      final computedPrice = storedPrice > 0
          ? storedPrice
          : (widget.isPatented ? 150000 : 85000);

      setState(() {
        _likeCount       = d['likes']      as int? ?? widget.likes;
        _interestedCount = d['interested'] as int? ?? 0;
        _isLiked         = _uid != null && likedBy.contains(_uid);
        _isInterested    = _uid != null && interestedBy.contains(_uid);

        // For seeded/dummy ideas use fallback copy; for real submissions
        // use what the user actually wrote.
        _problemStatement = (isSeeded || problem.isEmpty)
            ? _fallbackProblem
            : problem;
        _detailedSolution = (isSeeded || solution.isEmpty)
            ? _fallbackSolution
            : solution;

        _biddingSchedule = schedule;
        _basePrice       = computedPrice;
        _isLoading       = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _problemStatement = _fallbackProblem;
          _detailedSolution = _fallbackSolution;
          _biddingSchedule  = _fallbackBiddingTime;
          _basePrice        = widget.isPatented ? 150000 : 85000;
          _isLoading        = false;
        });
      }
    }
  }

  // ── Toggle like ────────────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('approved_ideas')
        .doc(widget.ideaId);

    setState(() {
      _isLiked   = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await ref.update({
          'likes':   FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([_uid]),
        });
      } else {
        await ref.update({
          'likes':   FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([_uid]),
        });
      }

      // Mirror likes back to owner's idea sub-collection
      final ownerUid = (await ref.get()).data()?['uid'] as String?;
      if (ownerUid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('ideas')
            .doc(widget.ideaId)
            .update({'likes': FieldValue.increment(_isLiked ? 1 : -1)})
            .catchError((_) {});
      }
    } catch (_) {
      setState(() {
        _isLiked   = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    }
  }

  // ── Toggle interested ──────────────────────────────────────────────────────
  Future<void> _toggleInterested() async {
    if (_uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('approved_ideas')
        .doc(widget.ideaId);

    setState(() {
      _isInterested    = !_isInterested;
      _interestedCount += _isInterested ? 1 : -1;
    });

    try {
      if (_isInterested) {
        await ref.update({
          'interested':   FieldValue.increment(1),
          'interestedBy': FieldValue.arrayUnion([_uid]),
        });
      } else {
        await ref.update({
          'interested':   FieldValue.increment(-1),
          'interestedBy': FieldValue.arrayRemove([_uid]),
        });
      }

      // Mirror to owner's idea sub-collection
      final ownerUid = (await ref.get()).data()?['uid'] as String?;
      if (ownerUid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('ideas')
            .doc(widget.ideaId)
            .update({
          'interested': FieldValue.increment(_isInterested ? 1 : -1),
        })
            .catchError((_) {});
      }
    } catch (_) {
      setState(() {
        _isInterested    = !_isInterested;
        _interestedCount += _isInterested ? 1 : -1;
      });
    }
  }

  // ── Category colour helpers ────────────────────────────────────────────────
  Color _categoryBg() {
    switch (widget.industry) {
      case 'Food':          return const Color(0xFFFFF3E0);
      case 'AI':            return const Color(0xFFEDE9FE);
      case 'Blockchain':    return const Color(0xFFDBEAFE);
      case 'IoT':           return const Color(0xFFDCFCE7);
      case 'Healthcare':    return const Color(0xFFFFE4E6);
      case 'Sustainability':return const Color(0xFFD1FAE5);
      default:              return const Color(0xFFF1F5F9);
    }
  }

  Color _categoryText() {
    switch (widget.industry) {
      case 'Food':          return const Color(0xFFE65100);
      case 'AI':            return _purple;
      case 'Blockchain':    return const Color(0xFF1D4ED8);
      case 'IoT':           return const Color(0xFF16A34A);
      case 'Healthcare':    return const Color(0xFFBE123C);
      case 'Sustainability':return const Color(0xFF059669);
      default:              return const Color(0xFF374151);
    }
  }

  String _formatPrice(int price) => '\$${price
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},')}';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // ── AppBar ───────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              color: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF374151), size: 24),
                  ),
                  Text(
                    'Idea Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: _purple),
            )
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [_buildMainCard()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLoading ? null : _buildBottomCTA(),
    );
  }

  // ── Main card ─────────────────────────────────────────────────────────────
  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Contributor ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contributorName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Contributor',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          // ── Tags ───────────────────────────────────────────────────────
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              _Pill(
                label: widget.industry,
                bgColor: _categoryBg(),
                textColor: _categoryText(),
              ),
              _Pill(
                icon: widget.isPatented
                    ? Icons.verified_outlined
                    : Icons.block_outlined,
                label: widget.isPatented ? 'Patented' : 'Not Patented',
                bgColor: widget.isPatented
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF1F5F9),
                textColor: widget.isPatented
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── AI Rating ──────────────────────────────────────────────────
          Row(
            children: [
              Text('AI Rating:',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: const Color(0xFF6B7280))),
              const SizedBox(width: 8),
              _StarRating(rating: widget.aiRating),
              const SizedBox(width: 6),
              Text(
                widget.aiRating.toStringAsFixed(1),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Problem Statement ──────────────────────────────────────────
          Text(
            'Problem Statement',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            _problemStatement,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF4B5563),
                height: 1.6),
          ),
          const SizedBox(height: 20),

          // ── Overview / Detailed Solution ───────────────────────────────
          Text(
            'Overview',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            _detailedSolution,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF4B5563),
                height: 1.6),
          ),
          const SizedBox(height: 6),
          Text(
            'Full details will be revealed to the winning bidder',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: _purple,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          // ── Base Price ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFEFF6FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base Price',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(_basePrice),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bidding Schedule ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFDE68A), width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Text(
                      'Bidding Schedule',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined,
                        size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _biddingSchedule,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 16),

          // ── Likes + Interested count ───────────────────────────────────
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined,
                  size: 20, color: _purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_likeCount ${_likeCount == 1 ? 'person' : 'people'} liked'
                      '  •  $_interestedCount interested',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF374151)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Action buttons ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _toggleLike,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isLiked
                          ? _purple
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isLiked
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: _isLiked
                              ? Colors.white
                              : const Color(0xFF374151),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLiked ? 'Liked' : 'Like',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _isLiked
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleInterested,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isInterested
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isInterested
                              ? Icons.people
                              : Icons.people_outline,
                          size: 16,
                          color: _isInterested
                              ? Colors.white
                              : const Color(0xFF374151),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isInterested ? 'Interested' : "I'm Interested",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _isInterested
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom CTA ────────────────────────────────────────────────────────────
  Widget _buildBottomCTA() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_gradientStart, _gradientEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Interested? Start Bidding',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
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
          size: 17,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }
}

// ─── Pill Tag ─────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final IconData? icon;
  final String    label;
  final Color     bgColor;
  final Color     textColor;

  const _Pill({
    this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor),
          ),
        ],
      ),
    );
  }
}