import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarViewPage extends StatefulWidget {
  const CalendarViewPage({super.key});

  @override
  _CalendarViewPageState createState() => _CalendarViewPageState();
}

class _CalendarViewPageState extends State<CalendarViewPage> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<Map<String, dynamic>>? _selectedTasks = [];
  final Map<DateTime, List<dynamic>> _tasks = {};

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Color determineColor(List assignedUsers, List stateList, DateTime finishDate) {
    // 날짜 비교를 위해 시간 부분을 제외한 오늘 날짜의 시작 시점
    DateTime today = DateTime.now();
    DateTime startOfToday = DateTime(today.year, today.month, today.day);

    // finishDate도 시간 부분을 제외하고 날짜만 비교하기 위해 정규화
    DateTime finishDateOnly = DateTime(finishDate.year, finishDate.month, finishDate.day);

    int userState = -1; // 기본 상태 (사용자 정보를 찾을 수 없거나 상태가 없을 경우)

    if (uid != null) {
      int userIndex = assignedUsers.indexOf(uid);
      if (userIndex != -1 && userIndex < stateList.length) {
        // 사용자의 상태가 유효하게 존재하면 해당 상태 값 사용
        userState = stateList[userIndex];
      }
    }

    // 1. 사용자의 상태가 '완료'(2)인 경우
    if (userState == 2) {
      return Colors.grey.shade400; // 회색
    } else {
      // 사용자의 상태가 '완료'가 아닌 경우 (0, 1, 또는 알 수 없음 -1)

      // 2.a. 마감일(finishDateOnly)이 오늘 이전(startOfToday)인 경우 (즉, 어제까지였던 경우)
      if (finishDateOnly.isBefore(startOfToday)) {
        return const Color(0xffFF6868); // 빨간색
      } else {
        if( userState == 1) {
          return const Color(0xffFDE767); // 노란색
        }else{
        // 2.b. 마감일이 오늘이거나 오늘 이후인 경우
        return Colors.lightGreen;} // 밝은 녹색
      }
    }
  }

  var uid = FirebaseAuth.instance.currentUser?.uid;

  void _fetchTasks() async {
    FirebaseFirestore.instance
        .collection('tasks')
        .where('assigned_users', arrayContains: uid)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        DateTime finishDate = (doc.data()['finished_at'] as Timestamp).toDate();
        String taskName = doc.data()['task_name'];
        List state = doc.data()['state'];
        List assignedUsers = doc.data()['assigned_users'];
        Color taskColor = determineColor(assignedUsers, state, finishDate);

        DateTime dayKey =
            DateTime(finishDate.year, finishDate.month, finishDate.day);

        if (!_tasks.containsKey(dayKey)) {
          _tasks[dayKey] = [];
        }
        _tasks[dayKey]?.add({'color': taskColor, 'name': taskName});
      }
      setState(() {});
    });
  }

  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    DateTime dayKey = DateTime(day.year, day.month, day.day);

    // _tasks[dayKey]에서 최대 4개의 task만 반환
    return _tasks[dayKey]?.take(4).map((task) {
          return {
            'color': task['color'],
            'name': task['name'],
          };
        }).toList() ??
        [];
  }

  void _showTaskListBottomSheet(
      BuildContext context, List<Map<String, dynamic>>? tasks) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // 리스트뷰 스크롤 비활성화
                  itemCount: tasks?.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                        tasks?[index]['task_name'],
                        textScaler: const TextScaler.linear(1.4),
                      ),
                      leading: Icon(Icons.circle,
                          color: tasks?[index]['task_color']),
                      //여기서 색깔을 불러와야됨. determineColor을 여기서 하면 안되고, marker 할때 해야됨. 그리고 그 데이터는 매핑되어야함.
                      // 다른 task 정보 표시하기
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchTasksForSelectedDay(DateTime selectedDay) async {
    final DateTime startOfDay =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final DateTime endOfDay = DateTime(
        selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);

    final QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance
            .collection('tasks')
            .where('assigned_users', arrayContains: uid)
            .where('finished_at', isGreaterThanOrEqualTo: startOfDay)
            .where('finished_at', isLessThanOrEqualTo: endOfDay)
            .get();

    final List<Map<String, dynamic>> tasks = querySnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
      List<dynamic> stateList = document['state'];
      return {
        'task_name': document['task_name'],
        'task_color': determineColor(document['assigned_users'], stateList,
            (document['finished_at'] as Timestamp).toDate()),
        //얘를 string, color 오가면서 작업해야함.
        // 다른 task 정보 가져오기
      };
    }).toList();

    setState(() {
      _selectedTasks = tasks;
    });
  }

  Widget _buildEventsMarker(DateTime date, List<dynamic> events) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: events.map((event) {
        // Ensure 'event' is a Map and has a 'color' key
        if (event is Map && event.containsKey('color')) {
          return Container(
            margin: const EdgeInsets.only(top: 40),
            child: Icon(
              size: 12,
              Icons.feed,
              color: event['color'],
            ),
          );
        } else {
          return Container(); // Or some other default widget
        }
      }).toList(),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: TableCalendar(
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB0A695), width: 2),
                color: const Color(0xFF776B5D),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(7),
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFB0A695),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            locale: 'ko_KR',
            calendarFormat: _calendarFormat,
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2101),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            headerStyle: const HeaderStyle(formatButtonVisible: false,titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.black,fontSize: 20),
              leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFFB0A6A5)),
              rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFFB0A6A5)),
            ),
            daysOfWeekHeight: 20,
            onDaySelected: (selectedDay, focusedDay) async {
              // 비동기 작업 수행
              await _fetchTasksForSelectedDay(selectedDay);

              // 비동기 작업이 완료되면 setState() 호출하여 화면 업데이트
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              _showTaskListBottomSheet(context, _selectedTasks);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) => _getTasksForDay(day),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return _buildEventsMarker(date, events);
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }
}
