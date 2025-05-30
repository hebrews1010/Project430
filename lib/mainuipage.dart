import 'package:flutter/material.dart' hide DatePickerTheme;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourthirty/screens/group/groupmanage.dart';
import 'package:fourthirty/screens/todo/todolist.dart';
import 'package:fourthirty/screens/calendar/calendar.dart';
import 'package:fourthirty/screens/task/taskmanage.dart';
import 'package:fourthirty/screens/bulletin/bulletin.dart'; //web으로 바꾸려면 여기만 웹으로 바꾸셈
import 'package:fourthirty/screens/settings/settings.dart';

class MainUiPage extends StatefulWidget {
  const MainUiPage({super.key});

  @override
  _MainUiPageState createState() => _MainUiPageState();
}

class _MainUiPageState extends State<MainUiPage> {
  @override
  void initState() {
    super.initState();
    _loadGroupDisplayName();
  }

  Future<void> _loadGroupDisplayName() async {
    // 현재 사용자의 uid 가져오기
    final String userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userUid.isNotEmpty) {
      // 사용자의 uid를 사용하여 users 컬렉션의 문서를 가져오기
      final DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userUid).get();

      if (userSnapshot.exists) {
        // user_group_id 가져오기
        final String userGroupId = userSnapshot['user_group_id'] ?? '';

        if (userGroupId.isNotEmpty) {
          // user_group_id를 사용하여 group 컬렉션의 문서를 가져오기
          final DocumentSnapshot groupSnapshot =
              await _firestore.collection('groups').doc(userGroupId).get();

          if (groupSnapshot.exists) {
            // group 이름 가져오기
            final String groupName = groupSnapshot['group_name'] ?? '';

            setState(() {
              _groupDisplayName = groupName;
            });
          }
        }
      }
    }
  }

  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _groupDisplayName = '';

  // 각 메뉴에 해당하는 위젯을 리스트로 구성합니다.
  static final List<Widget> _widgetOptions = <Widget>[
    const TasksPage(),
    const TaskManagePage(),
    const CalendarViewPage(),
    const BulletinPage(),
    const GroupManagePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          // 현재 포커스를 가진 위젯을 해제하여 키보드를 숨깁니다.
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            shadowColor: Colors.brown[200],

            titleSpacing: 22,
            title: Text(
              _groupDisplayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ));
                },
              ),
            ],
          ),
          body: Center(
            // 선택된 메뉴에 해당하는 위젯을 표시합니다.
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.shifting,
            iconSize: 30,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.check_circle),
                label: '업무 목록',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.create),
                label: '업무 관리',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: '캘린더',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.message),
                label: '게시판',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: '그룹 관리',
              ),
            ],
            currentIndex: _selectedIndex,
            unselectedItemColor: Colors.grey,
            selectedItemColor: const Color(0xFF8D6B53),
            onTap: _onItemTapped,
          ),
        ));
  }
}
