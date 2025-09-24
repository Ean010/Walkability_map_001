import 'package:flutter/material.dart';
import 'database_service.dart';
import 'models.dart' as model;
import 'main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await result.user?.sendEmailVerification();
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    }
  }

  String _authErrorHandler(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'The email address is malformed.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password.',
      'email-already-in-use' => 'This email is already registered.',
      'weak-password' => 'Password should be at least 6 characters.',
      'operation-not-allowed' => 'Email/password accounts are not enabled.',
      _ => 'An error occurred. Please try again.',
    };
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final firebaseUser = await _authService.signIn(email, password);

      if (firebaseUser != null) {
        if (!firebaseUser.emailVerified) {
          await firebaseUser.sendEmailVerification();
          setState(() => _isLoading = false);
          if (!mounted) return;
          _showSnackBar('Please verify your email first');
          return;
        }

        var localUser = await databaseService.getUserByEmail(email);
        localUser ??= await databaseService.createUser(model.User(
          userID: 0,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? email,
          password: password,
          profilePhoto: null,
        ));

        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPage(user: localUser!)));
        return;
      }

      final user = await databaseService.getUser(email, password);
      setState(() => _isLoading = false);

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPage(user: user)));
      } else {
        if (!mounted) return;
        _showSnackBar('Invalid email or password');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscure = false, TextInputType? keyboardType}) =>
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10.0), border: InputBorder.none),
          obscureText: obscure,
          keyboardType: keyboardType,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('WELCOME', style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 50.0),
                  _buildTextField(_emailController, 'email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 20.0),
                  _buildTextField(_passwordController, 'password', obscure: true),
                  const SizedBox(height: 10.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationPage())),
                        child: const Text('Not a user? Click here', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage())),
                        child: const Text('Forgot password?', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _handleRegistration() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nicknameController.text.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingUser = await databaseService.getUserByEmail(_emailController.text);
      if (existingUser != null) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        _showSnackBar('Email already registered');
        return;
      }

      final user = await _authService.signUp(_emailController.text.trim(), _passwordController.text.trim());

      if (user != null) {
        await databaseService.createUser(model.User(
          userID: 0,
          name: _nicknameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          profilePhoto: null,
        ));

        setState(() => _isLoading = false);
        if (!mounted) return;
        _showSnackBar('Verification email sent!');
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        _showSnackBar('Registration failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscure = false, TextInputType? keyboardType}) =>
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10.0), border: InputBorder.none),
          obscureText: obscure,
          keyboardType: keyboardType,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Create Account', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 40.0),
                  _buildTextField(_nicknameController, 'nickname'),
                  const SizedBox(height: 20.0),
                  _buildTextField(_emailController, 'email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 20.0),
                  _buildTextField(_passwordController, 'password', obscure: true),
                  const SizedBox(height: 30.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _handleResetPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      _showSnackBar('Password reset link sent to your email');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Reset Your Password', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 20.0),
                  const Text('Enter your email address and we will send you instructions to reset your password.', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14)),
                  const SizedBox(height: 40.0),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(hintText: 'email', contentPadding: EdgeInsets.symmetric(horizontal: 10.0), border: InputBorder.none),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send Reset Link', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}