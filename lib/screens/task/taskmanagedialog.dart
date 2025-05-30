import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourthirty/screens/bulletin/post_detail_page.dart';
import 'package:fourthirty/screens/bulletin/createpostpage.dart';

class TaskManageDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final String taskId;

  const TaskManageDialog({super.key, required this.task, required this.taskId});

  @override
  _TaskManageDialogState createState() => _TaskManageDialogState();
}

class _TaskManageDialogState extends State<TaskManageDialog> {
  late DateTime finishedAt;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  var currentUser = FirebaseAuth.instance.currentUser;
  Set<String> checkedUsers = {};
  Map<String, List<bool>> groupCheckedStatus = {};
  Map<String, dynamic>? relatedPostData;
  String relatedPostId = '';
  String? taskId;
  late QuerySnapshot groupSnapshot;
  late Map<String, dynamic> task = widget.task;
  bool ing = false;
  bool ing2 =false;

  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskScriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    finishedAt = (widget.task['finished_at'] as Timestamp).toDate();
    _taskNameController.text = widget.task['task_name'];
    _taskScriptController.text = widget.task['task_script'];
    _fetchRelatedPost();
    _loadGroupSnapshot();
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _taskScriptController.dispose();
    super.dispose();
  }

  void setAssignedUsers(
      List<String> users, List<dynamic> newStates, List<dynamic> newAlerts) {
    setState(() {
      task['assigned_users'] = users;
      task['alert'] = newAlerts;
      task['state'] = newStates;
    });
  }

  Future<void> _loadGroupSnapshot() async {
    User? userAuth = FirebaseAuth.instance.currentUser;
    final DocumentSnapshot userSnapshot =
        await firestore.collection('users').doc(userAuth?.uid).get();

    if (userSnapshot.exists) {
      final String userId = userSnapshot.id;

      // 모든 그룹의 group_users 가져오기
      groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('group_users', arrayContains: userId)
          .get();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: finishedAt.compareTo(
                  DateTime(DateTime.now().year + 5, 12, 31, 23, 59)) ==
              -1
          ? finishedAt
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != finishedAt) {
      setState(() {
        finishedAt = picked.add(const Duration(hours: 23, minutes: 59));
        FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.taskId)
            .update({'finished_at': finishedAt});
      });
    }
  }

  void _deleteTask(BuildContext context) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('정말로 지우시겠습니까? 삭제된 데이터는 복구되지 않습니다.'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () {
                // Delete the task from Firestore
                FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.taskId)
                    .delete();
                Navigator.of(context).pop(); // Close the confirmation dialog
                Navigator.of(context).pop(); // Close the TaskManageDialog
              },
            ),
          ],
        );
      },
    );
  }

  void _showSelectUsersDialog() {
    List<DocumentSnapshot> groups = groupSnapshot.docs;

    // 다이얼로그 표시
    getGroupUsers(groups).then(
      (groupUserNames) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return Scaffold(
                    body: ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        DocumentSnapshot group = groups[index];
                        String groupId = group.id;
                        List<dynamic> groupUsers =
                            group['group_users'] as List<dynamic>;

                        List<String> userNames = groupUserNames[groupId] ?? [];

                        List<bool> isCheckedList =
                            groupCheckedStatus.putIfAbsent(
                                groupId,
                                () => List.generate(
                                    userNames.length, (index) => false));
                        if (!isCheckedList.contains(true)) {
                          for (String assiUsers
                              in widget.task['assigned_users']) {
                            int index = groupUsers.indexOf(assiUsers);
                            isCheckedList[index] = true;
                            checkedUsers.add(assiUsers);
                          }
                        }
                        return ListTile(
                          title: Text('${widget.task['task_name']}' '\n\n' +
                              group['group_name']),
                          subtitle: Column(
                            children: userNames.asMap().entries.map((entry) {
                              int idx = entry.key;
                              String userName = entry.value;
                              String userUid = group['group_users'][idx];

                              return CheckboxListTile(
                                title: Text(userName),
                                value: isCheckedList[idx],
                                onChanged: (bool? value) {
                                  setState(() {
                                    isCheckedList[idx] = !isCheckedList[idx];
                                    value = isCheckedList[idx];
                                    groupCheckedStatus[groupId] = isCheckedList;

                                    if (value == true) {
                                      checkedUsers.add(userUid);
                                    } else {
                                      checkedUsers.remove(userUid);
                                    }
                                    // print(isCheckedList[idx]);
                                    // print(groupCheckedStatus);
                                    // print(value);
                                    // print(checkedUsers);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    floatingActionButton: FloatingActionButton(
                      child: const Icon(Icons.check_circle_outline),
                      onPressed: () {
                        if (ing2 == true) {
                          null;
                        } if (ing2 == false) {
                          ing2 = true;
                        if (checkedUsers.isNotEmpty) {
                          var currentUser = FirebaseAuth.instance.currentUser;
                          var uid = currentUser?.uid;
                          List assign = widget.task['assigned_users'];
                          List states = widget.task['state'];
                          List alerts = widget.task['alert'];
                          Map<dynamic, dynamic> userStates = {};
                          for (int i = 0; i < assign.length; i++) {
                            var map = {assign[i]: states[i]};
                            userStates.addAll(map);
                          }
                          List newStates = [];
                          for (String user in checkedUsers) {
                            if (!assign.contains(user)) {
                              newStates.add(0);
                            } else {
                              newStates.add(userStates[user]);
                            }
                          }
                          //alerts
                          Map<dynamic, dynamic> userAlerts = {};
                          for (int i = 0; i < assign.length; i++) {
                            var map = {assign[i]: alerts[i]};
                            userAlerts.addAll(map);
                          }
                          List newAlerts = [];
                          for (String user in checkedUsers) {
                            if (!assign.contains(user)) {
                              newAlerts.add(false);
                            } else {
                              newAlerts.add(userAlerts[user]);
                            }
                          }

                          if (uid != null) {
                            FirebaseFirestore.instance
                                .collection('tasks')
                                .doc(widget.taskId)
                                .update({
                              'assigned_users': checkedUsers.toList(),
                              'state': newStates,
                              'alert': newAlerts
                            }).then((_) {
                              setAssignedUsers(
                                  checkedUsers.toList(), newStates, newAlerts);
                              Navigator.of(context).pop(); // 다이얼로그 닫기
                            });
                          }
                        }
                    ing2 = false;
                    }
                      },
                    ));
              });
            }).then((value) => setState(() {
              ing = false;
            }));
      },
    );
  }

  Future<void> _fetchRelatedPost() async {
    var postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('related_task_id', isEqualTo: widget.taskId)
        .limit(1) // Fetch only one post
        .get();

    if (postSnapshot.docs.isNotEmpty) {
      var post = postSnapshot.docs.first;
      setState(() {
        relatedPostData = post.data();
        relatedPostId = post.id;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    List<dynamic> assignedUsers = task['assigned_users'];
    List<dynamic> states = task['state'];
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    Future<List<Widget>> fetchAssignedUsersData() async {
      List<Map<String, dynamic>> userData = [];

      for (int i = 0; i < assignedUsers.length; i++) {
        String userId = assignedUsers[i];
        String userName = '';
        int state = states[i];
        //String pushToken = '';

        await firestore.collection('users').doc(userId).get().then((userDoc) {
          if (userDoc.exists) {
            userName = userDoc.data()?['user_name'] ?? '';
            //pushToken = userDoc.data()?['push_token'] ?? '';
          }
        });

        userData.add({
          'userId': userId,
          'userName': userName,
          'state': state,
          //'push_token': pushToken,
        });
      }

      // userData를 'state' 값에 따라 정렬
      userData.sort((a, b) => a['state'].compareTo(b['state']));

      // 정렬된 userData를 사용하여 ListTile 생성
      List<Widget> userTiles = userData.map((user) {
        Color? taskColor;
        String stateName;

        switch (user['state']) {
          case 0:
            stateName = '시작 전';
            taskColor = const Color(0xffFF6868);
            break;
          case 1:
            stateName = '진행중';
            taskColor = const Color(0xffFDE767);
            break;
          case 2:
            stateName = '완료';
            taskColor = Colors.lightGreen;
            break;
          default:
            stateName = '알 수 없음';
            taskColor = Colors.black;
            break;
        }

        List assignedUsers = task['assigned_users'] as List<dynamic>;
        List alertList = task['alert'];

        return ListTile(
          title: Text('이름: ${user['userName']}'),
          subtitle: Text('상태: $stateName'),
          leading: Icon(Icons.circle, color: taskColor, size: 20),
          trailing: IconButton(
            icon: Icon(Icons.notifications,
                color: alertList[assignedUsers.indexOf(user['userId'])]
                    ? const Color(0xffFF5858)
                    : const Color(0xff000000)),
            onPressed: () {
              //푸시 알림은 애플 개발자 등록해야 api 키 받아서 이용 가능
              int userIndex = assignedUsers.indexOf(user['userId']);
              alertList[userIndex] = !alertList[userIndex];
              FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(widget.taskId)
                  .update({'alert': alertList});

              setState(() {});
            },
          ),
        );
      }).toList();

      return userTiles;
    }

    String formattedFinished = finishedAt
                .compareTo(DateTime(DateTime.now().year + 5, 12, 31, 23, 59)) ==
            1
        ? '미정'
        : DateFormat.yMMMd().format(finishedAt); // 시간 생략
    taskId = widget.taskId;
    int nameLine;
    if (_taskNameController.text.length >= 16) {
      nameLine = 2;
    } else {
      nameLine = 1;
    }

    return GestureDetector(
      onTap: () {
        // 현재 포커스를 가진 위젯을 해제하여 키보드를 숨깁니다.
        FocusScope.of(context).unfocus();
      },
      child: AlertDialog(
        title: TextField(
          controller: _taskNameController,
          decoration: const InputDecoration(labelText: '제목'),
          maxLines: nameLine,
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              TextField(
                controller: _taskScriptController,
                decoration: const InputDecoration(labelText: '설명'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Text('마감 기한: $formattedFinished'),
              TextButton(
                onPressed: relatedPostId.isNotEmpty
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PostDetailPage(
                              post: relatedPostData!,
                              documentId: relatedPostId,
                            ),
                          ),
                        )
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                CreatePostPage(related: taskId),
                          ),
                        ),
                child: Text(
                  relatedPostId.isNotEmpty
                      ? relatedPostData!['title']
                      : '새 포스트 작성',
                ),
              ),
              ElevatedButton(
                onPressed: () => _selectDate(context),
                child: const Text('마감 기한 변경'),
              ),

              // Assigned users and states
              FutureBuilder(
                future: fetchAssignedUsersData(), //여기를 함수로 할지 변수로 할지는 선택임
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: ((snapshot.data?.length ?? 1) * 72.0),
                      child: const Center(
                        child: SizedBox(
                          height:
                              24.0, // CircularProgressIndicator의 크기를 24x24로 설정
                          width: 24.0, // 높이와 너비를 같게 하여 완벽한 원형 유지
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0, // 동그라미의 선 두께를 설정// 색깔 설정
                          ),
                        ),
                      ),
                    ); // 데이터 로딩 중이면 로딩 표시
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    // 데이터 로딩이 완료되면 리스트뷰 표시
                    List<Widget> userTiles = snapshot.data ?? [];

                    return Column(
                      children: userTiles,
                    );
                  }
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (ing == true) {
                    print('no');
                    null;
                  } else {
                    ing = true;
                    FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(widget.taskId)
                        .update({
                      'task_name': _taskNameController.text,
                      'task_script': _taskScriptController.text,
                    });
                    _showSelectUsersDialog();
                    // Navigator.of(context).pop();
                  }
                },
                child: const Text('업무 수행자 변경'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('업무 삭제'),
            onPressed: () => _deleteTask(context),
          ),
          ElevatedButton(
            child: const Text('확인'),
            onPressed: () {
              if (ing == true){null;}else{
                ing=true;
                nameLine = 1;
                FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.taskId)
                    .update({
                  'task_name': _taskNameController.text,
                  'task_script': _taskScriptController.text,
                  // 'finished_at' 업데이트는 선택 사항
                }).then((_) {
                  ing=false;
                  Navigator.of(context).pop(); // 편집 대화상자 닫기
                  // 필요한 경우 상태 업데이트
                });}
            },
          )
        ],
      ),
    );
  }
}

Future<Map<String, List<String>>> getGroupUsers(
    List<DocumentSnapshot> groups) async {
  Map<String, List<String>> groupUserNames = {};
  for (var group in groups) {
    List<dynamic> groupUsers = group['group_users'] as List<dynamic>;
    List<String> userNames = await _getUsersNames(groupUsers);
    groupUserNames[group.id] = userNames;
  }
  return groupUserNames;
}

Future<List<String>> _getUsersNames(List<dynamic> userUids) async {
  List<String> names = [];

  for (var uid in userUids) {
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    names.add(userDoc.data()?['user_name'] ?? 'Unknown');
  }

  return names;
}
