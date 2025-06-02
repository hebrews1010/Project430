import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

//import 'package:firebase_auth/firebase_auth.dart';
//import 'package:google_sign_in/google_sign_in.dart';
import 'package:fourthirty/screens/auth/groupsettingpage.dart';

//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourthirty/mainuipage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fourthirty/providers/users_provider.dart'; // UsersProvider 클래스가 이 파일에 정의되어 있다고 가정합니다.
import 'package:fourthirty/screens/auth/register_page.dart';

//import 'dart:html' as html;
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              //const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  // 오류 수정: 변수명을 소문자로 시작하도록 변경 (UsersProvider -> usersProvider)
                  final usersProvider = Provider.of<UsersProvider>(
                    context,
                    listen: false,
                  );
                  // 변경된 변수명 사용
                  final user = await usersProvider.handleSignIn(context);
                  // 변경된 변수명 사용
                  await usersProvider.processSignIn(user, context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Google 계정으로 로그인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final usersProvider = Provider.of<UsersProvider>(
                      context,
                      listen: false,
                    );
                    final User? firebaseUser = await usersProvider.handleSignIn(
                      context,
                    );

                    if (firebaseUser != null && context.mounted) {
                      // context.mounted 확인 추가
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => RegisterPage(user: firebaseUser),
                        ),
                      );
                    } else if (context.mounted) {
                      // 로그인 실패 또는 사용자 취소 시 메시지 표시 (handleSignIn 내부에서도 처리될 수 있음)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Google 인증에 실패했거나 취소되었습니다.'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Google 계정으로 회원가입',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
