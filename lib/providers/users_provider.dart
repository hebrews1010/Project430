import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fourthirty/screens/auth/groupsettingpage.dart'; // 사용자 정의 경로
import 'package:fourthirty/mainuipage.dart'; // 사용자 정의 경로
import 'package:fourthirty/screens/auth/register_page.dart'; // 사용자 정의 경로
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersProvider with ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  UsersProvider(this._auth, this._googleSignIn, this._firestore);

  // 사용자 정보 및 상태 변수
  DocumentSnapshot<Map<String, dynamic>>? userDoc;
  OAuthCredential? credential;
  GoogleSignInAccount? googleUser; // Google 로그인 시 받는 계정 정보
  GoogleSignInAuthentication? googleAuth; // Google 인증 토큰 정보

  // 다른 페이지에서 접근할 사용자 정보 변수
  User? user; // 현재 로그인된 Firebase User 객체 << 사용자가 추가한 필드
  String? currentUserUid;
  String? currentUserName;
  String? currentUserGroupId;

  Future<User?> handleSignIn(BuildContext context) async {
    if (kIsWeb) {
      print("Web Sign-In: Attempting...");
      try {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        user = userCredential.user; // Provider의 user 필드에 할당

        if (user != null) {
          currentUserUid = user!.uid;
          currentUserName = user!.displayName;
          notifyListeners();
          print("Web Sign-In: Successful for ${user!.email}");
        } else {
          print("Web Sign-In: Failed, user is null.");
        }
        return user;
      } catch (error, stackTrace) {
        print('Web Sign-In: Error: $error \nStack: $stackTrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('웹 로그인에 실패했습니다: ${error.toString()}')),
          );
        }
        user = null; // 에러 발생 시 Provider의 user 필드 초기화
        notifyListeners();
        return null;
      }
    } else { // 모바일 환경
      print("Mobile Sign-In: Attempting...");
      try {
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print('Mobile Sign-In: User cancelled or failed (googleUser is null).');
          // context.mounted 확인은 ScaffoldMessenger 사용 전에 이미 되어있다고 가정
          // (이 메소드를 호출하는 UI에서 context 유효성을 관리해야 함)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 로그인을 취소했거나 실패했습니다.')),
          );
          return null;
        }
        print('Mobile Sign-In: Google user obtained: ${googleUser?.email}');

        googleAuth = await googleUser!.authentication;
        if (googleAuth == null) {
          print('Mobile Sign-In: Error - googleUser.authentication resolved to null.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 인증 정보를 가져오는데 실패했습니다.')),
          );
          return null;
        }
        // print('Mobile Sign-In: GoogleSignInAuthentication retrieved.'); // 상세 로그 제거

        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth!.accessToken,
          idToken: googleAuth!.idToken,
        );
        // print('Mobile Sign-In: Firebase credential created.'); // 상세 로그 제거

        final UserCredential userCredential = await _auth.signInWithCredential(credential!);
        user = userCredential.user; // Provider의 user 필드에 할당

        if (user != null) {
          currentUserUid = user!.uid;
          currentUserName = user!.displayName;
          notifyListeners();
          print("Mobile Sign-In: Firebase sign-in successful: ${user!.email}");
        } else {
          print("Mobile Sign-In: Firebase sign-in failed, user is null.");
        }
        return user;

      } catch (e, stackTrace) {
        print('Mobile Sign-In: Error during sign-in process: $e \nStack: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모바일 로그인 중 오류: ${e.toString()}')),
        );
        user = null; // 에러 발생 시 Provider의 user 필드 초기화
        notifyListeners();
        return null;
      }
    }
  }

  // processSignIn의 user 파라미터는 handleSignIn의 결과를 직접 받거나,
  // Provider의 this.user를 사용할 수 있습니다. 현재는 파라미터를 받는 구조 유지.
  // 만약 this.user를 사용한다면: Future<void> processSignIn(BuildContext context) async { ... final User? userToProcess = this.user; ... }
  Future<void> processSignIn(User? userToProcess, BuildContext context) async {
    if (userToProcess == null) {
      print("ProcessSignIn: User to process is null. Cannot proceed.");
      return;
    }
    // this.user 와 userToProcess가 다를 경우를 대비하거나, this.user를 userToProcess로 업데이트 할 수 있음.
    // 여기서는 전달된 userToProcess를 기준으로 진행.
    // Provider 내부 상태와 일치시키기
    if (this.user == null || this.user!.uid != userToProcess.uid) {
      this.user = userToProcess;
    }
    if (currentUserUid == null || currentUserUid != userToProcess.uid) {
      currentUserUid = userToProcess.uid;
    }
    if (currentUserName == null && userToProcess.displayName != null){ // Firestore에 이름이 없을 경우 대비
      currentUserName = userToProcess.displayName;
    }


    print("ProcessSignIn: Processing for user ${userToProcess.uid}");
    try {
      userDoc = await _firestore.collection('users').doc(userToProcess.uid).get();

      if (!context.mounted) return;

      if (userDoc!.exists) {
        final data = userDoc!.data();
        print("ProcessSignIn: User document exists for ${userToProcess.uid}.");
        if (data != null) {
          if (data.containsKey('user_name') && data['user_name'] != null) {
            currentUserName = data['user_name'] as String?;
          }
          currentUserGroupId = data['user_group_id'] as String?; // null일 수 있음

          notifyListeners();

          if (currentUserGroupId != null && currentUserGroupId!.isNotEmpty) {
            // print("ProcessSignIn: User has group ID ($currentUserGroupId), navigating to MainUiPage."); // 상세 로그 제거
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainUiPage()),
            );
          } else {
            // print("ProcessSignIn: User has no group ID or it's empty, navigating to GroupSettingPage."); // 상세 로그 제거
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GroupSettingPage()),
            );
          }
        } else {
          print("ProcessSignIn: User document data is null for ${userToProcess.uid}. Navigating to GroupSettingPage.");
          currentUserGroupId = null;
          notifyListeners();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GroupSettingPage()),
          );
        }
      } else {
        print("ProcessSignIn: User document does not exist for ${userToProcess.uid}. Navigating to RegisterPage.");
        currentUserName = userToProcess.displayName; // Firestore에 없으므로 Google/Apple 기본 이름 사용
        currentUserGroupId = null;
        notifyListeners();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 필요합니다. 추가 정보를 입력해주세요.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RegisterPage(user: userToProcess)),
        );
      }
    } catch (e, stackTrace) {
      print("ProcessSignIn: Error: $e \nStack: $stackTrace");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보 처리 중 오류: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> logout({BuildContext? context}) async {
    print("Logout: Starting logout process.");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);

    try {
      await _auth.signOut();
      print("Logout: Signed out from FirebaseAuth.");
    } catch (e) {
      print("Logout: Error signing out from FirebaseAuth: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase 로그아웃 중 오류: ${e.toString()}')),
        );
      }
    }

    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print("Logout: Signed out from GoogleSignIn.");
      } else {
        // print("Logout: GoogleSignIn user was not signed in or already signed out."); // 불필요한 로그 제거
      }
    } catch (e) {
      print("Logout: Error signing out from GoogleSignIn: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 로그아웃 중 오류: ${e.toString()}')),
        );
      }
    }

    // 상태 변수 초기화
    user = null; // << 새로 추가된 user 필드 초기화
    googleUser = null;
    googleAuth = null;
    credential = null;
    userDoc = null;
    currentUserUid = null;
    currentUserName = null;
    currentUserGroupId = null;
    print("Logout: All local user data and auth details cleared.");

    notifyListeners();
    // print("Logout: Logout process completed and listeners notified."); // 상세 로그 제거
  }

  Future<void> addUser(String name) async {
    if (user == null) {
      print("AddUser: No user to add. User is null.");
      return;
    }
    try {
      final userDocRef = _firestore.collection('users').doc(user!.uid);
      final userDocSnapshot = await userDocRef.get();

      if (userDocSnapshot.exists) {
        print("AddUser: User document already exists for ${user!.uid}. Not adding again.");
        return; // 이미 존재하는 경우 추가하지 않음
      }

      await userDocRef.set({
        'user_name': name,
        'email': user!.email,
        'user_group_id': '', // 초기 그룹 ID는 비워둠
        'created_at': FieldValue.serverTimestamp(),
        'uid': user!.uid, // UID도 저장 (선택 사항이지만 유용할 수 있음)
      });

      print("AddUser: User added successfully for ${user!.uid}.");
    } catch (e) {
      print("AddUser: Error adding user to Firestore: $e");
    }
  }

}