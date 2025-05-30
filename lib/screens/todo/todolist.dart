import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourthirty/screens/bulletin/post_detail_page.dart';
import 'package:intl/intl.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  var currentUser = FirebaseAuth.instance.currentUser;
  bool ing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('assigned_users', arrayContains: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          List<DocumentSnapshot> tasks = snapshot.data?.docs ?? [];

          // 'state' 값과 'finished_at' 날짜에 따라 문서들을 정렬
          // 'state' 필드를 사용하여 tasks를 정렬하는 부분
          tasks.sort((a, b) {
            List iList = a['assigned_users'];
            List jList = b['assigned_users'];
            int i = iList.indexOf(currentUser?.uid);
            int j = jList.indexOf(currentUser?.uid);
            int stateA = a['state'][i]; // 'state' 배열에서 i번째 데이터를 가져옴
            int stateB = b['state'][j]; // 'state' 배열에서 i번째 데이터를 가져옴
            DateTime finishedAtA = (a['finished_at'] as Timestamp).toDate();
            DateTime finishedAtB = (b['finished_at'] as Timestamp).toDate();
            DateTime createdAtA = (a['created_at'] as Timestamp).toDate();
            DateTime createdAtB = (b['created_at'] as Timestamp).toDate();
            int compareState = stateA.compareTo(stateB);
            // alert 상태가 true인 항목을 먼저 정렬
            bool alertA = a['alert'][i];
            bool alertB = b['alert'][j];
            if (alertA && !alertB) return -1;
            if (!alertA && alertB) return 1;
            int compareFinishedAt = finishedAtA.compareTo(finishedAtB);

            if (stateA != 2 && stateB != 2) {
              // 둘 다 'state'가 2가 아닌 경우
              // 'finished_at' 날짜가 오늘과 가까운 순으로 정렬
              if (compareFinishedAt != 0) {
                return compareFinishedAt;
              } else {
                // 'finished_at'이 같을 경우 'created_at'으로 정렬
                int compareCreatedAt = createdAtA.compareTo(createdAtB);
                if (compareCreatedAt != 0) {
                  return compareCreatedAt;
                } else {
                  return compareState;
                }
              }
            } else {
              return compareState;
            }
          });

          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1.5,
              color: Color(0xffcccccc),
            ),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              var task = tasks[index];
              var taskId = task.id;
              var assignedUsers = task['assigned_users'] as List<dynamic>;
              var stateList = task['state'] as List<dynamic>;
              var alertList = task['alert'] as List<dynamic>;
              DateTime finishedAt = (task['finished_at'] as Timestamp).toDate();
              String formattedFinished = finishedAt.compareTo(
                          DateTime(DateTime.now().year + 5, 12, 31, 23, 59)) ==
                      1
                  ? ''
                  : '~${DateFormat.MMMd().format(finishedAt)}'; // 시간 생략

              // 현재 사용자의 uid와 일치하는 인덱스 찾기
              int userIndex = assignedUsers.indexOf(currentUser?.uid);
              int? selectedState =
                  userIndex != -1 ? stateList[userIndex] : null;
              Map<int, String> stateOptions = {0: '시작 전', 1: '진행중', 2: '완료'};
              bool isAlert = alertList[userIndex];

              // 'state'가 2인 경우 텍스트 색상을 회색으로 설정
              TextStyle textStyle = TextStyle(
                color: selectedState == 2 ? Colors.grey : Colors.black,
              );
              String taskName = task['task_name'];
              if (task['managed_by'] != '') {
                taskName = '#$taskName';
              }

              return Dismissible(
                  key: Key(taskId),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) {
                    return showDeleteConfirmationDialog(context, taskId, task);
                  },
                  child: ListTile(
                    title: Text(taskName, style: textStyle),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (formattedFinished != '')
                          Text(formattedFinished,
                              style: TextStyle(
                                  color: selectedState == 2
                                      ? Colors.grey
                                      : Colors.black,
                                  fontSize: 10)),
                        if (task['task_script'] != '')
                          Text(task['task_script'], style: textStyle),
                        if (formattedFinished == '' &&
                            task['task_script'] == '')
                          const SizedBox(
                            height: 9,
                          )
                      ],
                    ),
                    tileColor: isAlert ? Colors.redAccent : Colors.white,
                    // 색상 변경
                    onLongPress: () {
                      if (task['managed_by'] == '') {
                        showEditTaskDialog(task);
                        //개인업무 수정 다이어로그
                      } else {
                        if (isAlert) {
                          updateAlertStatus(
                              taskId, userIndex, false); // alert 상태 업데이트
                        }
                      }
                    },
                    onTap: () async {
                      if (ing == true) {
                        null;
                      } else {
                        ing = true;
                        var querySnapshot = await FirebaseFirestore.instance
                            .collection('posts')
                            .where('related_task_id', isEqualTo: taskId)
                            .get();
                        if (querySnapshot.docs.isNotEmpty) {
                          var postDoc = querySnapshot.docs.first;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                post: postDoc.data(),
                                documentId: postDoc.id,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('관련 포스트를 찾을 수 없습니다')),
                          );
                        }
                        ing = false;
                      }
                    },
                    trailing: DropdownButton<int>(
                      value: selectedState,
                      style: TextStyle(
                          color:
                              selectedState == 2 ? Colors.grey : Colors.black),
                      // 색상 설정
                      items: stateOptions.entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (int? select) {
                        setState(() {
                          if (userIndex != -1) {
                            stateList[userIndex] = select;
                            FirebaseFirestore.instance
                                .collection('tasks')
                                .doc(task.id)
                                .update({'state': stateList});
                          }
                        });
                      },
                    ),
                  ));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void showEditTaskDialog(DocumentSnapshot task) {
    String currentTaskName = task['task_name'];
    String currentTaskScript = task['task_script'];
    DateTime currentFinishedAt = (task['finished_at'] as Timestamp).toDate();

    TextEditingController taskNameController =
        TextEditingController(text: currentTaskName);
    TextEditingController taskScriptController =
        TextEditingController(text: currentTaskScript);

    // 다이얼로그 내에서 finishedAt 날짜를 업데이트하기 위한 콜백
    void updateFinishedAtDate(DateTime newDate) {
      setState(() {
        currentFinishedAt = newDate;
      });
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // StatefulBuilder를 사용하여 다이얼로그의 상태를 업데이트합니다.
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('업무 수정'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    TextField(
                      controller: taskNameController,
                      decoration: const InputDecoration(labelText: '업무 이름'),
                    ),
                    TextField(
                      controller: taskScriptController,
                      decoration: const InputDecoration(labelText: '설명'),
                      maxLines: 3,
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          selectNewDate(context, currentFinishedAt, (newDate) {
                        // selectNewDate 함수에서 콜백으로 전달된 새 날짜로 상태 업데이트
                        setState(() {
                          currentFinishedAt = newDate;
                        });
                      }),
                      child: Text(
                        currentFinishedAt.compareTo(DateTime(
                                    DateTime.now().year + 5, 12, 31, 23, 59)) ==
                                1
                            ? '미정'
                            : DateFormat.yMMMd().format(currentFinishedAt),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('저장'),
                  onPressed: () {
                    if (ing == true) {
                      null;
                    } else {
                      ing = true;
                      FirebaseFirestore.instance
                          .collection('tasks')
                          .doc(task.id)
                          .update({
                        'task_name': taskNameController.text,
                        'task_script': taskScriptController.text,
                        'finished_at': currentFinishedAt,
                      }).then((_) {
                        ing=false;
                        Navigator.of(context).pop(); // 다이얼로그 닫기

                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> selectNewDate(BuildContext context, DateTime currentFinishedAt,
      Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentFinishedAt.compareTo(
                  DateTime(DateTime.now().year + 5, 12, 31, 23, 59)) ==
              -1
          ? currentFinishedAt
          : DateTime.now(), // 현재 finishedAt을 초기 날짜로 사용합니다.
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != currentFinishedAt) {
      // 새 날짜가 선택되면, 콜백을 사용하여 다이얼로그 상태를 업데이트합니다.
      onDateSelected(picked.add(const Duration(hours: 23, minutes: 59)));
    }
  }

  void updateAlertStatus(String taskId, int userIndex, bool newStatus) {
    var taskDocRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    taskDocRef.get().then((taskDoc) {
      if (taskDoc.exists) {
        List<dynamic> alertList = List.from(taskDoc['alert']);
        alertList[userIndex] = newStatus;

        taskDocRef.update({'alert': alertList}).then((_) {
          setState(() {}); // 화면 새로 고침
        });
      }
    });
  }

  Future<bool?> showDeleteConfirmationDialog(
      BuildContext context, String taskId, DocumentSnapshot task) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 업무를 삭제하시겠습니까?'),
        actions: <Widget>[
          TextButton(
            child: const Text(
              '취소',
              style: TextStyle(
                  color: Color(0xFF505050), fontWeight: FontWeight.w600),
            ),
            //style: ButtonStyle(foregroundColor: Material),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text(
              '삭제',
              style: TextStyle(
                  color: Color(0xFF505050), fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              if (task['managed_by'] == '') {
                FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(taskId)
                    .delete();
              } else {
                removeCurrentUserFromTask(taskId);
              }
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> removeCurrentUserFromTask(String taskId) async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      var taskDocRef =
          FirebaseFirestore.instance.collection('tasks').doc(taskId);

      // 해당 task 문서의 'assigned_users' 필드 가져오기
      var taskDoc = await taskDocRef.get();
      if (taskDoc.exists) {
        List<dynamic> assignedUsers = List.from(taskDoc['assigned_users']);
        int userIndex = assignedUsers.indexOf(currentUser.uid);
        List stateList = List.from(taskDoc['state']);
        List alertList = List.from(taskDoc['alert']);
        stateList.removeAt(userIndex);
        alertList.removeAt(userIndex);

        // 현재 사용자의 UID가 배열에 있으면 제거
        assignedUsers.remove(currentUser.uid);

        // 변경된 배열로 문서 업데이트
        await taskDocRef.update({
          'assigned_users': assignedUsers,
          'state': stateList,
          'alert': alertList
        });
      }
    }
  }

  _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AddTaskDialog();
      },
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  String taskName = '';
  String taskScript = '';
  DateTime defaultDate = DateTime(DateTime.now().year + 10, 12, 31, 23, 59);
  DateTime finishedAt = DateTime(DateTime.now().year + 10, 12, 31, 23, 59);
  DateTime selectedDate = DateTime.now();

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
        finishedAt = selectedDate
            .add(const Duration(hours: 23, minutes: 59)); // 선택한 날짜에 23시 59분을 더함
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('개인 업무 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            onChanged: (value) {
              taskName = value;
            },
            cursorColor: const Color(0xFFAD8B73),
            decoration: const InputDecoration(
              labelText: '업무 이름',
              labelStyle: TextStyle(color: Color(0xFF8D6B53)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8D6B53)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8D6B53)),
              ),
            ),

            // decoration: const InputDecoration(labelText: 'Task Name',labelStyle: TextStyle(color: Color(0xFF8D6B53))),
          ),
          TextField(
            onChanged: (value) {
              taskScript = value;
            },
            cursorColor: const Color(0xFFAD8B73),
            decoration: const InputDecoration(
              labelText: '설명',
              labelStyle: TextStyle(color: Color(0xFF8D6B53)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8D6B53)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8D6B53)),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 5,),
          ElevatedButton(
              onPressed: () => selectDate(context),
              child: Text(
                finishedAt == defaultDate
                    ? '마감기한 설정'
                    : DateFormat.yMMMd().format(finishedAt),
                style: const TextStyle(
                  color: Colors.black,
                ),
              )),
        ],
      ),
      actions: [
        ElevatedButton(
          child: const Text('취소',
              style: TextStyle(
                color: Colors.black,
              )),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('추가',
              style: TextStyle(
                color: Colors.black,
              )),
          onPressed: () {
            var currentUser = FirebaseAuth.instance.currentUser;
            var uid = currentUser?.uid;
            if (taskName != '') {
              if (uid != null) {
                FirebaseFirestore.instance.collection('tasks').add({
                  'task_name': taskName,
                  'task_script': taskScript,
                  'finished_at': finishedAt,
                  'created_at': DateTime.now(),
                  'assigned_users': [uid],
                  'managed_by': '',
                  'state': [0],
                  'alert': [false]
                });
              }

              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('업무 이름은 필수입니다.'),
                  duration: Duration(seconds: 2), // 2초 동안 표시
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
