import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'package:flutter/foundation.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sign in with email and password
  Future<void> _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        if (kDebugMode) {
          print(
              'Attempting to sign in with email: ${_emailController.text.trim()}');
        }

        // Sign in with email and password
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (kDebugMode) {
          print('Sign in successful: ${userCredential.user?.uid}');
        }

        // Navigate to home after successful login
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) {
          print('Firebase auth exception: ${e.code} - ${e.message}');
        }
        setState(() {
          _errorMessage = _getFirebaseErrorMessage(e.code);
        });
      } catch (e) {
        if (kDebugMode) {
          print('Sign in error: $e');
        }
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Sign in with Google - Simplified and direct Firebase provider method
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        print('Attempting Google Sign-In with Firebase provider...');
      }

      // 1. Create a GoogleAuthProvider instance.
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Optional: Add specific scopes if your application requires them.
      // googleProvider.addScope('https://www.googleapis.com/auth/userinfo.email');
      // googleProvider.addScope('https://www.googleapis.com/auth/userinfo.profile');

      // 2. Sign in with Firebase Auth using the GoogleAuthProvider.
      // This method directly handles the native Google sign-in flow.
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithProvider(googleProvider);

      if (kDebugMode) {
        print('Google Sign-In successful with Firebase.');
        print(
            'User: ${userCredential.user?.displayName}, Email: ${userCredential.user?.email}');
      }

      // 3. Navigate to home page if the widget is still mounted.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
            'FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      }
      String friendlyMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          friendlyMessage =
              'An account already exists with this email using a different sign-in method.';
          break;
        case 'invalid-credential':
          friendlyMessage =
              'The authentication credential provided is invalid.';
          break;
        case 'operation-not-allowed':
          friendlyMessage =
              'Google Sign-In is not enabled in your Firebase project.';
          break;
        case 'user-disabled':
          friendlyMessage = 'This user account has been disabled.';
          break;
        case 'user-not-found': // Should not happen with provider sign-in but good to have
          friendlyMessage = 'No user found for this credential.';
          break;
        case 'popup-closed-by-user': // For web
          friendlyMessage = 'Sign-in popup was closed before completion.';
          break;
        case 'cancelled': // For some native flows
          friendlyMessage = 'Sign-in was cancelled.';
          break;
        default:
          friendlyMessage =
              'Google Sign-In failed: ${e.message ?? "An unknown error occurred."}';
      }
      setState(() {
        _errorMessage = friendlyMessage;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Generic error during Google Sign-In: $e');
      }
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to get user-friendly error messages
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'invalid-credential':
        return 'The credential data is malformed or has expired.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // App Logo or Title
                  Text(
                    'Welcome to Hisaab',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6C4EE3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF6C4EE3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF6C4EE3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navigate to password reset page
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: const Color(0xFF6C4EE3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C4EE3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _isLoading ? null : _signInWithEmailAndPassword,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C4EE3),
                        side: const BorderSide(
                            color: Color(0xFF6C4EE3), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 32,
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _isLoading ? null : _signInWithGoogle,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to registration page
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => const SignupPage()),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Color(0xFF6C4EE3),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    // Debug button - only visible in debug mode
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        onPressed: () async {
                          try {
                            print('===== DEBUGGING FIREBASE CONFIG =====');

                            // Check Firebase initialization
                            final firebaseApp = Firebase.app();
                            print('Firebase app name: ${firebaseApp.name}');
                            print('Firebase options: ${firebaseApp.options}');

                            // Check current auth state
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            print(
                                'Current user: ${currentUser?.uid ?? 'No user signed in'}');

                            // Check available providers for test email
                            try {
                              final providers = await FirebaseAuth.instance
                                  .fetchSignInMethodsForEmail(
                                      'test@example.com');
                              print(
                                  'Available providers for test@example.com: $providers');
                            } catch (e) {
                              print('Error checking providers: $e');
                            }

                            // Test Google Sign-In availability
                            try {
                              final googleSignIn = GoogleSignIn();
                              print('Testing Google Sign-In configuration...');

                              // Note: We can't directly test if Google Sign-In is available
                              // on the device without trying to sign in
                              print('Google Sign-In is configured in the app');
                              print('Possible issues if sign-in fails:');
                              print(
                                  '- SHA certificate fingerprints not configured in Firebase');
                              print(
                                  '- Google Sign-In not enabled in Firebase Auth');
                              print(
                                  '- Incorrect package name in Firebase config');
                            } catch (e) {
                              print('Error checking Google Sign-In: $e');
                            }

                            print('====================================');

                            // Show success alert
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Debug info printed to console')),
                            );
                          } catch (e) {
                            print('Debug error: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: const Text('Debug Firebase Config'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
