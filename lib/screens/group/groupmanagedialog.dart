import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class GroupManageDialog extends StatefulWidget {
  final String user_id;
  final String user_name;
  final String groupId;

  const GroupManageDialog({
    super.key,
    required this.user_id,
    required this.user_name,
    required this.groupId,
  });

  @override
  _GroupManageDialogState createState() => _GroupManageDialogState();
}

class _GroupManageDialogState extends State<GroupManageDialog> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> tasks = [];
  Map<String, dynamic> userTasksState = {};

  @override
  void initState() {
    super.initState();
    _fetchUserTasks();
  }

  Future<void> _fetchUserTasks() async {
    QuerySnapshot taskSnapshot =
        await firestore
            .collection('tasks')
            .where('assigned_users', arrayContains: widget.user_id)
            .get();

    for (var doc in taskSnapshot.docs) {
      if (doc['managed_by'] != '') {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int userIndex = (data['assigned_users'] as List).indexOf(
          widget.user_id,
        );
        if (userIndex != -1) {
          tasks.add({
            'id': doc.id,
            'name': data['task_name'],
            'state': data['state'][userIndex],
            'assigned_users': data['assigned_users'],
          });
        }
      }
    }

    setState(() {});
  }

  void _updateTaskState(String taskId, int newState, int userIndex) async {
    DocumentSnapshot taskDoc =
        await firestore.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) return;

    Map<String, dynamic> taskData = taskDoc.data() as Map<String, dynamic>;
    List<dynamic> states = taskData['state'];

    if (userIndex >= 0 && userIndex < states.length) {
      states[userIndex] = newState; // 상태 업데이트
      firestore.collection('tasks').doc(taskId).update({'state': states});
    }
  }

  void _forceRemoveUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('강제 탈퇴'),
          content: Text('${widget.user_name}를 그룹에서 탈퇴시키겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('강퇴하기'),
              onPressed: () {
                // Update the user's 'user_group_id' to ''
                leaveGroup(widget.user_id);

                Navigator.of(context).pop(); // Close the confirmation dialog
                Navigator.of(context).pop(); // Close the GroupManageDialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> leaveGroup(String? uid) async {
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final user_group_id = userDoc.data()?['user_group_id'];
    final groupDoc =
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(user_group_id)
            .get();
    final group_manager_id = groupDoc.data()?['group_manager'];

    if (user_group_id != null) {
      // 그룹에서 사용자 제거
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(user_group_id)
          .update({
            'group_users': FieldValue.arrayRemove([uid]),
          });

      // 사용자의 user_group_id 필드 비우기
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'user_group_id': '',
      });

      // 작업에서 사용자 제거(자기가 관리 안하는 작업)
      final tasksQuerySnapshot =
          await FirebaseFirestore.instance
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
              'alert': alerts,
              'managed_by': group_manager_id,
            });
          }
        }
      }

      //내가 관리하는 업무를 관리자에게 떠넘기기
      final tasksQuerySnapshot2 =
          await FirebaseFirestore.instance
              .collection('tasks')
              .where('managed_by', isEqualTo: uid)
              .get();

      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(user_group_id)
              .get();

      for (var doc in tasksQuerySnapshot2.docs) {
        List<dynamic> assignedUsers = doc['assigned_users'] ?? [];
        String task_manager = groupDoc['group_manager'] ?? '';
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
          'managed_by': task_manager,
          'state': states,
          'alert': alerts,
        });
      }

      // 작성한 게시물 삭제
      final postsQuerySnapshot =
          await FirebaseFirestore.instance
              .collection('posts')
              .where('made_by', isEqualTo: uid)
              .get();

      for (var doc in postsQuerySnapshot.docs) {
        var commentsSnapshot =
            await FirebaseFirestore.instance
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

        if (fileUrls.isNotEmpty) {
          for (var fileUrl in fileUrls) {
            if (fileUrl != null) {
              var fileRef = storage.refFromURL(fileUrl);
              await fileRef.delete();
            }
          }
        }

        if (imageUrls.isNotEmpty) {
          for (var imageUrl in imageUrls) {
            if (imageUrl != null) {
              var imageRef = storage.refFromURL(imageUrl);
              await imageRef.delete();
            }
          }
        }
        await doc.reference.delete();
      }

      // 그룹 탈퇴 처리 후 로직 (예: 홈 화면으로 이동)
    }
  }

  String taskStateToString(int state) {
    switch (state) {
      case 0:
        return '시작 전';
      case 1:
        return '진행중';
      case 2:
        return '완료';
      default:
        return '알 수 없음';
    }
  }

  int taskStateFromString(String state) {
    switch (state) {
      case '시작 전':
        return 0;
      case '진행중':
        return 1;
      case '완료':
        return 2;
      default:
        return -1; // 잘못된 값 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user_name),
      content: SingleChildScrollView(
        child: ListBody(
          children:
              tasks.map((task) {
                return ListTile(
                  title: Text(task['name']),
                  trailing: DropdownButton<String>(
                    value: taskStateToString(task['state']),
                    items:
                        <String>['시작 전', '진행중', '완료'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        int newState = taskStateFromString(newValue);
                        int userIndex = task['assigned_users'].indexOf(
                          widget.user_id,
                        );

                        if (userIndex != -1) {
                          setState(() {
                            // UI 업데이트를 위해 tasks 리스트의 해당 태스크 상태 업데이트
                            int taskIndex = tasks.indexWhere(
                              (t) => t['id'] == task['id'],
                            );
                            if (taskIndex != -1) {
                              tasks[taskIndex]['state'] = newState;
                            }

                            _updateTaskState(
                              task['id'],
                              newState,
                              userIndex,
                            ); // Firestore 업데이트
                          });
                        }
                      }
                    },
                  ),
                );
              }).toList(),
        ),
      ),
      actions: <Widget>[
        ElevatedButton(
          child: const Text('강제 탈퇴'),
          onPressed: () => _forceRemoveUser(context),
        ),
        ElevatedButton(
          child: const Text('확인'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
