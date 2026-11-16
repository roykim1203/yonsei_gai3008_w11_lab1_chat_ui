import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3이 끝났다면 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    // 할 일 4 — 메시지가 있으므로 빈 상태 문구는 보이지 않는다
    expect(find.text('무엇이든 물어보세요'), findsNothing);
  });

  testWidgets('메시지가 없으면 빈 상태 안내 문구가 보인다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('빈 상태에서 첫 메시지를 보내면 안내 문구가 사라진다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatPage(initialMessages: [])),
    );

    expect(find.text('무엇이든 물어보세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '첫 질문');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('무엇이든 물어보세요'), findsNothing);
    expect(find.text('첫 질문'), findsOneWidget);
  });

  testWidgets('전송하면 사용자 말풍선이 추가되고 입력창이 비워진다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '  안녕하세요  ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 앞뒤 공백이 제거된 메시지가 말풍선으로 추가된다
    expect(find.text('안녕하세요'), findsOneWidget);

    // 기존 가짜 대화는 그대로 남아 있다
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);
    expect(find.text('AI 챗봇에 움직이는 응답을 붙입니다.'), findsOneWidget);

    // 입력창은 비워진다
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('공백만 입력하면 전송되지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    final before = find.byType(Text).evaluate().length;

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byType(Text).evaluate().length, before);
  });

  testWidgets('Enter 키로도 전송된다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    await tester.enterText(find.byType(TextField), '엔터로 보내기');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('엔터로 보내기'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 입력창이 보이고 레이아웃 오류가 없다',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChatLabApp());

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final sendRect = tester.getRect(find.byIcon(Icons.send));
    expect(sendRect.bottom, lessThanOrEqualTo(480.0));
  });

  testWidgets('키보드가 올라와도 입력창이 화면 안에 남는다',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChatLabApp());

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 키보드가 차지한 300px 위쪽에 입력창이 있어야 한다
    final sendRect = tester.getRect(find.byIcon(Icons.send));
    expect(sendRect.bottom, lessThanOrEqualTo(500.0));
    expect(sendRect.top, greaterThanOrEqualTo(0.0));
  });

  testWidgets('오류 말풍선은 종류별 문구를 왼쪽에 표시한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(
          initialMessages: [
            ChatMessage(
              text: '',
              isUser: false,
              error: ChatErrorKind.unauthorized,
            ),
            ChatMessage(
              text: '',
              isUser: false,
              error: ChatErrorKind.rateLimited,
            ),
            ChatMessage(text: '', isUser: false, error: ChatErrorKind.server),
            ChatMessage(text: '', isUser: false, error: ChatErrorKind.timeout),
          ],
        ),
      ),
    );

    expect(find.text('키/권한을 확인해 주세요'), findsOneWidget);
    expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);
    expect(find.text('네트워크를 확인해 주세요'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(4));
    expect(find.text('다시 시도'), findsNWidgets(4));

    // AI 메시지처럼 왼쪽에 붙는다
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final rect = tester.getRect(find.text('키/권한을 확인해 주세요'));
    expect(rect.center.dx, lessThan(screenWidth / 2));
  });

  testWidgets('오류 말풍선이 있어도 메시지를 보낼 수 있다',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(
          initialMessages: [
            ChatMessage(text: '', isUser: false, error: ChatErrorKind.server),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '오류 뒤 입력');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('오류 뒤 입력'), findsOneWidget);
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);
  });

  testWidgets('실패하면 오류 말풍선이 남고 재시도 성공 시 AI 응답으로 바뀐다',
      (WidgetTester tester) async {
    final mock = MockChatReply(failuresBeforeSuccess: 1);
    await tester.pumpWidget(MaterialApp(home: ChatPage(reply: mock.call)));

    await tester.enterText(find.byType(TextField), '질문');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 사용자 말풍선 1개 + 왼쪽 오류 말풍선
    expect(find.text('질문'), findsOneWidget);
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 오류는 사라지고 AI 응답이 추가되며, 사용자 메시지는 중복되지 않는다
    expect(find.text('응답을 받지 못했습니다'), findsNothing);
    expect(find.textContaining('Mock 응답입니다'), findsOneWidget);
    expect(find.text('질문'), findsOneWidget);
  });

  testWidgets('재시도가 다시 실패하면 오류 말풍선이 다시 보인다',
      (WidgetTester tester) async {
    final mock = MockChatReply(failuresBeforeSuccess: 2);
    await tester.pumpWidget(MaterialApp(home: ChatPage(reply: mock.call)));

    await tester.enterText(find.byType(TextField), '질문');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);
    expect(find.text('질문'), findsOneWidget);
  });

  testWidgets('요청 처리 중에는 중복 전송이 막힌다', (WidgetTester tester) async {
    final completer = Completer<String>();
    Future<String> reply(String text) => completer.future;

    await tester.pumpWidget(MaterialApp(home: ChatPage(reply: reply)));

    await tester.enterText(find.byType(TextField), '한 번만');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '두 번째');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('한 번만'), findsOneWidget);
    expect(find.text('두 번째'), findsNothing);

    completer.complete('응답');
    await tester.pump();
  });

  testWidgets('재시도 중에는 스피너가 보이고 버튼이 사라진다',
      (WidgetTester tester) async {
    final mock = MockChatReply(failuresBeforeSuccess: 1);
    await tester.pumpWidget(MaterialApp(home: ChatPage(reply: mock.call)));

    await tester.enterText(find.byType(TextField), '질문');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('응답을 받지 못했습니다'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // AnimatedSwitcher로 버튼이 스피너로 바뀐다
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('응답을 받지 못했습니다'), findsNothing);
    expect(find.textContaining('Mock 응답입니다'), findsOneWidget);
    expect(find.text('질문'), findsOneWidget);
  });

  testWidgets('429는 재시도마다 1초 → 2초 기다린 뒤 성공한다',
      (WidgetTester tester) async {
    final mock = MockChatReply(
      failuresBeforeSuccess: 2,
      failure: const ChatFailure(ChatErrorKind.rateLimited),
    );
    await tester.pumpWidget(MaterialApp(home: ChatPage(reply: mock.call)));

    await tester.enterText(find.byType(TextField), '질문');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);

    // 1차 재시도 — 1초 대기 안내
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1초 후 다시 시도'), findsOneWidget);

    // 1초 대기 + 0.5초 Mock 응답 → 다시 429
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);

    // 2차 재시도 — 2초 대기 안내
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2초 후 다시 시도'), findsOneWidget);

    // 2초 대기 + 0.5초 Mock 응답 → 성공
    await tester.pump(const Duration(milliseconds: 2300));

    expect(find.text('잠시 후 다시 시도해 주세요'), findsNothing);
    expect(find.textContaining('Mock 응답입니다'), findsOneWidget);
    expect(find.text('질문'), findsOneWidget);
  });

  testWidgets('401·500·timeout 오류에는 백오프가 없다', (WidgetTester tester) async {
    for (final kind in [
      ChatErrorKind.unauthorized,
      ChatErrorKind.server,
      ChatErrorKind.timeout,
    ]) {
      final mock = MockChatReply(
        failuresBeforeSuccess: 1,
        failure: ChatFailure(kind),
      );
      await tester.pumpWidget(MaterialApp(home: ChatPage(reply: mock.call)));

      await tester.enterText(find.byType(TextField), kind.name);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('초 후 다시 시도'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
