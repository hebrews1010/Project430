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
  String? groupId;
  late Map<String, dynamic> task = widget.task;
  bool ing = false;
  bool ing2 =false;
  bool ing3 = false;

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
      groupId = groupSnapshot.docs.isNotEmpty
          ? groupSnapshot.docs.first.id
          : null;

      //그룹은 하나밖에 없으므로 groupSnapshot.docs.first.id해도 될듯
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
    // groupSnapshot이 null이거나 비어있는 경우에 대한 방어 코드 추가
    if (groupSnapshot == null || groupSnapshot.docs.isEmpty) {
      print("_showSelectUsersDialog: groupSnapshot is null or empty.");
      if (mounted) { // context 사용 전 mounted 확인
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('그룹 정보를 먼저 불러와주세요.')),
        );
      }
      return;
    }
    // 현재 사용자가 속한 그룹 중 첫 번째 그룹을 사용한다고 가정
    DocumentSnapshot group = groupSnapshot.docs.first;
    String groupId = group.id;
    List<dynamic> groupUserUids = (group.data() as Map<String, dynamic>?)?['group_users'] as List<dynamic>? ?? [];

    // groupUserUids를 String 리스트로 변환
    List<String> groupUserUidsString = groupUserUids.map((e) => e.toString()).toList();

    // 기존 checkedUsers를 기반으로 이 다이얼로그의 초기 선택 상태 설정
    // 이 로직은 다이얼로그가 표시될 때마다 실행되므로,
    // 사용자가 다이얼로그 내에서 선택한 사항을 유지하려면
    // checkedUsers를 이 함수의 로컬 변수로 복사해서 사용하고,
    // 확인 시에만 page state의 checkedUsers를 업데이트하는 것이 좋습니다.
    // 여기서는 기존 로직을 최대한 따르되, 초기화 문제를 인지합니다.
    Set<String> dialogCheckedUsers = Set<String>.from(checkedUsers); // 다이얼로그 로컬 선택 상태

    // getGroupUsers 함수는 이제 List<String>을 반환한다고 가정
    // (원래 코드에서는 Map<String, List<String>>을 반환하는 getGroupUsers(groups) 였음)
    // 단일 그룹에 대한 사용자 이름 목록을 가져오는 함수가 필요합니다.
    // 여기서는 _getUsersNames(List<dynamic> userUids)를 직접 사용한다고 가정합니다.
    _getUsersNames(groupUserUidsString).then( // groupUserUidsString 사용
          (List<String> userNames) { // 이제 userNames는 특정 그룹의 이름 리스트
        if (!mounted) return;

        // isCheckedList 초기화: widget.task['assigned_users']를 기준으로
        // 이 로직은 다이얼로그가 열릴 때마다 수행되어 이전 선택을 덮어쓸 수 있으므로 주의
        List<bool> isCheckedList = List.generate(userNames.length, (idx) {
          if (idx < groupUserUidsString.length) {
            return dialogCheckedUsers.contains(groupUserUidsString[idx]);
          }
          return false;
        });
        // 기존 코드의 초기화 로직:
        // 만약 이전에 선택된 것이 없고, task에 할당된 사용자가 있다면 초기 체크
        // 이 부분은 사용자의 의도에 따라 조정 필요 (항상 task 기준으로 할지, 이전 선택 유지할지)
        bool wasAnythingCheckedInitiallyByTask = false;
        List<dynamic> assignedUsersInTask = widget.task['assigned_users'] as List<dynamic>? ?? [];
        Set<String> taskAssignedSet = Set<String>.from(assignedUsersInTask.cast<String>());

        for(int i=0; i< userNames.length; i++){
          if (i < groupUserUidsString.length && taskAssignedSet.contains(groupUserUidsString[i])) {
            if(!isCheckedList[i]) { // 이미 dialogCheckedUsers에 의해 true가 아니라면
              isCheckedList[i] = true;
              dialogCheckedUsers.add(groupUserUidsString[i]); // dialogCheckedUsers에도 반영
            }
            wasAnythingCheckedInitiallyByTask = true;
          }
        }
        // 만약 Task에 할당된 사용자가 없어서 isCheckedList가 모두 false라면,
        // 그리고 dialogCheckedUsers (이전 선택) 에 의해 체크된 것도 없다면,
        // 이전에 사용자가 다이얼로그에서 선택했던 상태 (dialogCheckedUsers)를 isCheckedList에 반영해야 합니다.
        // 현재는 위 로직에서 task의 assigned_users를 dialogCheckedUsers에 추가하고, 이를 isCheckedList에 반영하고 있습니다.


        showDialog(
            context: context,
            builder: (BuildContext dialogContext) { // dialogContext 사용
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setDialogState) { // setDialogState 사용
                    return Scaffold(
                        appBar: AppBar(
                          title: Text("${group['group_name'] ?? '그룹'} 구성원 선택"),
                          leading: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        body: userNames.isEmpty
                            ? const Center(child: Text("선택할 사용자가 없습니다."))
                            : SingleChildScrollView( // ListView.builder 대신 SingleChildScrollView + Column
                          child: Column(
                            children: [
                              ListTile( // 태스크 이름은 AppBar나 다른 곳으로 옮기는 것이 UI상 더 자연스러울 수 있습니다.
                                title: Text('태스크: ${widget.task['task_name']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                // subtitle: Text('그룹: ${group['group_name']}'), // AppBar로 옮김
                              ),
                              // Column으로 CheckboxListTile들을 직접 나열
                              ...userNames.asMap().entries.map((entry) { // ...
                                int idx = entry.key;
                                String userName = entry.value;

                                if (idx >= groupUserUidsString.length || idx >= isCheckedList.length) {
                                  return const SizedBox.shrink(); // 데이터 불일치 방지
                                }
                                String userUid = groupUserUidsString[idx];

                                return CheckboxListTile(
                                  title: Text(userName),
                                  value: isCheckedList[idx],
                                  onChanged: (bool? value) {
                                    setDialogState(() { // 다이얼로그 내부 UI만 업데이트
                                      isCheckedList[idx] = value ?? false;
                                      // groupCheckedStatus[groupId] = isCheckedList; // 단일 그룹이므로 이 Map 구조는 불필요해짐

                                      if (value == true) {
                                        dialogCheckedUsers.add(userUid);
                                      } else {
                                        dialogCheckedUsers.remove(userUid);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                        floatingActionButton: FloatingActionButton(
                          child: const Icon(Icons.check_circle_outline),
                          onPressed: () async { // async 추가
                            if (ing2 == true) return; // 중복 실행 방지

                            setState(() { ing2 = true; }); // _TaskManagePageState의 setState 사용

                            if (dialogCheckedUsers.isNotEmpty) { // 다이얼로그의 로컬 선택 사용
                              var currentAuthUser = FirebaseAuth.instance.currentUser;
                              // var uid = currentAuthUser?.uid; // 현재 코드에서는 uid 변수를 직접 사용하지 않음

                              List<dynamic> currentAssignedDb = List.from(widget.task['assigned_users'] ?? []);
                              List<dynamic> currentStatesDb = List.from(widget.task['state'] ?? []);
                              List<dynamic> currentAlertsDb = List.from(widget.task['alert'] ?? []);

                              Map<String, int> oldUserStates = {};
                              Map<String, bool> oldUserAlerts = {};

                              for (int i = 0; i < currentAssignedDb.length; i++) {
                                if (i < currentStatesDb.length) {
                                  oldUserStates[currentAssignedDb[i] as String] = currentStatesDb[i] as int;
                                }
                                if (i < currentAlertsDb.length) {
                                  oldUserAlerts[currentAssignedDb[i] as String] = currentAlertsDb[i] as bool;
                                }
                              }

                              List<String> newAssignedUsersList = dialogCheckedUsers.toList();
                              List<int> newStates = [];
                              List<bool> newAlerts = [];

                              for (String userIdInNewList in newAssignedUsersList) {
                                newStates.add(oldUserStates[userIdInNewList] ?? 0);
                                newAlerts.add(oldUserAlerts[userIdInNewList] ?? false);
                              }

                              try {
                                await FirebaseFirestore.instance // await 추가
                                    .collection('tasks')
                                    .doc(widget.taskId)
                                    .update({
                                  'assigned_users': newAssignedUsersList,
                                  'state': newStates,
                                  'alert': newAlerts
                                });

                                // 부모 위젯(TaskManageDialog)의 상태 업데이트
                                setAssignedUsers(newAssignedUsersList, newStates, newAlerts);

                                if (mounted) Navigator.of(dialogContext).pop(); // 다이얼로그 닫기 (dialogContext 사용)

                              } catch (e) {
                                print("Error updating task: $e");
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('업무 업데이트 중 오류: ${e.toString()}')));
                              } finally {
                                if (mounted) setState(() { ing2 = false; });
                              }
                            } else {
                              // 선택된 사용자가 없는 경우 처리
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('선택된 수행자가 없습니다.')));
                              if (mounted) setState(() { ing2 = false; });
                            }
                          },
                        ));
                  });
            }).then((_) { // 반환값이 없으므로 value 파라미터 제거
          // 다이얼로그가 닫힌 후 실행될 코드 (예: _TaskManagePageState의 ing 상태 업데이트)
          // 이 setState는 _TaskManagePageState의 것
          if (mounted) {
            setState(() {
              // ing = false; // ing는 _showAddTaskDialog에서 사용하던 것, 여기서는 ing2를 주로 사용함
              // checkedUsers는 여기서 업데이트할 필요 없음. 이미 FAB onPressed에서 this.checkedUsers가 업데이트됨.
            });
          }
        });
      },
    ).catchError((error) { // getGroupUsers (또는 _getUsersNames) 에러 처리
      print("Error getting user names: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사용자 이름 로딩 중 오류가 발생했습니다.')));
      }
      setState(() => ing2 = false); // 로딩 상태 해제
    });
  }

// _getUsersNames 함수는 _TaskManagePageState 내에 이미 정의되어 있다고 가정합니다.
// Future<List<String>> _getUsersNames(List<dynamic> userUids) async { ... }

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
                  if (ing3 == true) {
                    print('no');
                    null;
                  } else {
                    ing3 = true;
                    FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(widget.taskId)
                        .update({
                      'task_name': _taskNameController.text,
                      'task_script': _taskScriptController.text,
                    });
                    ing3 = false;
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
            child: ing // _isLoading은 State 클래스의 멤버 변수여야 합니다 (예: bool _isLoading = false;)
                ? const SizedBox( // 로딩 중일 때 인디케이터 표시
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // 버튼 색상에 맞게 조절
              ),
            )
                : const Text('확인'),
            onPressed: ing // 로딩 중이면 버튼 비활성화
                ? null
                : () async { // async 키워드 추가
              if (!mounted) return; // 위젯이 마운트되어 있는지 확인

              setState(() {
                ing = true; // 로딩 시작 상태 업데이트
                // nameLine = 1; // nameLine 변경이 UI에 영향을 준다면 여기서 setState와 함께 처리
              });

              try {
                await FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.taskId) // widget.taskId가 유효하다고 가정
                    .update({
                  'task_name': _taskNameController.text,
                  'task_script': _taskScriptController.text,
                  // 'finished_at' 업데이트는 선택 사항
                });

                print('Task ${widget.taskId} updated successfully.');

                if (mounted) { // 작업 완료 후 다시 mounted 확인
                  Navigator.of(context).pop(); // 편집 대화상자 닫기
                  // 필요한 경우 부모 위젯에 상태 변경 알림 또는 추가적인 상태 업데이트
                  // 예: widget.onTaskUpdated?.call();
                }
              } catch (error) {
                print('Error updating task: $error');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('업무 업데이트 중 오류가 발생했습니다: ${error.toString()}')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    ing = false; // 로딩 종료 상태 업데이트
                  });
                }
              }
            },
          )
        ],
      ),
    );
  }
}

Future<List<String>> getGroupUsers(
   DocumentSnapshot group) async {
 List<String> groupUserNames = [];

    List<dynamic> groupUsers = group['group_users'] as List<dynamic>;
    List<String> userNames = await _getUsersNames(groupUsers);
    groupUserNames = userNames;

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
