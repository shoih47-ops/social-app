import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'create_username_screen.dart';

class LoginScreen extends StatefulWidget {
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    bool isLoading = false;

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

            await checkUsernameAndGo();

            final user = FirebaseAuth.instance.currentUser;

            final prefs = await SharedPreferences.getInstance();
            List<String> accounts = prefs.getStringList('accounts') ?? [];

            // uid|email|password|photoUrl
            String accountData = 
                "${user!.uid}|${user.email}|${passwordController.text}|${user.photoURL ?? ''}";

            if (!accounts.contains(accountData)) {
                accounts.add(accountData);
                await prefs.setStringList('accounts', accounts);
            }
            
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Login failed")),
            );
        }

        setState(() {
            isLoading = false;
        });
    }    

    List<Map<String, dynamic>> savedAccounts = [];

    void loadAccounts() async {
        final prefs = await SharedPreferences.getInstance();
        List<String> accounts = prefs.getStringList('accounts') ?? [];

        savedAccounts = [];
        
        for (String acc in accounts) {
            List<String> parts = acc.split('|');

            if (parts.length >= 4) {
                savedAccounts.add({            
                    'uid': parts[0],
                    'email': parts[1],
                    'password': parts[2],
                    'photo': parts[3],
                });
            };
        }

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

    Future<void> signInWithGoogle() async {
        try {
            final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

            if (googleUser == null) return;

            final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

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
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
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
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Google login failed")),
            );
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

            if (!doc.exists || doc.data()?['username'] == null || doc.data()?['username'] =='') {
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
            backgroundColor: Colors.grey[200],
            body: Center(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 10,
                                        offset: Offset(0, 5),
                                    )
                                ],
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                    // TITLE
                                    const Text(
                                        "Welcome 👋",
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                        ),
                                    ),

                                    const SizedBox(height: 20),                                    

                                    Column(
                                        children: savedAccounts.map((acc) {
                                            return ListTile(
                                                leading: CircleAvatar(
                                                    radius: 22,
                                                    backgroundImage: acc['photo'] != ''
                                                        ? NetworkImage(acc['photo']!)
                                                        : null,
                                                    child: acc['photo'] == '' ? Icon(Icons.person) : null,
                                                ),
                                                title: Text(acc['email']!),
                                                onTap: () async {
                                                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                                                        email: acc['email']!,
                                                        password: acc['password']!,
                                                    );

                                                    await checkUsernameAndGo();
                                                },
                                            );
                                        }).toList(),
                                    ),

                                    // EMAIL
                                    TextField(
                                        controller: emailController,
                                        decoration: InputDecoration(
                                            prefixIcon: Icon(Icons.email),
                                            hintText: "Email",
                                            filled: true,
                                            fillColor: Colors.grey[200],
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(15),
                                                borderSide: BorderSide.none,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 15),

                                    TextField(
                                        controller: passwordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                            prefixIcon: Icon(Icons.lock),
                                            hintText: "Password",
                                            filled: true,
                                            fillColor: Colors.grey[200],
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(15),
                                                borderSide: BorderSide.none,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 25),

                                    // LOGIN BUTTON
                                    SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                            onPressed: login,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.deepPurple,
                                                padding: const EdgeInsets.symmetric(vertical: 15),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(15),
                                                ),
                                            ),
                                            child: isLoading
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : const Text(
                                                    "Login",
                                                    style: TextStyle(                                                    
                                                        fontSize: 16,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                    ),
                                                ),
                                        ),
                                    ),

                                    const SizedBox(height: 10),

                                    SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                            onPressed: signInWithGoogle,
                                            icon: Icon(Icons.g_mobiledata, size: 28),
                                            label: Text("Continue with Google"),
                                            style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(15),
                                                ),
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 10),

                                    // REGISTER
                                    TextButton(
                                        onPressed: register,
                                        child: const Text("Create new account"),
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