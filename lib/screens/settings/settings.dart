import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fourthirty/screens/auth/loginpage.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;
  String userName = '';
  bool autoLogin = false;
  bool ing = false;

  //final GoogleSignIn googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    _loadUserSettings();
  }

  _loadUserSettings() async {
    // 현재 사용자 이름 불러오기
    var userDoc =
        await _firestore.collection('users').doc(currentUser?.uid).get();
    if (userDoc.exists) {
      setState(() {
        userName = userDoc.data()?['user_name'] ?? '';
      });
    }

    // 자동 로그인 설정 불러오기
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      autoLogin = prefs.getBool('auto_login') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('사용자 이름: $userName'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editUserName(),
            ),
          ),
          ListTile(
            title: const Text('파일 및 이미지 저장 경로 초기화'),
            onTap: () => _resetDownloadPath(),
          ),
          ListTile(
            title: const Text('그룹 탈퇴'),
            onTap: () => leaveGroup(currentUser?.uid, false),
          ),
          ListTile(
            title: const Text('계정 삭제'),
            onTap: () => _deleteAccount(),
          ),
          SwitchListTile(
            title: const Text('자동 로그인'),
            value: autoLogin,
            onChanged: (bool value) {
              setState(() {
                autoLogin = value;
              });
              _setAutoLogin(value);
            },
          ),
          ListTile(
            title: const Text('로그아웃'),
            onTap: () => _logout(),
          ),
        ],
      ),
    );
  }

// 사용자 이름 수정 기능 구현
  void _editUserName() async {
    TextEditingController nameController =
        TextEditingController(text: userName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 이름 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '새 사용자 이름'),
        ),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('저장'),
            onPressed: () async {
              if (ing == true) {
                null;
              } else {
                ing = true;
                var newName = nameController.text;
                await _firestore
                    .collection('users')
                    .doc(currentUser?.uid)
                    .update({'user_name': newName});
                setState(() {
                  userName = newName;
                });
                ing = false;
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

// 파일 및 이미지 저장 경로 초기화 기능 구현
  void _resetDownloadPath() async {
    var confirmInit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장 경로 초기화 확인'),
        content: const Text('저장 경로를 초기화하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('초기화'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmInit != true) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('download_directory');
  }

// 그룹 탈퇴 기능 구현
  Future<void> leaveGroup(String? uid, bool fromDeleteAccount) async {
    var confirmLeave = fromDeleteAccount
        ? true
        : showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('그룹 탈퇴 확인'),
              content: const Text('정말로 그룹에서 탈퇴하시겠습니까?'),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('탈퇴'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          );

    if (confirmLeave != true || uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userGroupId = userDoc.data()?['user_group_id'];
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(userGroupId)
        .get();
    List groupUsers = groupDoc['group_users'];
    bool isAlone = (groupUsers.length == 1 && groupUsers.contains(uid));

    if (userGroupId != null) {
      // 그룹에서 사용자 제거
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(userGroupId)
          .update({
        'group_users': FieldValue.arrayRemove([uid])
      });

      // 사용자의 user_group_id 필드 비우기
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'user_group_id': ''});

      // 관리하는 작업에서 사용자 제거
      final tasksQuerySnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('managed_by', isNotEqualTo: uid)
          .get();

      for (var task in tasksQuerySnapshot.docs) {
        var assignedUsers = List.from(task['assigned_users']);
        if (assignedUsers.contains(uid)) {
          int userIndex = assignedUsers.indexOf(uid);
          var states = List.from(task['state']);
          var alerts = List.from(task['alert']);
          states.removeAt(userIndex);
          alerts.removeAt(userIndex);

          assignedUsers.remove(uid);
          if (assignedUsers.isEmpty) {
            await task.reference.delete();
          } else {
            await task.reference.update({
              'assigned_users': assignedUsers,
              'state': states,
              'alert': alerts
            });
          }
        }
      }

      //내가 관리하는 업무를 관리자에게 떠넘기기
      final tasksQuerySnapshot2 = await FirebaseFirestore.instance
          .collection('tasks')
          .where('managed_by', isEqualTo: uid)
          .get();

      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(userGroupId)
          .get();

      for (var doc in tasksQuerySnapshot2.docs) {
        List<dynamic> assignedUsers = doc['assigned_users'] ?? [];
        String taskManager = groupDoc['group_manager'] ?? '';
        var states = List.from(doc['state']);
        var alerts = List.from(doc['alert']);
        // 'assigned_users' 배열에 현재 사용자의 uid가 있는 경우
        if (assignedUsers.contains(uid)) {
          int userIndex = assignedUsers.indexOf(uid);

          states.removeAt(userIndex);
          alerts.removeAt(userIndex);
          assignedUsers.remove(uid);
        }
        await doc.reference.update({
          'assigned_users': assignedUsers,
          'managed_by': taskManager,
          'state': states,
          'alert': alerts
        });
      }

      // 작성한 게시물 삭제
      final postsQuerySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('made_by', isEqualTo: uid)
          .get();

      for (var doc in postsQuerySnapshot.docs) {
        var commentsSnapshot = await FirebaseFirestore.instance
            .collection('comments')
            .where('post_id', isEqualTo: doc.id)
            .get();
        for (var docu in commentsSnapshot.docs) {
          await docu.reference.delete();
        }

        // Firebase Storage에서 파일 및 이미지 삭제
        FirebaseStorage storage = FirebaseStorage.instance;
        List<dynamic> fileUrls = doc['fileUrl'] ?? [];
        List<dynamic> imageUrls = doc['imageUrl'] ?? [];

        for (var fileUrl in fileUrls) {
          if (fileUrl != null) {
            var fileRef = storage.refFromURL(fileUrl);
            await fileRef.delete();
          }
        }

        for (var imageUrl in imageUrls) {
          if (imageUrl != null) {
            var imageRef = storage.refFromURL(imageUrl);
            await imageRef.delete();
          }
        }
        await doc.reference.delete();
      }

      // 그룹 탈퇴 처리 후 로직 (예: 홈 화면으로 이동)
      _logout();
    }
    if (isAlone) {
      groupDoc.reference.delete();
    }
  }

// 계정 삭제 기능 구현
  void _deleteAccount() async {
    var uid = currentUser?.uid;
    var confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제 확인'),
        content: const Text('정말로 계정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('삭제'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmDelete != true || uid == null) return;

    await leaveGroup(currentUser?.uid, true);

    // 4. 'users' 컬렉션에서 사용자 문서 삭제
    await _firestore.collection('users').doc(uid).delete();

    // 로그인 페이지로 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false, // false는 모든 이전 루트들을 제거합니다.
    );
  }

// 자동 로그인 설정 기능 구현
  void _setAutoLogin(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', value);
  }

// 로그아웃 기능 구현
  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut(); // 구글 로그인 데이터 초기화

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false, // false는 모든 이전 루트들을 제거합니다.
    );
  }
}
