import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fourthirty/firebase_options.dart';
import 'package:fourthirty/screens/auth/loginpage.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fourthirty/mainuipage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Firebase 초기화
  //FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  // Firestore 캐시 설정 (옵션)

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'ko_KR';

    return FutureBuilder<bool>(
        future: _getAutoLoginStatus(),
        builder: (context, snapshot) {
          bool autoLogin = snapshot.data ?? false;

    return MaterialApp(
              debugShowCheckedModeBanner: false,
      theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF776B5D), // DatePicker 헤더의 배경색
                onPrimary: Colors.white, // DatePicker 헤더의 텍스트 색상
                surface: Color(0xFFF9F1E9), // DatePicker 배경색
                onSurface: Colors.black, // DatePicker 텍스트 색상
              ),
              // 앱의 주 색상을 설정합니다.
              primaryColor: const Color(0xFF776B5D),
              // 예시: 앱 바의 배경색 등에 사용

              // 앱 바 테마 설정

              appBarTheme: const AppBarTheme(
                color: Color(0xFFF9F1E9), // 앱 바의 배경색
              ),

              // 플로팅 액션 버튼 테마 설정
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFCEAB93), // 플로팅 액션 버튼의 배경색
                // 기타 플로팅 액션 버튼 테마 설정
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFdDbB93), // 버튼 배경색
                  foregroundColor: const Color(0xFF111111), // 버튼 텍스트 색상
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // 모서리 둥글게
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0), // 버튼 패딩
                  // 기타 스타일 설정...
                ),
              ),

              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF111111), // 버튼 텍스트 색상
                  // backgroundColor: Color(0xFFB0A695), // 버튼 배경색
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // 모서리 둥글게
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0), // 버튼 패딩
                  // 기타 스타일 설정...
                ),
              ),
              indicatorColor: const Color(0xFFE3CAA5),

              // 슬라이더 테마 설정
              sliderTheme: const SliderThemeData(
                activeTrackColor: Color(0xFFE3CAA5),
                inactiveTrackColor: Color(0xFFF1DEC9),
                // 기타 슬라이더 테마 설정
              ),

              // 체크박스 테마 설정
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.all(const Color(0xFF9F8C76)),
                // 기타 체크박스 테마 설정
              ),

              // 카드 테마 설정
              cardTheme: const CardTheme(
                color: Color(0xFFF9F1E9), // 카드의 배경색
                // 기타 카드 테마 설정
              ),

              dialogTheme: const DialogTheme(
                backgroundColor: Color(0xFFF9F1E9), // 대화상자 배경색
                titleTextStyle: TextStyle(
                    color: Color(0xFF473B2D), // 대화상자 제목 텍스트 색상
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold // 제목 텍스트 크기
                    ),
                contentTextStyle: TextStyle(
                  color: Color(0xFF706655), // 대화상자 내용 텍스트 색상
                  fontSize: 16.0, // 내용 텍스트 크기
                ),
              ),

              // RaisedButton 테마 설정
              buttonTheme: ButtonThemeData(
                buttonColor: const Color(0xFFCEAB93), // 버튼 배경색
                textTheme: ButtonTextTheme.normal, // 버튼 텍스트 테마
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), // 모서리 둥글게
                ),
              ),
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: Color(0xFF473B2D), // 여기서 커서 색상 지정
                // 기타 텍스트 선택과 관련된 설정...
              ),

              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,

                labelStyle: TextStyle(
                  color: Color(0xFF533A15), // 라벨 텍스트 스타일
                ),
                hintStyle: TextStyle(
                  color: Color(0xFF614E39), // 힌트 텍스트 스타일
                ),
                // 기타 스타일 설정...
              ),

              // 기타 테마 설정...
            ),
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              // ... app-specific localization delegate(s) here
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              //const Locale('en', 'US'),
              Locale('ko', 'KO'),
            ],
            home: autoLogin ?  const MainUiPage(): LoginPage(),
    );
        });
  }

  Future<bool> _getAutoLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_login') ?? false;
  }
}
