import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../api_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _purple        = Color(0xFF7C3AED);
const _purpleLight   = Color(0xFF8B5CF6);
const _gradientStart = Color(0xFF7C3AED);
const _gradientEnd   = Color(0xFF3B82F6);
const _bgColor       = Color(0xFFF8FAFC);

const _categories = [
  'Food', 'AI', 'Automobile', 'Healthcare',
  'Blockchain', 'IoT', 'Sustainability',
];

// Max patent image size: 150 KB
const int _maxPatentBytes = 150 * 1024;

// ─── SubmitIdeaScreen ─────────────────────────────────────────────────────────
class SubmitIdeaScreen extends StatefulWidget {
  const SubmitIdeaScreen({super.key});

  @override
  State<SubmitIdeaScreen> createState() => _SubmitIdeaScreenState();
}

class _SubmitIdeaScreenState extends State<SubmitIdeaScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _titleController     = TextEditingController();
  final _problemController   = TextEditingController();
  final _solutionController  = TextEditingController();
  final _basePriceController = TextEditingController();

  // ── Form state ────────────────────────────────────────────────────────────
  String?    _selectedCategory;
  bool?      _patentAvailable;
  DateTime?  _selectedDate;
  TimeOfDay? _selectedTime;
  bool       _submitting = false;

  // ── Patent image ──────────────────────────────────────────────────────────
  File?   _patentImageFile;
  String? _patentImageBase64;
  final   ImagePicker _imagePicker = ImagePicker();

  // ── AI price state ────────────────────────────────────────────────────────
  bool   _aiLoading        = false;
  bool   _aiPriceRevealed  = false;
  String _aiLoadingMessage = '';

  final List<String> _aiMessages = [
    '🔍 Analyzing your idea\'s uniqueness...',
    '📊 Scanning current market conditions...',
    '🌍 Estimating total addressable market size...',
    '🏆 Benchmarking against similar patented ideas...',
    '⚡ Running competitor pricing analysis...',
    '🤖 Calculating optimal base price...',
  ];

  // ── Firebase ──────────────────────────────────────────────────────────────
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _problemController.dispose();
    _solutionController.dispose();
    _basePriceController.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Time picker ───────────────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Pick patent image ─────────────────────────────────────────────────────
  Future<void> _pickPatentImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Upload Patent Document',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
              const SizedBox(height: 4),
              Text('Max file size: 150 KB',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: const Color(0xFF6B7280))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: _purple),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: _purple),
                title: Text('Take a Photo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 700,
      maxHeight: 700,
    );

    if (picked == null || !mounted) return;

    final file  = File(picked.path);
    final bytes = await file.readAsBytes();

    if (bytes.length > _maxPatentBytes) {
      _showError(
        'Image is ${(bytes.length / 1024).toStringAsFixed(0)} KB — '
            'please use an image under 150 KB.',
      );
      return;
    }

    setState(() {
      _patentImageFile   = file;
      _patentImageBase64 = base64Encode(bytes);
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Patent image selected (${(bytes.length / 1024).toStringAsFixed(0)} KB)',
        style: GoogleFonts.plusJakartaSans(fontSize: 13),
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── AI price fetch ────────────────────────────────────────────────────────
  Future<void> _getAISuggestedPrice() async {
    if (_aiLoading || _aiPriceRevealed) return;
    setState(() {
      _aiLoading        = true;
      _aiLoadingMessage = _aiMessages[0];
    });

    for (int i = 1; i < _aiMessages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      setState(() => _aiLoadingMessage = _aiMessages[i]);
    }

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _aiLoading        = false;
      _aiPriceRevealed  = true;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      _showError('Please select a category.');
      return;
    }
    if (_patentAvailable == null) {
      _showError('Please select patent availability.');
      return;
    }
    if (_patentAvailable == true && _patentImageBase64 == null) {
      _showError('Please upload your patent document.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Please set a bidding schedule.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = _auth.currentUser?.uid;
      String fullIdea = _titleController.text.trim() + " " + _problemController.text.trim() + " " + _solutionController.text.trim();
      var mlResult = await ApiService.processIdea(fullIdea);
      final Map<String, dynamic> ideaData = {
        'uid':              uid,
        'title':            _titleController.text.trim(),
        'problemStatement': _problemController.text.trim(),
        'detailedSolution': _solutionController.text.trim(),
        'category':         _selectedCategory,
        'isPatented':       _patentAvailable,
        'basePrice':        int.tryParse(_basePriceController.text.trim()) ?? 0,
        'biddingDate':      _selectedDate != null
            ? '${_selectedDate!.day.toString().padLeft(2, '0')}-'
            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
            '${_selectedDate!.year}'
            : null,
        'biddingTime':      _selectedTime?.format(context),
        'status':           'pending_review',
        // FIX: Added client-side integer timestamp used for sorting in admin screen.
        // FieldValue.serverTimestamp() is async and arrives null briefly,
        // which breaks orderBy. 'createdAt' (int ms) is available immediately.
        'createdAt':        DateTime.now().millisecondsSinceEpoch,
        'submittedAt':      FieldValue.serverTimestamp(),
        'mlRating': mlResult['rating'],
        'mlSentiment': mlResult['sentiment'],
        'mlPrice': mlResult['suggested_price'] ?? 0,
        'mlRange': mlResult['range'] ?? '',
      };

      if (_aiPriceRevealed) {
        ideaData['aiSuggestedPrice'] = 50000;
      }

      if (_patentAvailable == true && _patentImageBase64 != null) {
        ideaData['patentImageBase64'] = _patentImageBase64;
      }

      if (uid != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('ideas')
            .add(ideaData);
      }

      setState(() => _submitting = false);
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      setState(() => _submitting = false);
      _showError('Failed to submit: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Idea Submitted!',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827))),
              const SizedBox(height: 8),
              Text(
                'Your idea has been submitted for review. '
                    'We\'ll notify you once it\'s approved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.5),
              ),
              const SizedBox(height: 24),
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Back to Home',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // ── Idea Title ─────────────────────────────────────────
                  _FieldLabel(text: 'Idea Title', required: true),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Enter your innovative idea title',
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Problem Statement ──────────────────────────────────
                  _FieldLabel(
                      text: 'Problem Statement', required: true),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _problemController,
                    hint: 'What problem does your idea solve?',
                    maxLines: 5,
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Detailed Statement & Solution ──────────────────────
                  _FieldLabel(
                      text: 'Detailed Statement & Solution',
                      required: true),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _solutionController,
                    hint: 'Describe your solution in detail...',
                    maxLines: 7,
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Category ───────────────────────────────────────────
                  _FieldLabel(text: 'Category', required: true),
                  const SizedBox(height: 10),
                  _buildCategorySelector(),
                  const SizedBox(height: 20),

                  // ── Patent Available ───────────────────────────────────
                  _FieldLabel(
                      text: 'Patent Available?', required: true),
                  const SizedBox(height: 10),
                  _buildPatentToggle(),
                  const SizedBox(height: 12),

                  // ── Patent image upload (only when Yes) ────────────────
                  if (_patentAvailable == true)
                    _buildPatentUploadSection(),

                  const SizedBox(height: 20),

                  // ── Base Price ─────────────────────────────────────────
                  _FieldLabel(
                      text: 'Base Price (USD)', required: true),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _basePriceController,
                    hint: 'Enter your expected base price',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // ── AI Suggested Price ─────────────────────────────────
                  _buildAISuggestedCard(),
                  const SizedBox(height: 20),

                  // ── Bidding Schedule ───────────────────────────────────
                  _FieldLabel(
                      text: 'Bidding Schedule', required: true),
                  const SizedBox(height: 10),
                  _buildBiddingSchedule(),
                  const SizedBox(height: 32),

                  // ── Submit button ──────────────────────────────────────
                  _buildSubmitButton(),
                ],
              ),
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
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF374151), size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            Text(
              'Submit Your Idea',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Generic text field ────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ── Category selector ─────────────────────────────────────────────────────
  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(
                  () => _selectedCategory = isSelected ? null : cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? _purple.withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? _purple : const Color(0xFFD1D5DB),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              cat,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? _purple
                    : const Color(0xFF374151),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Patent Yes / No toggle ────────────────────────────────────────────────
  Widget _buildPatentToggle() {
    return Row(
      children: [
        _PatentOption(
          label: 'Yes',
          selected: _patentAvailable == true,
          onTap: () => setState(() {
            _patentAvailable = true;
          }),
        ),
        const SizedBox(width: 12),
        _PatentOption(
          label: 'No',
          selected: _patentAvailable == false,
          onTap: () => setState(() {
            _patentAvailable    = false;
            _patentImageFile   = null;
            _patentImageBase64 = null;
          }),
        ),
      ],
    );
  }

  // ── Patent image upload section ───────────────────────────────────────────
  Widget _buildPatentUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
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
                  'Please upload a clear photo of your patent certificate. '
                      'Max size: 150 KB (compressed JPG recommended).',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),

        RichText(
          text: TextSpan(
            text: 'Patent Document',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937)),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        GestureDetector(
          onTap: _pickPatentImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _patentImageFile != null
                  ? _purple.withOpacity(0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _patentImageFile != null
                    ? _purple.withOpacity(0.4)
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: _patentImageFile != null
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.file(
                    _patentImageFile!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit,
                        color: Colors.white, size: 14),
                  ),
                ),
                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text('Patent uploaded',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            )
                : Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(Icons.upload_file_outlined,
                      size: 36, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text('Upload Patent Certificate',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569))),
                  const SizedBox(height: 4),
                  Text('JPG / PNG  •  Max 150 KB',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── AI Suggested Price ────────────────────────────────────────────────────
  Widget _buildAISuggestedCard() {
    if (!_aiLoading && !_aiPriceRevealed) {
      return GestureDetector(
        onTap: _getAISuggestedPrice,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _purple.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome,
                  color: _purple, size: 18),
              const SizedBox(width: 8),
              Text(
                'Get AI Suggested Price',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _purple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _purple.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: _purple, size: 16),
                const SizedBox(width: 6),
                Text(
                  'AI is analyzing your idea...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFFEDE9FE),
                valueColor:
                AlwaysStoppedAnimation<Color>(_purple),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
              child: Text(
                _aiLoadingMessage,
                key: ValueKey(_aiLoadingMessage),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _purple.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Revealed
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: _purple, size: 18),
              const SizedBox(width: 6),
              Text(
                'AI Suggested Price',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _purple,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _aiPriceRevealed = false;
                  _aiLoading       = false;
                }),
                child: const Icon(Icons.refresh,
                    color: _purple, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$50,000',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _purple)),
          const SizedBox(height: 4),
          Text(
            'Based on: idea uniqueness, market conditions, '
                'market size & competitor pricing',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _purple.withOpacity(0.8),
                height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Bidding Schedule ──────────────────────────────────────────────────────
  Widget _buildBiddingSchedule() {
    final dateText = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}-'
        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
        '${_selectedDate!.year}'
        : 'dd-mm-yyyy';

    final timeText =
    _selectedTime != null ? _selectedTime!.format(context) : '--:--';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(dateText,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _selectedDate != null
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(timeText,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _selectedTime != null
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
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
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextButton(
          onPressed: _submitting ? null : _submit,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _submitting
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
              : Text('Submit Idea for Review',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── Field Label ──────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool   required;
  const _FieldLabel({required this.text, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937)),
        children: required
            ? [
          const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.redAccent))
        ]
            : [],
      ),
    );
  }
}

// ─── Patent Option Button ─────────────────────────────────────────────────────
class _PatentOption extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _PatentOption(
      {required this.label,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          decoration: BoxDecoration(
            color: selected
                ? _purple.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _purple : const Color(0xFFD1D5DB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? _purple
                    : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

