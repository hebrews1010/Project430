import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fourthirty/providers/users_provider.dart';
import 'package:provider/provider.dart';


class GroupsProvider with ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  GroupsProvider(this._auth, this._firestore);

  DocumentSnapshot? userSnapshot;
  String? groupId;
  DocumentReference? groupDocRef;
  DocumentSnapshot? groupSnapshot;
  List<dynamic>? groupUsers;


  Future<DocumentSnapshot> fetchGroupSnapshot() async {
    if (!groupSnapshot!.exists) {
      groupDocRef = _firestore.collection('groups').doc(groupId);
      return await groupDocRef!.get();
    }
    {
      return groupSnapshot!;
    }
  }

  Future<DocumentSnapshot> updateGroupSnapshot() async {
    groupDocRef = _firestore.collection('groups').doc(groupId);
    groupSnapshot = await groupDocRef!.get();
    return groupSnapshot!;
  }

  Future<String> fetchUserGroupId() async {
    if(groupId != null) {
      return groupId!;
    }else if(userSnapshot != null && userSnapshot!.exists) {
      groupId = userSnapshot!['user_group_id'] ?? '';
      return groupId!;
    } else {
      User? user = _auth.currentUser;
      if (user != null) {
        CollectionReference usersCollection = _firestore.collection('users');
        DocumentReference userDocRef = usersCollection.doc(user.uid);
        userSnapshot = await userDocRef.get();
        groupId = userSnapshot!['user_group_id'] ?? '';
        return groupId!;
      }
      return '';
    }
  }

  Future<void> fetchGroupUsers() async {
    if (!groupSnapshot!.exists) {
      fetchGroupSnapshot();
    } else {
      groupUsers = groupSnapshot!['group_users'] ?? [];
    }
  }


  void createGroup(BuildContext context, String groupName) async {
    CollectionReference groups = _firestore.collection('groups');
    User? user = _auth.currentUser;
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
      CollectionReference usersCollection = _firestore.collection('users');

      // 사용자의 UID를 기반으로 해당 사용자의 문서 가져오기
      DocumentReference userDocRef = usersCollection.doc(user.uid);

      try {
        // 사용자 문서가 있는지 확인
        userSnapshot = await userDocRef.get();
        if (userSnapshot!.exists) {
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
    //만료된 위젯 트리를 참조해서 페이지 이동이 안될 경우 퓨처 함수로 이동을 따로 구현하고 그 함수를 쓰면 됨
  }


  Future<void> groupAssign(String groupId) async {
    // 현재 사용자의 UID 가져오기
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }


    // 그룹 문서 가져오기
    groupSnapshot = await fetchGroupSnapshot();

    if (groupSnapshot!.exists) {
      // 그룹 문서가 존재하는 경우
      groupUsers = groupSnapshot!['group_users'] ?? [];

      if (!groupUsers!.contains(user.uid)) {
        // 현재 사용자의 UID가 그룹에 추가되어 있지 않으면 추가
        groupUsers!.add(user.uid);


        CollectionReference usersCollection = _firestore.collection('users');

        // 사용자의 UID를 기반으로 해당 사용자의 문서 가져오기
        DocumentReference userDocRef = usersCollection.doc(user.uid);


        try {
          // 사용자 문서가 있는지 확인
          userSnapshot = await userDocRef.get();
          if (userSnapshot!['user_group_id'] == '') {
            if (userSnapshot!.exists) {
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

        // 업데이트된 group_users 배열을 그룹 문서에 저장
        if (groupDocRef!.id == '') {
          groupDocRef = _firestore.collection('groups').doc(groupId);
        }
        await groupDocRef!.update({'group_users': groupUsers});
      }
    }
  }

}