import 'package:flutter/material.dart';
import 'mainuipage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupSettingPage extends StatefulWidget {
  const GroupSettingPage({super.key});

  @override
  State<GroupSettingPage> createState() => _GroupSettingPageState();
}

class _GroupSettingPageState extends State<GroupSettingPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // '그룹 생성하기' 버튼을 눌렀을 때의 동작 구현
                _showGroupNameDialog(context);
              },
              child: const Text('그룹 생성하기'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // '그룹 가입하기' 버튼을 눌렀을 때의 동작 구현
                _joinGroup(context);
              },
              child: const Text('그룹 가입하기'),
            ),
          ],
        ),
      ),
    );
  }

  void _createGroup(BuildContext context, String groupName) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference groups = firestore.collection('groups');
    User? user = FirebaseAuth.instance.currentUser;
    List initialGroupUsers = [
      user?.uid,
    ];

    // 새 그룹 문서 생성
    DocumentReference newGroupRef = await groups.add({
      'group_name': groupName,
      'created_at': DateTime.now().toIso8601String(),
      'group_manager': user?.uid,
      'group_users': initialGroupUsers,
    });

    String newGroupId = newGroupRef.id;

    if (user != null) {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference usersCollection = firestore.collection('users');

      // 사용자의 UID를 기반으로 해당 사용자의 문서 가져오기
      DocumentReference userDocRef = usersCollection.doc(user.uid);

      try {
        // 사용자 문서가 있는지 확인
        DocumentSnapshot userSnapshot = await userDocRef.get();

        if (userSnapshot.exists) {
          // 문서가 있는 경우, 업데이트 수행
          await userDocRef.update({
            'user_group_id': newGroupId,
          });
          print('user_group_id가 업데이트되었습니다.');
        } else {
          // 문서가 없는 경우, 새로운 문서 생성
          await userDocRef.set({
            'user_group_id': newGroupId,
          });
          print('새로운 사용자 문서가 생성되었습니다.');
        }
      } catch (error) {
        print('업데이트 중 오류 발생: $error');
      }
    }

    //그룹 생성 완료 메시지 표시 및 MainUiPage로 이동
    print('그룹이 생성되었습니다! 그룹 코드: $newGroupId');

    moveToMainUiPage(); //만료된 위젯 트리를 참조해서 페이지 이동이 안될 경우 퓨처 함수로 이동을 따로 구현하고 그 함수를 쓰면 됨
  }

  Future<void> moveToMainUiPage() async {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const MainUiPage(), // MainUIPage()는 이동하고자 하는 페이지입니다.
        ));
  }

  void _joinGroup(BuildContext context) {
    // 사용자가 그룹 번호를 입력하여 그룹 가입하는 기능
    // 여기에서 사용자가 입력한 그룹 번호로 그룹에 가입할 수 있습니다.
    // 가입 완료 시, AlertDialog 또는 스낵바 등을 통해 가입 완료 메시지를 보여줄 수 있습니다.
    // 예시로 AlertDialog를 사용한 구현
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('그룹 가입'),
          content: TextField(
            controller: _groupIdController, //아직 다 안했어요 받은걸 보내줘야함
            decoration: const InputDecoration(labelText: '그룹 코드'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                String groupId = _groupIdController.text;
                groupAssign(groupId);
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> groupAssign(String groupId) async {
    // 현재 사용자의 UID 가져오기
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // 사용자가 로그인되어 있지 않으면 작업 중단
      return;
    }

    // 그룹 ID 가져오기 (여기에서는 그룹 ID가 고정되어 있다고 가정)
    //String groupId = groupId;

    // Firestore에서 해당 그룹 문서 가져오기
    DocumentReference groupDocRef =
        FirebaseFirestore.instance.collection('groups').doc(groupId);

    // 그룹 문서 가져오기
    DocumentSnapshot groupSnapshot = await groupDocRef.get();

    print('가입시도');
    if (groupSnapshot.exists) {
      // 그룹 문서가 존재하는 경우
      List<dynamic> groupUsers = groupSnapshot['group_users'] ?? [];
      if (!groupUsers.contains(user.uid)) {
        // 현재 사용자의 UID가 그룹에 추가되어 있지 않으면 추가
        groupUsers.add(user.uid);
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        CollectionReference usersCollection = firestore.collection('users');

        // 사용자의 UID를 기반으로 해당 사용자의 문서 가져오기
        DocumentReference userDocRef = usersCollection.doc(user.uid);

        try {
          // 사용자 문서가 있는지 확인
          DocumentSnapshot userSnapshot = await userDocRef.get();
          if (userSnapshot['user_group_id'] == '') {
            if (userSnapshot.exists) {
              // 문서가 있는 경우, 업데이트 수행
              await userDocRef.update({
                'user_group_id': groupId,
              });
              print('user_group_id가 업데이트되었습니다.');
            } else {
              // 문서가 없는 경우, 새로운 문서 생성
              await userDocRef.set({
                'user_group_id': groupId,
              });
              print('새로운 사용자 문서가 생성되었습니다.');
            }
          }
        } catch (error) {
          print('업데이트 중 오류 발생: $error');
        }

        print('가입성공');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const MainUiPage(), // MainUIPage()는 이동하고자 하는 페이지입니다.
          ),
        );

        // 업데이트된 group_users 배열을 그룹 문서에 저장
        await groupDocRef.update({'group_users': groupUsers});
      }
    }
  }

  void _showGroupNameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('그룹 이름 입력'),
          content: TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(labelText: '그룹 이름'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                String newGroupName = _groupNameController.text;
                _createGroup(context, newGroupName);
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
