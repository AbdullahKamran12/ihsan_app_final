import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ihsan_app_final/screens/mosqueDisplayScreen.dart';
import 'package:ihsan_app_final/screens/web_signup.dart';
import 'package:ihsan_app_final/main.dart';

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({Key? key}) : super(key: key);

  @override
  _WebLoginPageState createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordVisible = false;

  // ── Palette ────────────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
  static const Color skyLight = Color.fromARGB(255, 220, 240, 255);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color offWhite = Color.fromARGB(255, 247, 249, 255);
  static const Color textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color border = Color.fromARGB(255, 210, 220, 240);

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await saveGuestStatus(false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MosqueDisplayScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _signup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WebSignUpPage()),
    );
  }

  Future<void> _forgotPassword() async {
    final resetController =
        TextEditingController(text: _emailController.text.trim());
    String? sheetError;
    bool sent = false;
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: offWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: navy, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset Password',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textDark)),
                        Text("We'll send a link to your email",
                            style: TextStyle(fontSize: 12, color: textMid)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (!sent) ...[
                  // Email field
                  TextField(
                    controller: resetController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 15, color: textDark),
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      labelStyle: const TextStyle(color: textMid, fontSize: 13),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: navy, size: 20),
                      filled: true,
                      fillColor: white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: gold, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Spam note
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: goldLight,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: gold.withOpacity(0.45), width: 1),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 15, color: Color.fromARGB(255, 160, 120, 20)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "If you don't see it in your inbox, check your spam or junk folder — it most likely ended up there.",
                            style: TextStyle(
                                fontSize: 12,
                                color: Color.fromARGB(255, 120, 90, 20),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (sheetError != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: Color.fromARGB(255, 190, 60, 50)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(sheetError!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color.fromARGB(255, 170, 50, 40))),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: gold))
                        : ElevatedButton(
                            onPressed: () async {
                              final email = resetController.text.trim();
                              if (email.isEmpty) {
                                setS(() => sheetError =
                                    'Please enter your email address.');
                                return;
                              }
                              setS(() {
                                loading = true;
                                sheetError = null;
                              });
                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(email: email);
                                setS(() {
                                  sent = true;
                                  loading = false;
                                });
                              } on FirebaseAuthException catch (e) {
                                setS(() {
                                  loading = false;
                                  sheetError = e.code == 'user-not-found'
                                      ? 'No account found with that email.'
                                      : e.message ??
                                          'Something went wrong. Try again.';
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: gold,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                  color: gold.withOpacity(0.5), width: 1.5),
                              elevation: 0,
                            ),
                            child: const Text('Send Reset Link',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                  ),
                ] else ...[
                  // ── Success state ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 210, 245, 232),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color.fromARGB(255, 72, 200, 155)
                              .withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.mark_email_read_outlined,
                            color: Color.fromARGB(255, 40, 160, 110), size: 36),
                        const SizedBox(height: 10),
                        const Text('Email sent!',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 20, 110, 75))),
                        const SizedBox(height: 6),
                        Text(
                          'A reset link was sent to ${resetController.text.trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color.fromARGB(255, 40, 100, 70)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: goldLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: gold.withOpacity(0.4)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.folder_outlined,
                                  size: 13,
                                  color: Color.fromARGB(255, 140, 100, 20)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Don't see it? Check your spam or junk folder.",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color.fromARGB(255, 120, 90, 20),
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMid,
                        side: const BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── TOP BRANDING ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                decoration: BoxDecoration(
                  color: navy,
                  border: Border(
                    bottom:
                        BorderSide(color: gold.withOpacity(0.35), width: 1.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: navyMid,
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: gold.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mosque_outlined,
                          color: gold, size: 38),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ihsan',
                      style: TextStyle(
                        color: white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إحسان  ·  Your Path to Excellence in Faith',
                      style: TextStyle(
                        color: gold.withOpacity(0.8),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // ── FORM ───────────────────────────────────────────────────
              Container(
                color: offWhite,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(fontSize: 14, color: textMid),
                    ),

                    const SizedBox(height: 24),

                    // Email
                    _loginField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 14),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      style: const TextStyle(fontSize: 15, color: textDark),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle:
                            const TextStyle(color: textMid, fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: navy, size: 20),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                          child: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: textMid,
                            size: 20,
                          ),
                        ),
                        filled: true,
                        fillColor: white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: border, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: gold, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ),

                    // ── Forgot password link ──────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _forgotPassword,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: textMid.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: textMid.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: gold))
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: navy,
                                foregroundColor: gold,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(
                                    color: gold.withOpacity(0.5), width: 1.5),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded,
                                      color: gold, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: gold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: border, height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  color: textMid.withOpacity(0.7),
                                  fontSize: 12)),
                        ),
                        const Expanded(
                            child: Divider(color: border, height: 1)),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Sign Up
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _signup,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: navy.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_outlined,
                                      size: 16, color: textMid),
                                  SizedBox(width: 6),
                                  Text('Sign Up',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textDark,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Error
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 228, 225),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color.fromARGB(255, 220, 100, 90)
                                .withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color.fromARGB(255, 190, 60, 50),
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 170, 50, 40),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textMid, fontSize: 13),
          prefixIcon: Icon(icon, color: navy, size: 20),
          filled: true,
          fillColor: white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: gold, width: 1.5),
          ),
        ),
      );
}
