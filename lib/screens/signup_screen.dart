import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _gradientStart = Color(0xFF7C3AED);
const _gradientMid   = Color(0xFF8B5CF6);
const _gradientEnd   = Color(0xFF3B82F6);

enum _UserRole { contributor, investor, both }

// ─── SignupScreen ─────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _fullNameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _mobileController   = TextEditingController();

  final List<TextEditingController> _emailOtpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _emailOtpFocus =
  List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _mobileOtpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _mobileOtpFocus =
  List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _pinControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocus =
  List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _confirmPinControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _confirmPinFocus =
  List.generate(6, (_) => FocusNode());

  // ── State ─────────────────────────────────────────────────────────────────
  _UserRole _userRole = _UserRole.both;

  bool   _emailOtpSent        = false;
  bool   _emailVerified       = false;
  bool   _emailOtpLoading     = false;
  bool   _emailVerifyLoading  = false;
  String _emailError          = '';

  bool   _mobileOtpSent       = false;
  bool   _mobileVerified      = false;
  bool   _mobileOtpLoading    = false;
  bool   _mobileVerifyLoading = false;
  String _mobileError         = '';

  String? _verificationId;

  String _pin        = '';
  String _confirmPin = '';

  bool _submitting = false;

  Timer? _emailDebounce;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    for (final c in _emailOtpControllers)   c.dispose();
    for (final f in _emailOtpFocus)         f.dispose();
    for (final c in _mobileOtpControllers)  c.dispose();
    for (final f in _mobileOtpFocus)        f.dispose();
    for (final c in _pinControllers)        c.dispose();
    for (final f in _pinFocus)              f.dispose();
    for (final c in _confirmPinControllers) c.dispose();
    for (final f in _confirmPinFocus)       f.dispose();
    _emailDebounce?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _otpFromBoxes =>
      _emailOtpControllers.map((c) => c.text).join();
  String get _mobileOtpFromBoxes =>
      _mobileOtpControllers.map((c) => c.text).join();

  void _showSnack(String msg, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.plusJakartaSans(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Email duplicate check ─────────────────────────────────────────────────
  void _onEmailChanged(String value) {
    setState(() => _emailError = '');
    _emailDebounce?.cancel();
    if (value.contains('@') && value.contains('.')) {
      _emailDebounce =
          Timer(const Duration(milliseconds: 700), () async {
            try {
              final methods = await FirebaseAuth.instance
                  .fetchSignInMethodsForEmail(value.trim());
              if (methods.isNotEmpty && mounted) {
                setState(() => _emailError =
                'This email is already registered. Please use another.');
              }
            } catch (_) {}
          });
    }
  }

  // ── Send Email OTP ────────────────────────────────────────────────────────
  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email first.');
      return;
    }
    if (_emailError.isNotEmpty) return;

    setState(() => _emailOtpLoading = true);

    try {
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() {
          _emailError =
          'This email is already registered. Please use another.';
          _emailOtpLoading = false;
        });
        return;
      }

      final otp =
      (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
          .toString();
      await FirebaseFirestore.instance
          .collection('email_otps')
          .doc(email)
          .set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _emailOtpSent    = true;
          _emailOtpLoading = false;
        });
        _showSnack('OTP sent to $email  [Demo OTP: $otp]',
            color: _gradientStart);
      }
    } catch (e) {
      setState(() => _emailOtpLoading = false);
      _showSnack('Failed to send OTP. Try again.');
    }
  }

  // ── Verify Email OTP ──────────────────────────────────────────────────────
  Future<void> _verifyEmailOtp() async {
    final otp   = _otpFromBoxes;
    final email = _emailController.text.trim();
    if (otp.length < 6) return;

    setState(() => _emailVerifyLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('email_otps')
          .doc(email)
          .get();

      if (doc.exists && doc.data()?['otp'] == otp) {
        setState(() {
          _emailVerified       = true;
          _emailVerifyLoading  = false;
        });
        await doc.reference.delete();
      } else {
        setState(() => _emailVerifyLoading = false);
        _showSnack('Incorrect OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _emailVerifyLoading = false);
      _showSnack('Verification failed. Try again.');
    }
  }

  // ── Send Mobile OTP ───────────────────────────────────────────────────────
  Future<void> _sendMobileOtp() async {
    final phone = _mobileController.text.trim();
    if (phone.isEmpty) {
      _showSnack('Enter your mobile number first.');
      return;
    }

    setState(() {
      _mobileOtpLoading = true;
      _mobileError      = '';
    });

    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('mobile', isEqualTo: phone)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      setState(() {
        _mobileError      = 'This mobile number is already registered.';
        _mobileOtpLoading = false;
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        setState(() {
          _mobileVerified   = true;
          _mobileOtpLoading = false;
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _mobileOtpLoading = false);
        _showSnack(e.message ?? 'Phone verification failed.');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId   = verificationId;
          _mobileOtpSent    = true;
          _mobileOtpLoading = false;
        });
        _showSnack('OTP sent to $phone', color: _gradientStart);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── Verify Mobile OTP ─────────────────────────────────────────────────────
  Future<void> _verifyMobileOtp() async {
    final otp = _mobileOtpFromBoxes;
    if (otp.length < 6 || _verificationId == null) return;

    setState(() => _mobileVerifyLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseAuth.instance.signOut();

      setState(() {
        _mobileVerified      = true;
        _mobileVerifyLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _mobileVerifyLoading = false);
      _showSnack(e.message ?? 'Invalid OTP.');
    }
  }

  // ── Create Account ────────────────────────────────────────────────────────
  Future<void> _createAccount() async {
    final name  = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _mobileController.text.trim();
    _pin        = _pinControllers.map((c) => c.text).join();
    _confirmPin = _confirmPinControllers.map((c) => c.text).join();

    if (name.isEmpty) {
      _showSnack('Please enter your full name.');
      return;
    }
    if (!_emailVerified) {
      _showSnack('Please verify your email.');
      return;
    }
    if (!_mobileVerified) {
      _showSnack('Please verify your mobile number.');
      return;
    }
    if (_pin.length < 6) {
      _showSnack('Please set a 6-digit PIN.');
      return;
    }
    if (_pin != _confirmPin) {
      _showSnack('PINs do not match.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: email, password: _pin);

      final uid = cred.user!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid':       uid,
        'fullName':  name,
        'email':     email,
        'mobile':    phone,
        'role':      _userRole.name,
        'pin':       _pin,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _submitting = false);
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 18),
                Text('Account Created!',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827))),
                const SizedBox(height: 8),
                Text(
                  'Welcome to InspireX, $name! 🎉\nYour account has been created successfully.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const HomeScreen()),
                              (route) => false,
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Let\'s Go!',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _submitting = false);
      String msg = 'Account creation failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        msg = 'PIN is too weak. Use 6 digits.';
      }
      _showSnack(msg);
    } catch (e) {
      setState(() => _submitting = false);
      _showSnack('Something went wrong. Please try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_gradientStart, _gradientMid, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              children: [
                _buildBranding(),
                const SizedBox(height: 24),
                _buildFormCard(),
                const SizedBox(height: 16),
                Text(
                  'By signing up, you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Branding (back arrow lives here) ─────────────────────────────────────
  Widget _buildBranding() {
    return Column(
      children: [
        // Back arrow — no separate app bar needed
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x557C3AED),
                      blurRadius: 24,
                      spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.lightbulb_outline_rounded,
                  size: 32, color: _gradientStart),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Create Account',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text('Join the marketplace for ideas',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85))),
      ],
    );
  }

  // ── Form card ─────────────────────────────────────────────────────────────
  Widget _buildFormCard() {
    _pin        = _pinControllers.map((c) => c.text).join();
    _confirmPin = _confirmPinControllers.map((c) => c.text).join();
    final pinsMatch =
        _pin.length == 6 && _confirmPin.length == 6 && _pin == _confirmPin;
    final pinsMismatch =
        _pin.length == 6 && _confirmPin.length == 6 && _pin != _confirmPin;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Full Name ──────────────────────────────────────────────
          _label('Full Name'),
          const SizedBox(height: 6),
          _textField(
            controller: _fullNameController,
            hint: 'Enter your full name',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // ── Email ──────────────────────────────────────────────────
          _label('Email Address'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _emailController,
                  hint: 'your.email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_emailVerified,
                  onChanged: _onEmailChanged,
                ),
              ),
              const SizedBox(width: 8),
              _emailVerified
                  ? _verifiedBadge()
                  : _otpButton(
                label: _emailOtpSent ? 'Resend' : 'Send OTP',
                loading: _emailOtpLoading,
                onTap: _sendEmailOtp,
              ),
            ],
          ),
          if (_emailError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_emailError,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.redAccent)),
            ),

          if (_emailOtpSent && !_emailVerified) ...[
            const SizedBox(height: 12),
            _otpCard(
              label: 'Enter Email OTP',
              controllers: _emailOtpControllers,
              focusNodes: _emailOtpFocus,
              loading: _emailVerifyLoading,
              onVerify: _verifyEmailOtp,
            ),
          ],
          const SizedBox(height: 16),

          // ── Mobile ─────────────────────────────────────────────────
          _label('Mobile Number'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _mobileController,
                  hint: '+91 XXXXX XXXXX',
                  keyboardType: TextInputType.phone,
                  enabled: !_mobileVerified,
                  onChanged: (_) => setState(() => _mobileError = ''),
                ),
              ),
              const SizedBox(width: 8),
              _mobileVerified
                  ? _verifiedBadge()
                  : _otpButton(
                label: _mobileOtpSent ? 'Resend' : 'Send OTP',
                loading: _mobileOtpLoading,
                onTap: _sendMobileOtp,
              ),
            ],
          ),
          if (_mobileError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_mobileError,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.redAccent)),
            ),

          if (_mobileOtpSent && !_mobileVerified) ...[
            const SizedBox(height: 12),
            _otpCard(
              label: 'Enter Mobile OTP',
              controllers: _mobileOtpControllers,
              focusNodes: _mobileOtpFocus,
              loading: _mobileVerifyLoading,
              onVerify: _verifyMobileOtp,
            ),
          ],
          const SizedBox(height: 16),

          // ── I want to join as ──────────────────────────────────────
          _label('I want to join as'),
          const SizedBox(height: 10),
          Row(
            children: [
              _roleButton(
                  label: 'Contributor',
                  icon: Icons.description_outlined,
                  role: _UserRole.contributor),
              const SizedBox(width: 8),
              _roleButton(
                  label: 'Investor',
                  icon: Icons.work_outline,
                  role: _UserRole.investor),
              const SizedBox(width: 8),
              _roleButton(
                  label: 'Both',
                  icon: Icons.person_outline,
                  role: _UserRole.both),
            ],
          ),
          const SizedBox(height: 16),

          // ── Create PIN ─────────────────────────────────────────────
          _label('Create 6-Digit PIN'),
          const SizedBox(height: 12),
          _pinRow(_pinControllers, _pinFocus),
          const SizedBox(height: 16),

          // ── Confirm PIN ────────────────────────────────────────────
          _label('Confirm PIN'),
          const SizedBox(height: 12),
          _pinRow(_confirmPinControllers, _confirmPinFocus),
          if (pinsMismatch)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('PINs do not match',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.redAccent)),
            ),
          if (pinsMatch)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('✓ PINs match',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.green)),
            ),
          const SizedBox(height: 24),

          // ── Create Account button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
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
                    color: _gradientStart.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: _submitting ? null : _createAccount,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Create Account',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Already have account ───────────────────────────────────
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280)),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Log in',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _gradientStart)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151)));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      enabled: enabled,
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: enabled
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFF1F5F9),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          borderSide:
          const BorderSide(color: _gradientStart, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }

  Widget _otpButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _verifiedBadge() => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFDCFCE7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF86EFAC)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle,
            color: Color(0xFF16A34A), size: 16),
        const SizedBox(width: 4),
        Text('Verified',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF16A34A))),
      ],
    ),
  );

  // ── OTP card (email / mobile) ─────────────────────────────────────────────
  Widget _otpCard({
    required String label,
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool loading,
    required VoidCallback onVerify,
  }) {
    // Dynamic box width to prevent overflow
    // Available = screenWidth - scrollPadding(48) - cardPadding(40)
    //             - otpCardPadding(28) - 5 gaps(30)
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth =
    ((screenWidth - 48 - 40 - 28 - 30) / 6).floorToDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
                  (i) => Row(
                children: [
                  _buildOtpBox(controllers[i], focusNodes[i], i,
                      controllers, focusNodes, boxWidth),
                  if (i != 5) const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
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
                onPressed: loading ? null : onVerify,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: loading
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Verify',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Single OTP box ────────────────────────────────────────────────────────
  Widget _buildOtpBox(
      TextEditingController controller,
      FocusNode focusNode,
      int index,
      List<TextEditingController> allControllers,
      List<FocusNode> allFocus,
      double boxWidth,
      ) {
    return SizedBox(
      width: boxWidth,
      height: 46,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDD6FE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDD6FE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: _gradientStart, width: 1.8),
          ),
        ),
        onChanged: (v) {
          if (v.length == 1 && index < 5) {
            allFocus[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            allFocus[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  // ── PIN row ───────────────────────────────────────────────────────────────
  Widget _pinRow(
      List<TextEditingController> controllers,
      List<FocusNode> focusNodes) {
    // Dynamic box width to prevent overflow
    // Available = screenWidth - scrollPadding(48) - cardPadding(40) - 5 gaps(20)
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth =
    ((screenWidth - 48 - 40 - 20) / 6).floorToDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        6,
            (i) => Row(
          children: [
            SizedBox(
              width: boxWidth,
              height: 50,
              child: TextField(
                controller: controllers[i],
                focusNode: focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: _gradientStart, width: 1.8),
                  ),
                ),
                onChanged: (v) {
                  if (v.length == 1 && i < 5) {
                    focusNodes[i + 1].requestFocus();
                  } else if (v.isEmpty && i > 0) {
                    focusNodes[i - 1].requestFocus();
                  }
                  setState(() {
                    _pin = _pinControllers
                        .map((c) => c.text)
                        .join();
                    _confirmPin = _confirmPinControllers
                        .map((c) => c.text)
                        .join();
                  });
                },
              ),
            ),
            if (i != 5) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ── Role button ───────────────────────────────────────────────────────────
  Widget _roleButton({
    required String label,
    required IconData icon,
    required _UserRole role,
  }) {
    final selected = _userRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _userRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                colors: [_gradientStart, _gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
                : null,
            color: selected ? null : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
              BoxShadow(
                  color: _gradientStart.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF64748B)),
              const SizedBox(height: 5),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
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
