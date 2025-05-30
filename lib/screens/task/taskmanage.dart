import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'taskmanagedialog.dart';
import 'package:intl/intl.dart';

class TaskManagePage extends StatefulWidget {
  const TaskManagePage({super.key});

  @override
  _TaskManagePageState createState() => _TaskManagePageState();
}

class _TaskManagePageState extends State<TaskManagePage> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  var currentUser = FirebaseAuth.instance.currentUser;
  Set<String> checkedUsers = {};
  late List<DocumentSnapshot> groups;
  late int userNamesLength;
  late String group_id;
  late QuerySnapshot groupSnapshot;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    fetchGroupUsers;
  }

  Future<void> fetchGroupUsers() async {
    groupSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('group_users', arrayContains: currentUser?.uid)
        .get();
    groups = groupSnapshot.docs;
    for (var group in groups) {
      List<dynamic> groupUsers = group['group_users'] as List<dynamic>;
      List<String> userNames = await _getUsersNames(groupUsers);
      // 체크박스 상태를 false로 초기화
      userNamesLength = userNames.length;
      group_id = group.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: firestore
            .collection('tasks')
            .where('managed_by', isEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          // 문서 리스트를 정렬 가능한 형태로 변환
          List<QueryDocumentSnapshot> tasks = snapshot.data!.docs;

          // 정렬 로직 적용
          tasks.sort((a, b) {
            // TaskState가 모두 2인 경우를 확인
            bool allCompletedA = (a['state'] as List).every((s) => s == 2);
            bool allCompletedB = (b['state'] as List).every((s) => s == 2);
            if (allCompletedA != allCompletedB) {
              return allCompletedA ? 1 : -1;
            }

            // 'finished_at' 필드의 날짜를 비교
            DateTime finished_atA = (a['finished_at'] as Timestamp).toDate();
            DateTime finished_atB = (b['finished_at'] as Timestamp).toDate();
            int finishedAtComparison = finished_atA.compareTo(finished_atB);
            if (finishedAtComparison != 0) {
              return finishedAtComparison;
            }

            // 'finished_at'이 같은 경우 'created_at'을 비교
            DateTime created_atA = (a['created_at'] as Timestamp).toDate();
            DateTime created_atB = (b['created_at'] as Timestamp).toDate();
            return created_atA.compareTo(created_atB);
          });

          return LayoutBuilder(builder: (context, constraints) {
            constraints.maxHeight;
            constraints.maxWidth;
            return ListView.separated(
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1.5,
                color: Color(0xffcccccc),
              ),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                // QueryDocumentSnapshot을 Map<String, dynamic>으로 변환
                var task = tasks[index].data() as Map<String, dynamic>;
                var task_id = tasks[index].id;
                // 여기서 ListTile 구성 로직을 구현
                List assigned_users = task['assigned_users'];
                List states = task['state'];
                // double unitWidth =
                //     (MediaQuery.of(context).size.width) / taskState.length * 0.88;
                int redNum = states.where((element) => element == 0).length;
                int yellowNum =
                    states.where((element) => element == 1).length;
                int greenNum =
                    states.where((element) => element == 2).length;
                DateTime finished_at = (task['finished_at'] as Timestamp).toDate();
                String formattedFinished = finished_at.compareTo(DateTime(
                            DateTime.now().year + 5, 12, 31, 23, 59)) ==
                        1
                    ? ''
                    : '~${DateFormat.MMMd().format(finished_at)}';

                return SizedBox(
                  height: 79,
                  child: ListTile(
                    title: Text(
                      task['task_name'],
                      style: TextStyle(
                          color: greenNum == states.length
                              ? Colors.grey
                              : Colors.black),
                      maxLines: 1, // 최대 표시 줄 수를 1로 설정
                      overflow:
                          TextOverflow.ellipsis, // 텍스트가 넘칠 경우 말줄임표(...)로 처리
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (formattedFinished != '')
                          Text(
                            formattedFinished,
                            style: TextStyle(
                                color: greenNum == states.length
                                    ? Colors.grey
                                    : Colors.black),
                          ),
                        if (formattedFinished == '')
                          SizedBox.fromSize(
                            size: const Size(0, 12),
                          ),
                        SizedBox.fromSize(
                          size: const Size(0, 3),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞춤
                          children: <Widget>[
                            Container(
                              height: 12.0,
                              // 높이 조정
                              width: (MediaQuery.of(context).size.width) /
                                  states.length *
                                  0.88 *
                                  redNum,
                              // 첫 번째 막대의 너비
                              color: const Color(0xffFF6868), // 색상 조정
                            ),
                            Container(
                              height: 12.0,
                              width: (MediaQuery.of(context).size.width) /
                                  states.length *
                                  0.88 *
                                  yellowNum,
                              // 두 번째 막대의 너비
                              color: const Color(0xffFDE767),
                            ),
                            Container(
                              height: 12.0,
                              width: (MediaQuery.of(context).size.width) /
                                  states.length *
                                  0.88 *
                                  greenNum,
                              // 세 번째 막대의 너비
                              color: greenNum == states.length
                                  ? Colors.grey
                                  : Colors.lightGreen,
                            ),
                          ],
                        ),
                        SizedBox.fromSize(
                          size: const Size(0, 2),
                        ),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return TaskManageDialog(task: task, taskId: task_id);
                        },
                      );
                    },

                    // 추가적인 UI 구성 요소 (예: 색점 표시 등)를 여기에 구현
                  ),
                );
              },
            );
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String taskName = '';
  String taskScript = '';
  DateTime defaultDate = DateTime(DateTime.now().year + 10, 12, 31, 23, 59);
  DateTime? finishedAt = DateTime(DateTime.now().year + 10, 12, 31, 23, 59);
  DateTime selectedDate = DateTime.now();
  bool ing = false;

  void _showAddTaskDialog() {
    ing = false;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('협업 업무 추가'),
          content: StatefulBuilder(
            // StatefulBuilder를 추가
            builder: (BuildContext context, StateSetter setState) {
              // 이 setState는 StatefulBuilder의 로컬 상태를 업데이트하기 위한 것입니다.
              return SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextField(
                      onChanged: (value) {
                        taskName = value;
                      },
                      decoration: const InputDecoration(hintText: '제목'),
                    ),
                    TextField(
                      onChanged: (value) {
                        taskScript = value;
                      },
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: '업무 설명'),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await selectDate(context);
                        setState(() {
                          // 여기서는 StatefulBuilder의 setState를 사용
                        });
                      },
                      child: Text(
                        finishedAt == defaultDate
                            ? '마감 기한'
                            : "${finishedAt!.year}-${finishedAt!.month.toString().padLeft(2, '0')}-${finishedAt!.day.toString().padLeft(2, '0')}",
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    if (ing == true)
                      Center(
                          child: SizedBox(
                              width: 32.5,
                              height: 32.5,
                              child: const CircularProgressIndicator()))
                    else
                      ElevatedButton(
                        onPressed: () {
                          if (ing == false) {
                            setState(() {
                              ing = true;
                            });
                            _showSelectUsersDialog()
                                .then((value) => setState(() {
                                      ing = false;
                                    }));
                          }
                        },
                        child: const Text('업무 수행자 선택'),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () async {
                if (ing == true) {
                } else {
                  ing = true;
                  Navigator.of(context).pop();
                  // await fetchGroupUsers();
                  taskName = '';
                  taskScript = '';
                  checkedUsers = {};
                  finishedAt = defaultDate;
                  selectedDate = DateTime.now();
                  try {
                    print(group_id);
                  } catch (e) {
                    await fetchGroupUsers();
                  }
                  // 체크박스 상태를 false로 초기화
                  groupCheckedStatus[group_id] =
                      List.generate(userNamesLength, (index) => false);
                  ing = false;
                }
              },
            ),
            TextButton(
              child: const Text('추가'),
              onPressed: () async {
                if (ing == true) {
                  null;
                } else {
                  ing = true;
                  if (taskName != '' && checkedUsers.isNotEmpty) {
                    var currentUser = FirebaseAuth.instance.currentUser;
                    var uid = currentUser?.uid;
                    int userNumber = checkedUsers.length;
                    List<int> userState = [];
                    List<bool> alertList = [];
                    for (int i = 0; i < userNumber; i++) {
                      userState.add(0);
                      alertList.add(false);
                    }

                    if (uid != null) {
                      FirebaseFirestore.instance.collection('tasks').add({
                        'task_name': taskName,
                        'task_script': taskScript,
                        'finished_at': finishedAt,
                        'created_at': DateTime.now(),
                        'assigned_users': checkedUsers,
                        'managed_by': currentUser?.uid,
                        'state': userState,
                        'alert': alertList
                      });
                    }
                    //Navigator.of(context).pop();
                    for (var group in groups) {
                      List<dynamic> groupUsers =
                          group['group_users'] as List<dynamic>;

                      //List<String> userNames = await _getUsersNames(groupUsers);
                      // 체크박스 상태를 false로 초기화
                      groupCheckedStatus[group.id] =
                          List.generate(groupUsers.length, (index) => false);
                    }
                    taskName = '';
                    taskScript = '';
                    checkedUsers = {};
                    finishedAt = defaultDate;
                    selectedDate = DateTime.now();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('제목과 업무 수행자는 필수입니다. $checkedUsers')));
                  }
                  ing = false;
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate, // 초기 날짜 설정
      firstDate: DateTime(2000), // 선택 가능한 가장 이른 날짜
      lastDate: DateTime(2100), // 선택 가능한 가장 늦은 날짜
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked; // 선택한 날짜로 상태 업데이트
        finishedAt = selectedDate.add(const Duration(hours: 23, minutes: 59));
      });
    }
  }

  Future<String> getUserNameByUid(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['user_name'] as String;
      } else {
        // 문서가 존재하지 않는 경우
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  void updateUserName(String user) async {
    String? userName = await getUserNameByUid(user);
    setState(() {
      name = userName;
    });
  }

  String name = '';
  Map<String, List<bool>> groupCheckedStatus = {}; // 각 그룹별 체크 상태

  Future<void> _showSelectUsersDialog() async {
    setState(() {
      ing = true;
    });

    User? userAuth = FirebaseAuth.instance.currentUser;
    final DocumentSnapshot userSnapshot =
        await firestore.collection('users').doc(userAuth?.uid).get();

    if (userSnapshot.exists) {
      final String userId = userSnapshot.id;

      try {
        print(group_id);
      } catch (e) {
        // 모든 그룹의 group_users 가져오기
        groupSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .where('group_users', arrayContains: userId)
            .get();
        groups = groupSnapshot.docs;
      }


      // 모든 그룹의 사용자 이름 가져오기
      Map<String, List<String>> groupUserNames = {};
      for (var group in groups) {
        List<dynamic> groupUsers = group['group_users'] as List<dynamic>;
        List<String> userNames = await _getUsersNames(groupUsers);
        groupUserNames[group.id] = userNames;
        //groupCheckedStatus[group.id] = List.generate(userNames.length, (index) => false);
      }

      // 다이얼로그 표시
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
                    String group_id = group.id;
                    List<String> userNames = groupUserNames[group_id] ?? [];
                    List<bool> isCheckedList = groupCheckedStatus.putIfAbsent(
                        group_id,
                        () =>
                            List.generate(userNames.length, (index) => false));


                    // userGroup의 값에 따라 체크박스를 체크하면 해당 그룹에 속한 모든 사용자들의 체크박스가 체크되도록 수정
                    return  Column(
                      children: [
                        ListTile(
                          title: Text(group['group_name']),
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
                                    groupCheckedStatus[group_id] = isCheckedList;

                                    if (value == true) {
                                      checkedUsers.add(userUid);
                                    } else {
                                      checkedUsers.remove(userUid);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 100,)
                      ],
                    );
                  },
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Icon(Icons.check_circle_outline),
                ),
              );
            });
          }).then((value) => setState(() {
            ing = false; // 필요한 경우 여기에서 추가 상태 업데이트를 수행할 수 있습니다.
          }));
      // setState(() {
      //   //ing=false;// 필요한 경우 여기에서 추가 상태 업데이트를 수행할 수 있습니다.
      // });
    }
  }

// _getUsersNames 함수와 나머지 필요한 코드...

  // 사용자 이름을 조회하는 함수
  Future<List<String>> _getUsersNames(List<dynamic> userUids) async {
    List<String> names = [];

    for (var uid in userUids) {
      var userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      names.add(userDoc.data()?['user_name'] ?? 'Unknown');
    }

    return names;
  }
}
