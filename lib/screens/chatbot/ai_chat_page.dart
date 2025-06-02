import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gemini_service.dart';
import 'dart:convert';
import 'package:fourthirty/mainuipage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

final String userId = MainUiPage().userUid;

class _ChatScreenState extends State<ChatScreen> {

  final ScrollController _scrollController = ScrollController();

  bool keyboardScroll = false;
  final TextEditingController _messageController = TextEditingController();

  // Changed from `late final` to nullable and then assigned.
  // We'll initialize it asynchronously.
  GeminiService? _geminiService;

  final CollectionReference _messagesCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('messages');

  final CollectionReference _tasksCollection = FirebaseFirestore.instance
          .collection('tasks');

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scrollToBottomWhenScrolling() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Asynchronously initialize GeminiService
    _initializeGeminiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // GeminiService를 비동기적으로 초기화하는 새로운 메서드
  Future<void> _initializeGeminiService() async {
    // GeminiService.create()를 호출하고 초기화 완료까지 기다립니다.
    final service = await GeminiService(userId);
    setState(() {
      _geminiService = service; // 초기화된 인스턴스 할당
    });
  }

  void _sendUserMessage(String message) {
    // Ensure _geminiService is initialized before using it
    if (_geminiService == null) {
      print("GeminiService is not yet initialized. Please wait.");
      return; // Or show a loading indicator
    }

    if (message.isNotEmpty) {
      _messagesCollection.add({
        'text': message,
        'sender': 'user',
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();

      _geminiService!
          .getAiResponse(message)
          .then((responseMessage) {
            // Use `!` since we checked for null
            if (responseMessage != null) {
              _messagesCollection.add({
                'text': responseMessage,
                'sender': 'ai',
                'timestamp': FieldValue.serverTimestamp(),
              });
              _geminiService!.AfterResponse(responseMessage);

              if (responseMessage.startsWith('[')) {
                try {
                  final decodedMessages = json.decode(responseMessage);
                  for (var msg in decodedMessages) {
                    if (msg.containsKey('task')) {
                      msg['task'].forEach((taskTitle, completed) async {
                        QuerySnapshot existingTasks =
                            await _tasksCollection
                                .where('task_name', isEqualTo: taskTitle)
                                .where('state', isEqualTo: [0])
                                .get();

                        if (existingTasks.docs.isNotEmpty) {
                          await existingTasks.docs.first.reference.update({
                            'completed': completed,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await _tasksCollection.add({
                            'task_name': taskTitle,
                            'task_script': '',
                            'finished_at': DateTime.now(),
                            'created_at': DateTime.now(),
                            'assigned_users': [userId],
                            'managed_by': '',
                            'state': completed ? [2] : [0],
                            'alert': [false]
                          });
                          //state는 2는 완료, 0은 미완, 1은 진행중
                        }
                      });
                    }
                  }
                } catch (e) {
                  print("JSON 파싱 오류: $e");
                }
              }
              _scrollToBottom();
            }
          })
          .catchError((error) {
            print("세나 응답 받기 실패: $error");
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Color(0xFFEDEDED), // Changed to a light grey color
        body: KeyboardVisibilityBuilder(
          builder: (context, isKeyboardVisible) {
            if (isKeyboardVisible == false) {
              keyboardScroll = false;
            }
            if (isKeyboardVisible == true && keyboardScroll == false) {
              _scrollToBottomWhenScrolling();
              keyboardScroll = true;
            }
            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        _messagesCollection.orderBy('timestamp').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 20,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = messages[index];
                          final messageText = messageData['text'];

                          if (messageText.startsWith('[')) {
                            try {
                              final decodedMessages = json.decode(messageText);

                              List<Widget> messageWidgets = [];
                              for (var msg in decodedMessages) {
                                msg.forEach((key, value) {
                                  if (key == 'task' && value != null) {
                                    messageWidgets.add(
                                      _buildTaskMessage(value),
                                    );
                                  } else if (key == 'talk' && value != null) {
                                    messageWidgets.add(
                                      _buildDefaultMessage(value, false),
                                    );
                                  }
                                });
                              }

                              return Column(children: messageWidgets);
                            } catch (e) {
                              print("메시지 파싱 오류: $e");
                              return const SizedBox();
                            }
                          }

                          return _buildDefaultMessage(
                            messageText,
                            messageData['sender'] == 'user',
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7), // Fixed withValues
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'AI와 대화하기...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                          ),
                          onSubmitted: (value) {
                            _sendUserMessage(value);
                            _scrollToBottom();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          _sendUserMessage(_messageController.text);
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskMessage(Map taskData) {
    if (taskData.isEmpty) {
      return const SizedBox();
    }
    List<Widget> taskWidgets = [];
    taskData.forEach((key, value) {
      taskWidgets.add(
        Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: Colors.black,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                key,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.03), // Fixed withValues
          border: Border.all(color: Color(0xff635e5e), width: 3),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '할 일',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
            const Divider(color: Color(0xff635e5e)),
            ...taskWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultMessage(String messageText, bool isUserMessage) {
    if (messageText.isEmpty) {
      return const SizedBox();
    }
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                isUserMessage
                    ? Color(0xFFDCDCDC) // Fixed withValues
                    : Color(0xFFFFFFFF), // Fixed withValues
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            messageText,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            softWrap: true,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
