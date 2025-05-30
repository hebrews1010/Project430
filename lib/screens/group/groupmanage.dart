import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'groupmanagedialog.dart';
import 'package:flutter/services.dart';

class GroupManagePage extends StatefulWidget {
  const GroupManagePage({super.key});

  @override
  _GroupManagePageState createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late String user_group_id;
  String group_manager_id = '';
  Future<List<Map<String, dynamic>>>? futureGroupUsers;
  final TextEditingController divNameController= TextEditingController();

  @override
  void initState() {
    super.initState();
    futureGroupUsers = _fetchGroupUsers(); // 초기화

    _fetchUserGroupId();
  }

  void refreshData() {
    setState(() {
      // 데이터를 새로고침하는 로직
      // 예: _fetchGroupUsers()를 다시 호출하여 사용자 목록을 업데이트
      futureGroupUsers = _fetchGroupUsers(); // 데이터 갱신
    });
  }

  void _fetchUserGroupId() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc =
          await firestore.collection('users').doc(currentUser?.uid).get();
      if (userDoc.exists) {
        setState(() {
          user_group_id = userDoc['user_group_id'];
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupUsers() async {
    List<Map<String, dynamic>> groupUsers = [];

    QuerySnapshot groupSnapshot = await firestore
        .collection('groups')
        .where('group_users', arrayContains: currentUser?.uid)
        .get();

    for (var groupDoc in groupSnapshot.docs) {
      List<dynamic> userIds = groupDoc['group_users'];
      group_manager_id = groupDoc['group_manager'];

      for (var userId in userIds) {
        DocumentSnapshot userDoc =
            await firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          groupUsers.add({
            'uid': userId,
            'user_name': userDoc['user_name'],
            'user_div': userDoc['user_div']
          });
        }
      }
    }

    return groupUsers;
  }

  Future<Map<String, int>> _fetchTaskCounts(String user_id) async {
    Map<String, int> taskCounts = {'0': 0, '1': 0, '2': 0};

    QuerySnapshot taskSnapshot = await firestore
        .collection('tasks')
        .where('assigned_users', arrayContains: user_id)
        .get();

    for (var taskDoc in taskSnapshot.docs) {if(taskDoc['managed_by']!=''){
      List<dynamic> states = taskDoc['state'];
      int userIndex = (taskDoc['assigned_users'] as List).indexOf(user_id);

      if (userIndex != -1 && userIndex < states.length) {
        String state = states[userIndex].toString();
        taskCounts[state] = (taskCounts[state] ?? 0) + 1;
      }}
    }

    return taskCounts;
  }

  void NotManagerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('경고'),
          content: const Text('관리자가 아닙니다'),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
            ),
          ],
        );
      },
    );
  }
  void DivSettingDialog(BuildContext context, Map user) {
    String? divName;
    divNameController.text = user['user_div'];
    showDialog(

        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(user['user_name']),
            content: TextField(
              controller: divNameController,
              onChanged: (String? newValue) {
                divName = newValue;
              },
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text('확인'),
                onPressed: () {
                  setState(() {
                    user['user_div'] =divName;
                  });

                  divName ??= '';
                    firestore
                        .collection('users')
                        .doc(user['uid'])
                        .update({'user_div': divName});
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureGroupUsers,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator() ,);
          List<Map<String, dynamic>> users = snapshot.data ?? [];

          return ListView.builder(
            itemCount: users.length + 1, // +1 for user group ID at the top
            itemBuilder: (context, index) {
              if (index == 0) {
                // User group ID at the top
                return ListTile(
                  title: SelectableText('그룹 코드: $user_group_id'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user_group_id));
                      // 필요하다면 사용자에게 복사되었다는 피드백을 제공할 수 있습니다.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('그룹 코드가 복사되었습니다.')),
                      );
                    },
                  ),
                );
              } else {
                // User info
                Map<String, dynamic> user = users[index - 1];
                return ListTile(
                  trailing: user['uid'] == group_manager_id
                      ? const Icon(
                          Icons.account_box,
                          size: 25,
                        )
                      : SizedBox(width: 25,),
                  //여기 usergroupid 말고 그룹 매니저 id 와야됨
                  onTap: () {
                    if (currentUser?.uid == group_manager_id) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return GroupManageDialog(
                            groupId: user_group_id,
                            user_id: user['uid'],
                            user_name: user['user_name'],
                          );
                        },
                      ).then((_) =>
                          refreshData()); // Dialog 닫힐 때 refreshData 콜백 호출
                      print(currentUser?.uid);
                      print(group_manager_id);
                    } else {
                      return NotManagerDialog(context);
                    }
                  },
                  onLongPress: (){DivSettingDialog(context, user);},
                  title: Row(
                    children: [
                      Text(user['user_name']),
                      SizedBox(width: 10,),
                      Text(user['user_div'],style: TextStyle(color: Colors.grey,fontSize: 10,),textAlign: TextAlign.left,)
                    ],
                  ),
                  subtitle: FutureBuilder<Map<String, int>>(
                    future: _fetchTaskCounts(user['uid']),
                    builder: (context, taskSnapshot) {
                      if (!taskSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      Map<String, int> taskCounts = taskSnapshot.data ?? {};
                      return Text(
                          '시작 전: ${taskCounts['0']}, 진행중: ${taskCounts['1']}, 완료: ${taskCounts['2']}');
                    },
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
