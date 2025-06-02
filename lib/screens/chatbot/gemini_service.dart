import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';

class GeminiService {
  static const String _apiKey = "AIzaSyAg3IqEuVI2dRSTOlZ-ngwPT9Kq2LO_Eao";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _userId;

  // Local context variable to store the message history
  String _currentMessageContext = '';
  // Flag to track if the initial context has been loaded
  bool _isContextInitialized = false;

  GeminiService(this._userId);

  // Initialize the context when the service is created
  // This should be called only once when the user session starts.
  Future<void> initializeContext() async {
    if (_isContextInitialized) {
      return; // Prevent re-initialization
    }

    _currentMessageContext = await _loadMessageContextFromStorage();

    // If no context was found in Storage, fetch from Firestore
    if (_currentMessageContext.isEmpty) {
      print('Local context is empty, fetching from Firestore...');
      final initialMessages = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('messages')
          .orderBy('timestamp', descending: false) // Order ascending for correct context flow
          .get();

      if (initialMessages.docs.isNotEmpty) {
        _currentMessageContext = initialMessages.docs
            .map((doc) {
          final data = doc.data();
          return '${data['sender']}: ${data['text']}';
        })
            .join('\n');
        // Once fetched from Firestore, immediately save to Storage
        await _updateContextInStorage();
        print('Initial context loaded from Firestore and saved to Storage.');
      } else {
        print('No messages found in Firestore to initialize context.');
      }
    } else {
      print('Context loaded from Storage.');
    }
    _isContextInitialized = true;
  }

  // New method to load the context from Firebase Storage
  Future<String> _loadMessageContextFromStorage() async {
    try {
      final contextRef = _storage.ref().child(
        'message_contexts/$_userId/context.txt',
      );
      final existingContextData = await contextRef.getData();
      if (existingContextData != null) {
        return String.fromCharCodes(existingContextData);
      }
    } catch (e) {
      print('No existing context file found in Storage for $_userId. This is normal for first run. Error: $e');
    }
    return '';
  }

  // Method to update the context in Firebase Storage
  Future<void> _updateContextInStorage() async {
    try {
      final contextRef = _storage.ref().child(
        'message_contexts/$_userId/context.txt',
      );
      await contextRef.putString(_currentMessageContext);
      print('Context updated in Storage.');
    } catch (e) {
      print("Error saving context to storage: $e");
    }
  }

  // Method to add a new message to the local context and update Storage
  Future<void> addMessageToContext(String sender, String text) async {
    final newMessage = '$sender: $text';
    if (_currentMessageContext.isEmpty) {
      _currentMessageContext = newMessage;
    } else {
      _currentMessageContext += '\n$newMessage';
    }
    print('Added to local context: $newMessage');

    // Always update Storage after adding a new message to keep it synchronized.
    await _updateContextInStorage();
  }

  // Modified _getMessageContext to simply return the local context
  // This is now a synchronous getter.
  String getMessageContext() {
    return _currentMessageContext;
  }

  /// Deletes all messages in the user's Firestore 'messages' subcollection
  /// and clears the local and Storage context.
  Future<void> deleteMessageContext() async {
    print('Attempting to delete message context...');
    try {
      // 1. Delete documents in Firestore messages subcollection
      final messagesCollection =
      _firestore.collection('users').doc(_userId).collection('messages');
      final snapshot = await messagesCollection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('Firestore messages collection cleared.');

      // 2. Delete the context file from Firebase Storage
      final contextRef = _storage.ref().child(
        'message_contexts/$_userId/context.txt',
      );
      try {
        await contextRef.delete();
        print('Storage context file deleted.');
      } catch (e) {
        // This can happen if the file doesn't exist, which is fine.
        print('No context file to delete in Storage or error deleting: $e');
      }

      // 3. Clear local context
      _currentMessageContext = '';
      _isContextInitialized = false; // Reset initialization flag
      print('Local context cleared. Context is now empty.');
    } catch (e) {
      print('Error deleting message context: $e');
      rethrow; // Re-throw to indicate failure to the caller
    }
  }


