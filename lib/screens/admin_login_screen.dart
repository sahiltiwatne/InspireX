import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home_screen.dart';

const _gradientStart = Color(0xFF7C3AED);
const _gradientMid   = Color(0xFF8B5CF6);
const _gradientEnd   = Color(0xFF3B82F6);

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO ADD ADMINS IN FIRESTORE:
// Collection: "admins"
// Document ID: any (e.g. "admin1")
// Fields:
//   email: "admin@inspirex.com"
//   password: "yourpassword"  ← plain text (or hashed in production)
//   name: "Admin Name"
// ─────────────────────────────────────────────────────────────────────────────

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePass    = true;
  String _emailError   = '';
  String _passwordError = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    setState(() {
      _emailError    = '';
      _passwordError = '';
    });

    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Query Firestore admins collection
      final query = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _isLoading   = false;
          _emailError  = 'No admin found with this email.';
        });
        return;
      }

      final adminData = query.docs.first.data();
      final storedPassword = adminData['password'] as String? ?? '';

      if (storedPassword != password) {
        setState(() {
          _isLoading     = false;
          _passwordError = 'Incorrect password.';
        });
        return;
      }

      final adminName = adminData['name'] as String? ?? 'Admin';

      setState(() => _isLoading = false);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminHomeScreen(adminName: adminName),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Login failed. Please try again.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

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
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // Back button
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
                const SizedBox(height: 24),

                // Logo
                _buildLogo(),
                const SizedBox(height: 36),

                // Card
                _buildCard(),
                const SizedBox(height: 24),

                Text(
                  'Admin access only • Authorised personnel',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x557C3AED),
                      blurRadius: 28,
                      spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.admin_panel_settings_outlined,
                  size: 38, color: _gradientStart),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('InspireX Admin',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Secure Admin Portal',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildCard() {
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
          // Admin badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gradientStart.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _gradientStart.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    color: _gradientStart, size: 14),
                const SizedBox(width: 5),
                Text('Admin Login',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _gradientStart)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Email field
          _fieldLabel('Admin Email'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _emailController,
            hint: 'admin@inspirex.com',
            keyboardType: TextInputType.emailAddress,
            error: _emailError,
          ),
          if (_emailError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_emailError,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),

          // Password field
          _fieldLabel('Password'),
          const SizedBox(height: 6),
          _buildPasswordField(),
          if (_passwordError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_passwordError,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.redAccent)),
            ),
          const SizedBox(height: 28),

          // Login button
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
                      offset: const Offset(0, 4)),
                ],
              ),
              child: TextButton(
                onPressed: _isLoading ? null : _handleAdminLogin,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Login as Admin',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151)));

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String error = '',
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
          borderSide: BorderSide(
              color: error.isNotEmpty
                  ? Colors.redAccent
                  : const Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: error.isNotEmpty
                  ? Colors.redAccent
                  : const Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: _gradientStart, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePass,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: 'Enter your password',
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
          onTap: () =>
              setState(() => _obscurePass = !_obscurePass),
          child: Icon(
            _obscurePass
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF9CA3AF),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: _passwordError.isNotEmpty
                  ? Colors.redAccent
                  : const Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: _passwordError.isNotEmpty
                  ? Colors.redAccent
                  : const Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: _gradientStart, width: 1.5),
        ),
      ),
    );
  }
}