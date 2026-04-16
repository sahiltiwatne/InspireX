import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

const _domains = [
  'Food', 'AI', 'Automobile', 'Healthcare',
  'Blockchain', 'IoT', 'Sustainability', 'FinTech',
];

// ── 4 built-in avatars (gradient combos + icon) ───────────────────────────────
const _avatarOptions = [
  {'bg': [Color(0xFF7C3AED), Color(0xFF3B82F6)], 'icon': Icons.person},
  {'bg': [Color(0xFFEC4899), Color(0xFFF97316)], 'icon': Icons.person},
  {'bg': [Color(0xFF10B981), Color(0xFF06B6D4)], 'icon': Icons.person},
  {'bg': [Color(0xFFF59E0B), Color(0xFFEF4444)], 'icon': Icons.person},
];

enum _AccountType { contributor, investor, both }

// ─── ProfileScreen ────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Text controllers ───────────────────────────────────────────────────────
  final _nameController        = TextEditingController();
  final _emailController       = TextEditingController();
  final _phoneController       = TextEditingController();
  final _locationController    = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _ifscController        = TextEditingController();
  final _bankNameController    = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  // ── Avatar index (0–3) ────────────────────────────────────────────────────
  int _selectedAvatar = 0;

  // ── ID docs: local File picks + saved Base64 ──────────────────────────────
  File?   _newAadhaarFile;
  File?   _newPanFile;
  String? _aadhaarBase64;
  String? _panBase64;

  // ── Other state ───────────────────────────────────────────────────────────
  _AccountType      _accountType     = _AccountType.contributor;
  final Set<String> _selectedDomains = {};

  bool _loading = true;
  bool _saving  = false;

  // ── Firebase ──────────────────────────────────────────────────────────────
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;

  // Max allowed size for ID docs in bytes (150 KB is safe for Firestore)
  static const int _maxDocBytes = 150 * 1024; // 150 KB

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  // ── Load profile from Firestore ───────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final doc =
      await _firestore.collection('users').doc(_uid).get();

      if (!doc.exists || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final data = doc.data()!;

      _nameController.text        = data['fullName']    ?? '';
      _emailController.text       = data['email']       ?? '';
      _phoneController.text       = data['mobile']      ?? '';
      _locationController.text    = data['location']    ?? '';
      _bankAccountController.text = data['bankAccount'] ?? '';
      _ifscController.text        = data['ifsc']        ?? '';
      _bankNameController.text    = data['bankName']    ?? '';

      // Avatar index
      _selectedAvatar =
          (data['avatarIndex'] as int?) ?? 0;

      // Role
      final roleStr = data['role'] as String? ?? 'contributor';
      _accountType = _AccountType.values.firstWhere(
            (e) => e.name == roleStr,
        orElse: () => _AccountType.contributor,
      );

      // Domains
      _selectedDomains
        ..clear()
        ..addAll(List<String>.from(data['domains'] ?? []));

      // ID doc Base64 strings
      final rawAadhaar = data['aadhaarBase64'];
      final rawPan     = data['panBase64'];
      _aadhaarBase64   =
      (rawAadhaar is String && rawAadhaar.isNotEmpty)
          ? rawAadhaar
          : null;
      _panBase64       =
      (rawPan is String && rawPan.isNotEmpty) ? rawPan : null;

      debugPrint(
          '[Profile] aadhaar=${_aadhaarBase64 != null} pan=${_panBase64 != null}');
    } catch (e) {
      debugPrint('[Profile] load error: $e');
      _showSnack('Failed to load profile. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── File → Base64, with size check ───────────────────────────────────────
  Future<String?> _fileToBase64Checked(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxDocBytes) {
      return null; // caller will show error
    }
    return base64Encode(bytes);
  }

  // ── Base64 → MemoryImage ──────────────────────────────────────────────────
  MemoryImage? _base64ToImage(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final cleaned = b64.replaceAll(RegExp(r'\s'), '');
      final bytes   = base64Decode(cleaned);
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    } catch (e) {
      debugPrint('[Profile] base64 decode error: $e');
      return null;
    }
  }

  // ── Save to Firestore ─────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    try {
      // Process Aadhaar
      if (_newAadhaarFile != null) {
        final b64 = await _fileToBase64Checked(_newAadhaarFile!);
        if (b64 == null) {
          setState(() => _saving = false);
          _showSnack(
              'Aadhaar image is too large. Please use an image under 150 KB.');
          return;
        }
        _aadhaarBase64  = b64;
        _newAadhaarFile = null;
      }

      // Process PAN
      if (_newPanFile != null) {
        final b64 = await _fileToBase64Checked(_newPanFile!);
        if (b64 == null) {
          setState(() => _saving = false);
          _showSnack(
              'PAN image is too large. Please use an image under 150 KB.');
          return;
        }
        _panBase64  = b64;
        _newPanFile = null;
      }

      final Map<String, dynamic> updateData = {
        'fullName':    _nameController.text.trim(),
        'email':       _emailController.text.trim(),
        'mobile':      _phoneController.text.trim(),
        'location':    _locationController.text.trim(),
        'bankAccount': _bankAccountController.text.trim(),
        'ifsc':        _ifscController.text.trim(),
        'bankName':    _bankNameController.text.trim(),
        'role':        _accountType.name,
        'domains':     _selectedDomains.toList(),
        'avatarIndex': _selectedAvatar,
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      if (_aadhaarBase64 != null) {
        updateData['aadhaarBase64'] = _aadhaarBase64;
      }
      if (_panBase64 != null) {
        updateData['panBase64'] = _panBase64;
      }

      await _firestore
          .collection('users')
          .doc(_uid)
          .set(updateData, SetOptions(merge: true));

      setState(() => _saving = false);
      _showSnack('Profile saved successfully!', color: _purple);
    } catch (e) {
      debugPrint('[Profile] save error: $e');
      setState(() => _saving = false);
      _showSnack('Failed to save. Please try again.');
    }
  }

  // ── Avatar picker bottom sheet ────────────────────────────────────────────
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Text('Choose your Avatar',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
            const SizedBox(height: 6),
            Text('Pick one of the avatars below',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_avatarOptions.length, (i) {
                final colors = _avatarOptions[i]['bg'] as List<Color>;
                final isSelected = _selectedAvatar == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatar = i);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: isSelected
                          ? Border.all(
                          color: const Color(0xFF111827),
                          width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: colors.first.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                          : [],
                    ),
                    child: Icon(
                      _avatarOptions[i]['icon'] as IconData,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Document picker ───────────────────────────────────────────────────────
  Future<void> _pickDocument(bool isAadhaar) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                  'Upload ${isAadhaar ? 'Aadhaar' : 'PAN'} Card',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
              const SizedBox(height: 4),
              Text('Max file size: 150 KB',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF6B7280))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: _purple),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                onTap: () =>
                    Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: _purple),
                title: Text('Take a Photo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                onTap: () =>
                    Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    // Pick with aggressive compression to stay under 150 KB
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 700,
      maxHeight: 700,
    );

    if (picked == null || !mounted) return;

    final file  = File(picked.path);
    final bytes = await file.readAsBytes();

    // Pre-check size before even setting state
    if (bytes.length > _maxDocBytes) {
      _showSnack(
          'Image is ${(bytes.length / 1024).toStringAsFixed(0)} KB — '
              'please use one under 150 KB.',
          color: Colors.redAccent);
      return;
    }

    setState(() {
      if (isAadhaar) {
        _newAadhaarFile = file;
      } else {
        _newPanFile = file;
      }
    });

    _showSnack(
        '${isAadhaar ? 'Aadhaar' : 'PAN'} selected '
            '(${(bytes.length / 1024).toStringAsFixed(0)} KB). '
            'Tap Save Changes to store it.',
        color: Colors.green);
  }

  void _showSnack(String msg, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(
            child: CircularProgressIndicator(color: _purple)),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                _buildAvatarSection(),
                const SizedBox(height: 20),
                _buildSectionCard(
                  icon: Icons.person_outline,
                  title: 'Personal Details',
                  child: _buildPersonalDetails(),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.shield_outlined,
                  title: 'ID Verification',
                  child: _buildIDVerification(),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.credit_card_outlined,
                  title: 'KYC Details',
                  child: _buildKYCDetails(),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.work_outline,
                  title: 'Account Type',
                  child: _buildAccountType(),
                ),
                const SizedBox(height: 16),
                _buildDomainsCard(),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
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
            Text('Profile & Settings',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
          ],
        ),
      ),
    );
  }

  // ── Avatar section ────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    final colors =
    _avatarOptions[_selectedAvatar]['bg'] as List<Color>;

    return Column(
      children: [
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _showAvatarPicker,
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 48),
              ),
              // Small edit badge
              Positioned(
                bottom: 2, right: 2,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.edit,
                      size: 13, color: Color(0xFF374151)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showAvatarPicker,
          child: Text('Change Avatar',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _purple)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _purple, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Personal Details ──────────────────────────────────────────────────────
  Widget _buildPersonalDetails() {
    return Column(
      children: [
        _buildField(
            label: 'Full Name',
            controller: _nameController,
            hint: 'Enter your full name',
            textCapitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        _buildField(
            label: 'Email Address',
            controller: _emailController,
            hint: 'your.email@example.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildField(
            label: 'Phone Number',
            controller: _phoneController,
            hint: '+91 XXXXX XXXXX',
            keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _buildField(
            label: 'Location',
            controller: _locationController,
            hint: 'City, State, Country'),
      ],
    );
  }

  // ── ID Verification ───────────────────────────────────────────────────────
  Widget _buildIDVerification() {
    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Maximum file size: 150 KB per document. '
                      'Use compressed JPG images for best results.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
        _buildUploadBox(
          label: 'Aadhaar Card',
          localFile: _newAadhaarFile,
          savedBase64: _aadhaarBase64,
          onTap: () => _pickDocument(true),
        ),
        const SizedBox(height: 16),
        _buildUploadBox(
          label: 'PAN Card',
          localFile: _newPanFile,
          savedBase64: _panBase64,
          onTap: () => _pickDocument(false),
        ),
      ],
    );
  }

  // ── KYC Details ───────────────────────────────────────────────────────────
  Widget _buildKYCDetails() {
    return Column(
      children: [
        _buildField(
          label: 'Bank Account Number',
          controller: _bankAccountController,
          hint: 'Enter account number',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'IFSC Code',
          controller: _ifscController,
          hint: 'Enter IFSC code',
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Bank Name',
          controller: _bankNameController,
          hint: 'Enter bank name',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF1E40AF),
                  height: 1.5),
              children: const [
                TextSpan(
                    text: 'Note: ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text:
                    'KYC verification is mandatory for participating in bidding and receiving payments.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Account Type ──────────────────────────────────────────────────────────
  Widget _buildAccountType() {
    return Row(
      children: [
        _AccountTypeButton(
          label: 'Contributor',
          icon: Icons.description_outlined,
          selected: _accountType == _AccountType.contributor,
          onTap: () =>
              setState(() => _accountType = _AccountType.contributor),
        ),
        const SizedBox(width: 10),
        _AccountTypeButton(
          label: 'Investor',
          icon: Icons.work_outline,
          selected: _accountType == _AccountType.investor,
          onTap: () =>
              setState(() => _accountType = _AccountType.investor),
        ),
        const SizedBox(width: 10),
        _AccountTypeButton(
          label: 'Both',
          icon: Icons.person_outline,
          selected: _accountType == _AccountType.both,
          onTap: () => setState(() => _accountType = _AccountType.both),
        ),
      ],
    );
  }

  // ── Interested Domains ────────────────────────────────────────────────────
  Widget _buildDomainsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Interested Domains',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('Select domains you\'re interested in',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF6B7280))),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _domains.map((domain) {
              final isSelected = _selectedDomains.contains(domain);
              return GestureDetector(
                onTap: () => setState(() => isSelected
                    ? _selectedDomains.remove(domain)
                    : _selectedDomains.add(domain)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                        : null,
                    color:
                    isSelected ? null : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(domain,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF374151))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
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
          boxShadow: [
            BoxShadow(
                color: _purple.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ],
        ),
        child: TextButton(
          onPressed: _saving ? null : _saveChanges,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
              : Text('Save Changes',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── Generic labelled text field ───────────────────────────────────────────
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
      ],
    );
  }

  // ── Upload box ────────────────────────────────────────────────────────────
  Widget _buildUploadBox({
    required String label,
    required File? localFile,
    required String? savedBase64,
    required VoidCallback onTap,
  }) {
    ImageProvider? imageProvider;
    bool isUnsaved = false;

    if (localFile != null) {
      imageProvider = FileImage(localFile);
      isUnsaved = true;
    } else {
      final mem = _base64ToImage(savedBase64);
      if (mem != null) imageProvider = mem;
    }

    Widget content;

    if (imageProvider != null) {
      content = Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image(
              image: imageProvider,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: const Color(0xFFF1F5F9),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Color(0xFF9CA3AF), size: 32),
                ),
              ),
            ),
          ),
          // Edit icon
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.edit,
                  color: Colors.white, size: 14),
            ),
          ),
          // Status badge
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUnsaved
                    ? Colors.orange.withOpacity(0.9)
                    : Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnsaved ? Icons.upload : Icons.check,
                    color: Colors.white, size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isUnsaved ? 'Unsaved' : 'Saved',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.upload_outlined,
                size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text('Upload $label',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569))),
            const SizedBox(height: 2),
            Text('JPG / PNG  •  Max 150 KB',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: BoxDecoration(
              color: imageProvider != null
                  ? _purple.withOpacity(0.04)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: imageProvider != null
                    ? _purple.withOpacity(0.4)
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: content,
          ),
        ),
      ],
    );
  }
}

// ─── Account Type Button ──────────────────────────────────────────────────────
class _AccountTypeButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final bool         selected;
  final VoidCallback onTap;

  const _AccountTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
              colors: [_gradientStart, _gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: selected ? null : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
              BoxShadow(
                  color: _purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 24,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF64748B)),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF374151))),
            ],
          ),
        ),
      ),
    );
  }
}
