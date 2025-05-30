import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourthirty/groupsettingpage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  User? _user;
  bool _googleAuthTried = false;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });
    final User? user = await _signInWithGoogle();
    setState(() {
      _isLoading = false;
      _googleAuthTried = true;
      _user = user;
    });
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 계정 인증에 실패했습니다.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential.user;
    } catch (error) {
      print('Google 로그인 에러: $error');
      return null;
    }
  }

  Future<void> _registerUser() async {
    if (_user == null) return;
    setState(() {
      _isLoading = true;
    });
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }
    final DocumentReference<Map<String, dynamic>> userDoc = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
    final DocumentSnapshot<Map<String, dynamic>> userSnapshot = await userDoc.get();
    if (userSnapshot.exists) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 가입된 회원입니다.')),
      );
      return;
    }
    await userDoc.set({
      'display_name': name,
      'email': _user!.email,
      'user_group_id': '',
      'created_at': FieldValue.serverTimestamp(),
    });
    setState(() {
      _isLoading = false;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GroupSettingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_googleAuthTried) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      // 구글 인증 실패 시 아무것도 보여주지 않음(뒤로가기 처리됨)
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerUser,
                icon: const Icon(Icons.person_add),
                label: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('회원가입 완료'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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