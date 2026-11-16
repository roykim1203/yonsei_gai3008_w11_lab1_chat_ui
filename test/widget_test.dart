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
}
