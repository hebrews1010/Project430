import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// GoogleSignIn은 이제 RegisterPage에서 직접 사용하지 않습니다.
//import 'package:google_sign_in/google_sign_in.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourthirty/screens/auth/groupsettingpage.dart'; // 사용자 정의 경로
import 'package:fourthirty/providers/users_provider.dart'; // UsersProvider 클래스가 이 파일에 정의되어 있다고 가정합니다.
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  final User user; // UsersProvider로부터 전달받는 User 객체

  const RegisterPage({super.key, required this.user});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false; // 회원가입 완료 버튼 클릭 시 로딩 상태

  @override
  void initState() {
    super.initState();
    // 전달받은 user 객체의 displayName이 있다면 이름 필드의 초기값으로 설정
    if (widget.user.displayName != null && widget.user.displayName!.isNotEmpty) {
      _nameController.text = widget.user.displayName!;
    }
  }

  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름을 입력해주세요.')),
        );
      }
      return;
    }

    // final DocumentReference<Map<String, dynamic>> userDocRef =
    // FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

    // UsersProvider에서 이미 userDoc 존재 여부를 확인하고 RegisterPage로 오지만,
    // 만약 RegisterPage에 직접 접근하는 다른 경로가 있을 경우를 대비해 한번 더 확인 (선택적)
    // final DocumentSnapshot<Map<String, dynamic>> userSnapshot = await userDocRef.get();
    // if (userSnapshot.exists) {
    //   setState(() { _isLoading = false; });
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('이미 가입된 회원입니다. (Firestore 문서 존재)')),
    //     );
    //     // 이미 가입된 경우 GroupSettingPage로 보내거나 다른 처리를 할 수 있습니다.
    //     Navigator.pushReplacement(
    //       context,
    //       MaterialPageRoute(builder: (context) => const GroupSettingPage()),
    //     );
    //   }
    //   return;
    // }

    try {
      final usersProvider = Provider.of<UsersProvider>(context, listen: false);
      await usersProvider.addUser(name);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // 회원가입 성공 후 UsersProvider의 정보도 업데이트 해주는 것이 좋습니다.
        // 예를 들어, Provider를 통해 currentUserName, currentUserGroupId 등을 설정하고 notifyListeners() 호출
        // Provider.of<UsersProvider>(context, listen: false).updateRegisteredUserData(name, '');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GroupSettingPage()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error registering user to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보 저장 중 오류가 발생했습니다: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추가 정보 입력'), // 제목 변경 가능
        centerTitle: true,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 숨김 (선택적)
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.user.email}(으)로 로그인되었습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                '서비스 사용을 위해 이름을 입력해주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름 (닉네임)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerUser,
                icon: const Icon(Icons.person_add),
                label: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
                    : const Text('가입 완료 및 시작하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
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