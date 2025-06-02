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
    _fetchUserGroupId();
    futureGroupUsers = _fetchGroupUsers(); // 초기화
  }

  void refreshData() {
    setState(() {
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
    String? currentUid = currentUser?.uid;

    if (currentUid == null) {
      // 로그인되지 않은 경우 빈 리스트 반환
      print("User not logged in. Cannot fetch group users.");
      return [];
    }

    try {
      QuerySnapshot groupSnapshot = await firestore
          .collection('groups')
          .where('group_users', arrayContains: currentUid)
          .get();

      // group_manager_id는 첫 번째 찾은 그룹에서 가져옴 (그룹이 여러 개일 경우 로직 변경 필요)
      if (groupSnapshot.docs.isNotEmpty) {
        group_manager_id = groupSnapshot.docs.first['group_manager'];
      }


      for (var groupDoc in groupSnapshot.docs) {
        List<dynamic> userIds = groupDoc['group_users'];
        // group_manager_id는 _fetchUserGroupId에서 이미 설정될 수도 있으나, 여기서는 그룹 문서에서 직접 가져옴
        // group_manager_id = groupDoc['group_manager']; // 위에 이미 처리했으므로 주석 처리

        for (var userId in userIds) {
          DocumentSnapshot userDoc =
          await firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            groupUsers.add({
              'uid': userId,
              'user_name': userDoc['user_name'],
              //'user_div': userDoc['user_div'] 메신저처럼 학년별 종류별 일괄로 다룰수 있게.. 나중에 구현
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching group users: $e');
      // 오류를 FutureBuilder로 전달하기 위해 rethrow
      rethrow;
    }

    return groupUsers;
  }

  Future<Map<String, int>> _fetchTaskCounts(String user_id) async {
    Map<String, int> taskCounts = {'0': 0, '1': 0, '2': 0};

    try {
      QuerySnapshot taskSnapshot = await firestore
          .collection('tasks')
          .where('assigned_users', arrayContains: user_id)
          .get();

      for (var taskDoc in taskSnapshot.docs) {
        if (taskDoc['managed_by'] != null && taskDoc['managed_by'] != '') { // null 체크 추가
          List<dynamic> states = taskDoc['state'];
          int userIndex = (taskDoc['assigned_users'] as List).indexOf(user_id);

          if (userIndex != -1 && userIndex < states.length) {
            String state = states[userIndex].toString();
            taskCounts[state] = (taskCounts[state] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      print('Error fetching task counts for $user_id: $e');
      // 오류를 FutureBuilder로 전달하기 위해 rethrow
      rethrow;
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
                    user['user_div'] = divName;
                  });

                  divName ??= ''; // null이면 빈 문자열로
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // 인덱스 오류를 포함한 모든 오류를 여기에 표시
            String errorMessage = "데이터를 불러오는 중 오류가 발생했습니다: \n${snapshot.error.toString()}";
            if (snapshot.error.toString().contains('The query requires an index')) {
              errorMessage += "\n\nFirestore 콘솔에서 인덱스를 생성해야 합니다. 디버그 콘솔의 링크를 확인하세요.";
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('그룹 사용자를 찾을 수 없습니다.'));
          }

          List<Map<String, dynamic>> users = snapshot.data!;

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
                      : const SizedBox(width: 25), // 관리자 아이콘 없으면 빈 공간
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
                          refreshData());
                    } else {
                      NotManagerDialog(context); // return 대신 바로 호출
                    }
                  },
                  onLongPress: (){DivSettingDialog(context, user);},
                  title: Row(
                    children: [
                      Text(user['user_name']),
                      const SizedBox(width: 10),
                      Text(
                        user['user_div'] ?? '', // user_div가 null일 경우 대비
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                        textAlign: TextAlign.left,
                      )
                    ],
                  ),
                  subtitle: FutureBuilder<Map<String, int>>(
                    future: _fetchTaskCounts(user['uid']),
                    builder: (context, taskSnapshot) {
                      if (taskSnapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator(); // 작업 로딩 중
                      } else if (taskSnapshot.hasError) {
                        // Task Count 오류도 여기서 표시
                        String taskErrorMessage = "할 일 카운트 오류: \n${taskSnapshot.error.toString()}";
                        if (taskSnapshot.error.toString().contains('The query requires an index')) {
                          taskErrorMessage += "\n\nTask 관련 인덱스 생성 필요!";
                        }
                        return Text(
                          taskErrorMessage,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        );
                      }
                      Map<String, int> taskCounts = taskSnapshot.data ?? {};
                      return Text(
                          '시작 전: ${taskCounts['0'] ?? 0}, 진행중: ${taskCounts['1'] ?? 0}, 완료: ${taskCounts['2'] ?? 0}');
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