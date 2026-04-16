import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ihsan_app_final/screens/web_login.dart';
import 'package:ihsan_app_final/screens/mosqueDisplayScreen.dart';

// Mosque selection happens on first login via the display screen setup flow,
// NOT here. Only auth credentials + name + username collected.

class WebSignUpPage extends StatefulWidget {
  const WebSignUpPage({Key? key}) : super(key: key);
  @override
  _WebSignUpPageState createState() => _WebSignUpPageState();
}

class _WebSignUpPageState extends State<WebSignUpPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      final user = cred.user;
      if (user != null) {
        await _firestore.collection('UserData').doc(user.uid).set({
          'email': user.email,
          'displayName': _nameCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'postCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MosqueDisplayScreen()));
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered. Please log in instead.';
          break;
        case 'weak-password':
          msg = 'Password too weak — use at least 6 characters.';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email address.';
          break;
        default:
          msg = 'An error occurred during signup: ${e.message}';
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  void _goToLogin() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const WebLoginPage()));

  @override
  Widget build(BuildContext context) {
    const navy = Color.fromARGB(255, 10, 25, 60);
    const navyMid = Color.fromARGB(255, 18, 42, 95);
    const gold = Color.fromARGB(255, 212, 175, 95);
    const white = Color.fromARGB(255, 255, 255, 255);
    const offWhite = Color.fromARGB(255, 247, 249, 255);
    const textDark = Color.fromARGB(255, 15, 30, 65);
    const textMid = Color.fromARGB(255, 90, 115, 160);
    const border = Color.fromARGB(255, 210, 220, 240);

    Widget inputField({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      bool obscure = false,
      bool showToggle = false,
      TextInputType keyboard = TextInputType.text,
      String? Function(String?)? validator,
    }) =>
        TextFormField(
          controller: controller,
          obscureText: obscure && !_passwordVisible,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 15, color: textDark),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: textMid, fontSize: 13),
            prefixIcon: Icon(icon, color: navy, size: 20),
            suffixIcon: showToggle
                ? GestureDetector(
                    onTap: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                    child: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: textMid,
                        size: 20),
                  )
                : null,
            filled: true,
            fillColor: white,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: border, width: 1)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: gold, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color.fromARGB(255, 200, 60, 60), width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color.fromARGB(255, 200, 60, 60), width: 1.5)),
          ),
          validator: validator,
        );

    return Scaffold(
      backgroundColor: navy,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
              decoration: BoxDecoration(
                color: navy,
                border: Border(
                    bottom:
                        BorderSide(color: gold.withOpacity(0.35), width: 1.5)),
              ),
              child: Column(children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _goToLogin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: navyMid,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: gold.withOpacity(0.35), width: 1)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.arrow_back_ios_rounded,
                              color: gold.withOpacity(0.7), size: 12),
                          const SizedBox(width: 4),
                          Text('Back',
                              style: TextStyle(
                                  color: gold.withOpacity(0.7), fontSize: 12)),
                        ]),
                      ),
                    )),
                const SizedBox(height: 20),
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
                              spreadRadius: 2)
                        ]),
                    child: const Icon(Icons.mosque_outlined,
                        color: gold, size: 38)),
                const SizedBox(height: 16),
                const Text('Ihsan',
                    style: TextStyle(
                        color: white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('إحسان  ·  Your Path to Excellence in Faith',
                    style: TextStyle(
                        color: gold.withOpacity(0.8),
                        fontSize: 12,
                        letterSpacing: 0.5),
                    textAlign: TextAlign.center),
              ]),
            ),

            // Form
            Container(
              color: offWhite,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Create Account',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                              letterSpacing: 0.2)),
                      const SizedBox(height: 4),
                      const Text(
                        "You'll choose your mosque display after creating your account.",
                        style: TextStyle(fontSize: 13, color: textMid),
                      ),
                      const SizedBox(height: 24),

                      // Account section
                      _sectionLabel(
                          'ACCOUNT', Icons.lock_outline_rounded, navy),
                      const SizedBox(height: 10),
                      inputField(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Email is required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(v))
                              return 'Please enter a valid email';
                            return null;
                          }),
                      const SizedBox(height: 12),
                      inputField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          showToggle: true,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Password is required';
                            if (v.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          }),
                      const SizedBox(height: 20),

                      // Profile section
                      _sectionLabel(
                          'PROFILE', Icons.person_outline_rounded, navy),
                      const SizedBox(height: 10),
                      inputField(
                          controller: _nameCtrl,
                          label: 'Full Name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Full name is required'
                              : null),
                      const SizedBox(height: 12),
                      inputField(
                          controller: _usernameCtrl,
                          label: 'Username',
                          icon: Icons.alternate_email_rounded,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Username is required';
                            if (v.contains(' '))
                              return 'Username cannot contain spaces';
                            return null;
                          }),
                      const SizedBox(height: 28),

                      // Submit
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: gold))
                          : GestureDetector(
                              onTap: () {
                                if (_formKey.currentState!.validate())
                                  _signUp();
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                    color: navy,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                        color: gold.withOpacity(0.55),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                          color: navy.withOpacity(0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4))
                                    ]),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded,
                                          color: gold, size: 18),
                                      SizedBox(width: 8),
                                      Text('Create Account',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: gold,
                                              letterSpacing: 0.3)),
                                    ]),
                              ),
                            ),

                      const SizedBox(height: 14),

                      Center(
                          child: GestureDetector(
                        onTap: _goToLogin,
                        child: RichText(
                            text: TextSpan(
                          text: 'Already have an account?  ',
                          style: const TextStyle(fontSize: 13, color: textMid),
                          children: [
                            TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: gold.withOpacity(0.9)))
                          ],
                        )),
                      )),

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
                                  width: 1)),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color.fromARGB(255, 190, 60, 50),
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_errorMessage!,
                                    style: const TextStyle(
                                        color: Color.fromARGB(255, 170, 50, 40),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500))),
                          ]),
                        ),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      );
}
