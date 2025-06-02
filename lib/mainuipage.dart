import 'package:flutter/material.dart' hide DatePickerTheme;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourthirty/screens/group/groupmanage.dart';
import 'package:fourthirty/screens/todo/todolist.dart';
import 'package:fourthirty/screens/calendar/calendar.dart';
import 'package:fourthirty/screens/task/taskmanage.dart';
import 'package:fourthirty/screens/bulletin/bulletin.dart'; //web으로 바꾸려면 여기만 웹으로 바꾸셈
import 'package:fourthirty/screens/settings/settings.dart';
import 'package:fourthirty/screens/chatbot/ai_chat_page.dart';

class MainUiPage extends StatefulWidget {
  const MainUiPage({super.key});

  String get userUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  _MainUiPageState createState() => _MainUiPageState();
}

class _MainUiPageState extends State<MainUiPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _groupDisplayName = '';
  String _groupManagerUid = ''; // 그룹 관리자 UID를 저장할 변수
  int _selectedIndex = 0;

  // 각 메뉴에 해당하는 위젯을 리스트로 구성합니다.
  // 이 리스트는 이제 고정적으로 모든 위젯을 포함합니다.
  // bottomNavigationBarItem을 조건부로 생성할 것입니다.
  static final List<Widget> _widgetOptions = <Widget>[
    const TasksPage(),
    const TaskManagePage(),
    const ChatScreen(),
    const CalendarViewPage(),
    const BulletinPage(),
    const GroupManagePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadGroupInfo(); // 그룹 이름과 관리자 정보를 함께 로드
  }

  // 그룹 이름과 그룹 관리자 UID를 함께 로드하는 함수
  Future<void> _loadGroupInfo() async {
    if (userUid.isNotEmpty) {
      final DocumentSnapshot userSnapshot =
      await _firestore.collection('users').doc(userUid).get();

      if (userSnapshot.exists) {
        final String userGroupId = userSnapshot['user_group_id'] ?? '';

        if (userGroupId.isNotEmpty) {
          final DocumentSnapshot groupSnapshot =
          await _firestore.collection('groups').doc(userGroupId).get();

          if (groupSnapshot.exists) {
            final String groupName = groupSnapshot['group_name'] ?? '';
            final String groupManager = groupSnapshot['group_manager'] ?? ''; // 그룹 관리자 UID 로드

            setState(() {
              _groupDisplayName = groupName;
              _groupManagerUid = groupManager; // 상태 업데이트
            });
          }
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 사용자가 그룹 관리자인지 확인하는 플래그
    final bool isGroupManager = userUid == _groupManagerUid;

    // 조건부로 BottomNavigationBarItem 리스트를 생성
    final List<BottomNavigationBarItem> bottomNavItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.check_circle),
        label: '업무 목록',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.create),
        label: '업무 관리',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.send_sharp),
        label: '챗봇',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: '캘린더',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.message),
        label: '게시판',
      ),
    ];

    // 그룹 관리자일 경우에만 '그룹 관리' 아이템 추가
    if (isGroupManager) {
      bottomNavItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: '그룹 관리',
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _selectedIndex ==2 ? const Color(0xFFEDEDED) : const Color(0xFFFFFFFF),
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
          // _selectedIndex가 bottomNavItems.length보다 크거나 같을 경우 (예: 관리자 권한이 사라져서 인덱스가 없는 메뉴를 가리킬 때)
          // 기본값으로 첫 번째 메뉴를 보여주도록 안전 장치 추가
          child: _selectedIndex < _widgetOptions.length ? _widgetOptions.elementAt(_selectedIndex) : _widgetOptions.first,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.shifting,
          iconSize: 30,
          items: bottomNavItems, // 조건부로 생성된 아이템 리스트 사용
          currentIndex: _selectedIndex,
          unselectedItemColor: Colors.grey,
          selectedItemColor: const Color(0xFF4D4B43),
          onTap: (index) {
            // 선택된 인덱스가 현재 `bottomNavItems` 리스트의 범위를 벗어나지 않도록
            // 즉, 관리자 메뉴가 사라져서 인덱스 불일치가 발생할 경우를 처리
            if (index < bottomNavItems.length) {
              _onItemTapped(index);
            } else {
              // 예를 들어, 관리자 메뉴가 사라진 후에도 해당 인덱스가 선택되어 있다면
              // 기본값으로 첫 번째 메뉴를 선택하도록 처리할 수 있습니다.
              _onItemTapped(0);
            }
          },
        ),
      ),
    );
  }
}