  Future<Map<String, dynamic>> _getUserProgress() async {
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final activeTasks = await _firestore
            .collection('tasks')
            .where('assigned_users', arrayContains: _userId)
            .where('state', arrayContains: 0)
            .get();

        final completedTasks = await _firestore
            .collection('tasks')
            .where('assigned_users', arrayContains: _userId)
            .where('state', arrayContains: 2)
            .get();

        return {
          'activeTasks': activeTasks.docs.map((doc) => doc.data()['task_name']).toList(),
          'completedTasks': completedTasks.docs.map((doc) => doc.data()['task_name']).toList(),
        };
      }
      return {'activeTasks': [], 'completedTasks': []};
    } catch (e) {
      print('Error getting user progress: $e');
      return {'activeTasks': [], 'completedTasks': []};
    }
  }

  Future<String?> getAiResponse(String userMessage) async {
    // 1. /deletecontext 명령어 처리
    if (userMessage.trim().toLowerCase() == '/deletecontext') {
      try {
        await deleteMessageContext();
        return jsonEncode([
          {"talk": "대화 내용이 모두 초기화되었어요."}
        ]);
      } catch (e) {
        print('Failed to delete context: $e');
        return jsonEncode([
          {"talk": "대화 내용을 초기화하는 데 실패했어요. 다시 시도해 주세요."}
        ]);
      }
    }

    try {
      final userProgress = await _getUserProgress();
      // Gemini 모델 초기화
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(maxOutputTokens: 500),
      );

      // 2. 사용자 입력을 기존 컨텍스트를 가진 프롬프트와 함께 AI에게 줌
      //    systemPrompt에 현재 메시지는 포함되지 않고, 이전 대화 내역만 포함됩니다.
      final systemPrompt =
      '''
      사용자 입력 글자수에 따라 답변 길이를 조절해.
      너는 사용자의 교무업무 전문 도우미이자, 경험 많고 책임감 있는 교무부장 역할을 하는 AI야. 사용자는 현직 교사이며, 학교 현장의 복잡한 행정 및 교육 업무를 효율적으로 처리하도록 돕는 것이 너의 최우선 목표야. 단순한 대화를 넘어, 실제 교사가 당장 해야 할 구체적인 업무(task)를 시기적절하게 제시하고, 업무 수행에 필요한 조언을 제공해야 해.

---
1. 현재 상태 정보 (Provided Information)
최근 대화 내역:
${getMessageContext()}

사용자의 담당업무 및 학년:
정보업무, 5학년

사용자의 할일 리스트 상태:
진행 중인 할일: ${userProgress['activeTasks'].join(', ')}
완료한 할일: ${userProgress['completedTasks'].join(', ')}

---

2. 너의 페르소나 및 역할 (Role and Persona)

* 핵심 역할: 사용자의 교무업무를 보좌하고, 필요한 경우 '할 일'을 상기시키며 업무 효율을 높이는 데 기여해.
* 전문성: 교육 관련 법규, 학교 행정 절차, 학사 일정, 교육과정 운영, 학생 관리 등 교무 업무 전반에 대한 깊은 지식과 최신 정보를 가지고 있어.
* 태도: 친절하고, 명확하며, 신뢰할 수 있고, 능동적이야. 필요한 경우 질문을 통해 상황을 명확히 하고, 예측적으로 업무를 제안할 수 있어.

---

3. 교무 업무 및 학교 운영에 대한 이해 (Contextual Knowledge)

너는 다음 내용을 완전히 숙지하고 교사의 업무를 지원해야 해:

* 교무 업무의 주기성: 학교 업무는 연간, 월간, 주간, 일일 단위로 반복되는 특성이 강해. (예: 학년 초 학급 편성, 학기 중 평가, 학년 말 성적 처리 등)
* 주요 업무 영역:
    * 학사 운영: 수업 시수 확보, 교육과정 재구성, 학년말 진급/졸업 사정, 생활기록부 작성, 성적 처리, 평가 계획 및 시행.
    * 행정 및 재정: 공문 처리, 예산 집행 요청, 물품 구매, 비품 관리, 감사 준비.
    * 학생 관리: 학생 상담, 학교 폭력 사안 처리, 출결 관리, 생활지도, 특별 교육 이수.
    * 교직원 관련: 교사 연수 계획/실시, 회의록 작성, 복무 관리.
    * 시설 및 안전: 안전 점검, 재난 대비 훈련, 환경 미화.
    * 정보 업무 (사용자 담당): 나이스(NEIS) 시스템 관리, 학교 홈페이지 관리, 정보기기 관리, 개인정보 보호 교육 및 관리, 정보통신 윤리 교육.
* 나이스(NEIS) 시스템의 중요성: 교무 업무의 핵심 시스템으로, 학적, 성적, 출결, 생활기록부, 교육과정, 인사, 복무 등 모든 행정 처리의 기반이 됨. 나이스를 통한 업무 처리는 정확성과 시기를 지키는 것이 매우 중요해.
* 공문의 중요성: 교육청 및 유관기관과의 소통 채널이자 업무 지시의 근거. 공문 처리 시 기한 엄수와 내용의 정확한 파악이 필수적임.
* 학부모 소통: 가정통신문, 학교운영위원회, 학부모 상담 등.
* 학년별 특성: 각 학년 담임 교사는 학생 지도, 기초 학력 지도, 진로 탐색, 체험학습, 등의 업무 특성을 고려해야 해. 

---

4. '할 일 (Task)' 제시 가이드라인

* 구체성: 추상적인 '열심히 해라'가 아닌, '무엇을', '언제까지', '어떻게' 해야 하는지 구체적인 업무 명을 제시해줘.
    * 나이스 관련 예시: "나이스 학생 생활기록부 수상경력 입력 마감", "나이스 학생 출결상황 최종 확인 및 마감"
    * 학사 관련 예시: "1학기 기말고사 평가 문제 출제 및 검토", "5학년 교육과정 재구성 계획서 작성"
    * 행정 관련 예시: "교실 환경 개선을 위한 물품 구매 계획서 제출"
* 실용성: 교사가 실제로 투두리스트에 추가하여 바로 행동할 수 있는 수준의 업무여야 해.
* 시기 적절성: 대화의 맥락, 사용자의 현재 상태(`activeTasks`, `completedTasks`), 그리고 학교의 일반적인 연간/월간 학사 일정을 고려하여 지금 시점에 중요한 업무를 제안해줘. (예: 학기말에는 성적 처리, 학년말에는 진급/졸업 사정 관련 업무)
* 우선순위: 긴급하거나 중요한 업무를 우선적으로 제안할 수 있도록 고려해.
* 추가 및 완료:
    * 새로운 업무를 제안할 때는 `"task": {"[새로운 퀘스트 내용]": false}` 형식으로, 아직 완료되지 않은 상태(`false`)로 제시해.
    * 사용자가 완료한 업무라고 판단되면, 해당 업무의 상태를 `"task": {"[완료된 퀘스트 내용]": true}`로 업데이트해서 제시해줘. 기존 퀘스트는 계속 표시해줘.
    * 한 번에 여러 개의 task를 제시할 수 있어.

---

5. 답변 형식 및 주의사항 (Response Format and Cautions)

다음의 json 형식에 맞춰서 답변해줘:
```json
[
  {"task": {"(퀘스트내용1)": false, "(퀘스트 내용2)": false}},
  {"talk": "너의 첫걸음을 응원할게!"}
]
주의사항:

talk: 상대방 말 길이에 비례하여 답변 길이를 조절해.(질문과 답변의 글자수가 거의 비슷하게 분량조절) 대화의 흐름을 부드럽게 이어가는 데 집중해.
task:
할일 제시가 필요한 상황(업무 관련 질문, 특정 시기, 업무 상기 필요 등)이 아니면 talk만 제공하고 task 필드는 포함하지 마.
할일 리스트를 보여줄 때는 진행 중인 activeTasks와 새로 제시하는 task를 모두 포함하여 보여줘. 사용자의 activeTasks와 completedTasks를 참고하여 지금 필요한 업무를 제시하거나, 이미 완료된 업무에 대한 언급은 피하거나 완료 상태로 제시해.
추가되는 할일은 0개가 될 수도 있고 여러 개가 될 수도 있어. 기본적으로 0개인데, 필요할 때만 제공해.
task 내용은 최대한 구체적인 교무 업무 용어를 사용해.

''';
      print("System Prompt sent to AI:\n${systemPrompt.toString()}"); // 디버깅을 위해 프롬프트 출력
      print('파이어베이스에서 컨텍스트 불러왔나요?: ${_isContextInitialized ? '네' : '아니요'}');

      // Gemini 모델의 history에는 systemPrompt만 포함하고, userMessage는 content로 별도 전달
      final chat = model.startChat(history: [Content.text(systemPrompt)]);
      var content = Content.text(userMessage); // 현재 사용자 입력

      var response = await chat.sendMessage(content); // AI에게 사용자 입력 전달
      final geminiResponseText = response.text!
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // 3. 사용자 입력을 메시지 컨텍스트에 추가
      await addMessageToContext('user', userMessage);

      // 4. AI 응답
      return geminiResponseText;
      // 5. AI 응답을 컨텍스트에 추가 ->AfterResponse()

    } catch (error) {
      print("Error fetching Ai response: $error");
      return null;
    }
  }
  void AfterResponse(var geminiResponseText) async {
    // This method can be used to perform any cleanup or final actions after getting a response
    print("Response processing completed.");
    try {
      final decodedResponse = jsonDecode(geminiResponseText) as List;
      final talkPart = decodedResponse.firstWhere(
            (item) => item.containsKey('talk'),
        orElse: () => null,
      );
      if (talkPart != null && talkPart['talk'] is String) {
        await addMessageToContext('Ai', talkPart['talk']);
      }
    } catch (e) {
      print("Error parsing Gemini response to add to context: $e");
      await addMessageToContext('Ai', geminiResponseText); // Fallback
    }

    print("AI Response received:\n$geminiResponseText");
  }
}