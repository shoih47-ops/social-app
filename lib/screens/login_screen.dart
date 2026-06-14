import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'create_username_screen.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> checkUsernameAndGo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (!doc.exists || data?['username'] == null || data?['username'] == '') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CreateUsernameScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    }
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveRecentAccount(user);
      }

      await checkUsernameAndGo();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed")));
    }

    setState(() {
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> savedAccounts = [];

  Future<void> _saveRecentAccount(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    final name = (data?['username'] ?? user.displayName ?? '').toString();
    final photo = (data?['photoUrl'] ?? data?['photo'] ?? user.photoURL ?? '')
        .toString();
    final email = (user.email ?? emailController.text.trim()).trim();

    if (email.isEmpty) return;

    final accountData = '${user.uid}|$name|$email|$photo';
    final updatedAccounts = accounts.where((account) {
      final parts = account.split('|');
      if (parts.length >= 2 && parts[1] == email) return false;
      if (parts.length >= 3 && parts[2] == email) return false;
      if (parts.isNotEmpty && parts[0] == user.uid) return false;
      return true;
    }).toList();

    updatedAccounts.insert(0, accountData);

    await prefs.setStringList(
      'accounts',
      updatedAccounts.take(5).toList(),
    );
  }

  void loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList('accounts') ?? [];

    savedAccounts = [];

    for (String acc in accounts) {
      if (savedAccounts.length >= 5) break;

      List<String> parts = acc.split('|');

      if (parts.length >= 4) {
        final isNewAccountFormat = parts[2].contains('@');
        final email = isNewAccountFormat ? parts[2] : parts[1];
        final name = isNewAccountFormat ? parts[1] : email.split('@').first;

        savedAccounts.add({
          'uid': parts[0],
          'name': name,
          'email': email,
          'photo': parts[3],
        });
      } else if (parts.length == 1 && parts[0].contains('@')) {
        savedAccounts.add({
          'uid': '',
          'name': parts[0].split('@').first,
          'email': parts[0],
          'photo': '',
        });
      }
    }

    await prefs.setStringList(
      'accounts',
      savedAccounts.map((account) {
        return '${account['uid']}|${account['name']}|'
            '${account['email']}|${account['photo']}';
      }).toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  void clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accounts');
  }

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      /// Create Firestore user if first time
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'username': '',
          'photo': user.photoURL,
        });

        // new user -> ask username
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CreateUsernameScreen()),
        );
        return;
      }

      final data = doc.data();

      if (data == null || data['username'] == null || data['username'] == '') {
        // username missing -> ask
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CreateUsernameScreen()),
        );
      } else {
        // Normal user -> home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google login failed")));
    }
  }

  Future<void> register() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save account
      final prefs = await SharedPreferences.getInstance();
      List<String> emails = prefs.getStringList('accounts') ?? [];

      if (!emails.contains(emailController.text.trim())) {
        emails.add(emailController.text.trim());
        await prefs.setStringList('accounts', emails);
      }

      final user = FirebaseAuth.instance.currentUser;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!doc.exists ||
          doc.data()?['username'] == null ||
          doc.data()?['username'] == '') {
        // Go to Create Username Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CreateUsernameScreen()),
        );
      } else {
        // Go to Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Gradient header
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C4DFF), Color(0xFF3F51B5)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Welcome 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Capture and share your real life moments — beautifully and easily.',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),

              // Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  transform: Matrix4.translationValues(0.0, -48.0, 0.0),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtitle / Theme
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Share your real life moments',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Saved accounts (modern cards)
                      if (savedAccounts.isNotEmpty)
                        Column(
                          children: savedAccounts.map((acc) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundImage: acc['photo'] != ''
                                      ? NetworkImage(acc['photo']!)
                                      : null,
                                  child: acc['photo'] == ''
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                  acc['name']!.toString().trim().isEmpty
                                      ? acc['email']!
                                      : acc['name']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  acc['email']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                                onTap: () {
                                  final email = acc['email']!;
                                  emailController.value = TextEditingValue(
                                    text: email,
                                    selection: TextSelection.collapsed(
                                      offset: email.length,
                                    ),
                                  );
                                  passwordController.clear();
                                },
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 8),

                      // Email field
                      TextField(
                        controller: emailController,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 14,
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                          hintText: 'Email',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Password field
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: 'Password',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CFF),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.0,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 22),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateAccountScreen(),
                                ),
                              );
                            },
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
