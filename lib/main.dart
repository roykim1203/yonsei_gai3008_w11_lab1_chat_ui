import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());


class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6FE4),
        ),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}


/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser, this.error});

  final String text;
  final bool isUser;

  /// null이 아니면 오류 말풍선이다. 어떤 오류인지도 함께 보관한다.
  final ChatErrorKind? error;

  bool get isError => error != null;
}

/// 오류 종류 — 401/429/500/timeout을 하나의 "오류 상태"로 처리한다.
/// 안내 문구는 여기서만 정의해 Mock과 실제 API가 같은 문구를 쓴다.
enum ChatErrorKind {
  unauthorized(statusCode: 401, message: '키/권한을 확인해 주세요'),
  rateLimited(statusCode: 429, message: '잠시 후 다시 시도해 주세요'),
  server(statusCode: 500, message: '응답을 받지 못했습니다'),
  timeout(statusCode: null, message: '네트워크를 확인해 주세요');

  const ChatErrorKind({required this.statusCode, required this.message});

  final int? statusCode;
  final String message;

  /// 실제 HTTP 상태 코드를 오류 종류로 변환한다. (401/429 외에는 server)
  static ChatErrorKind fromStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
        return unauthorized;
      case 429:
        return rateLimited;
      default:
        return server;
    }
  }
}


/// 응답 실패를 나타내는 예외. Mock 응답과 실제 AI 응답이 같은 방식으로 던진다.
class ChatFailure implements Exception {
  const ChatFailure(this.kind, {this.cause});

  ChatFailure.fromStatusCode(int statusCode, {this.cause})
      : kind = ChatErrorKind.fromStatusCode(statusCode);

  const ChatFailure.timeout({this.cause}) : kind = ChatErrorKind.timeout;

  final ChatErrorKind kind;
  final Object? cause;

  String get message => kind.message;
  int? get statusCode => kind.statusCode;

  @override
  String toString() => 'ChatFailure(${kind.name}): $message';
}

/// 응답 생성 함수. Mock과 실제 API가 같은 시그니처를 쓴다.
typedef ChatReply = Future<String> Function(String text);

/// 실습용 Mock 응답. 정해진 횟수만큼 실패한 뒤 성공한다.
class MockChatReply {
  MockChatReply({
    this.failuresBeforeSuccess = 0,
    this.failure = const ChatFailure(ChatErrorKind.server),
    this.replyPrefix = 'Mock 응답입니다',
    this.delay = const Duration(milliseconds: 500),
  });

  final int failuresBeforeSuccess;
  final ChatFailure failure;
  final String replyPrefix;
  final Duration delay;

  int _calls = 0;

  Future<String> call(String text) async {
    await Future<void>.delayed(delay);
    _calls++;
    if (_calls <= failuresBeforeSuccess) {
      throw failure;
    }
    return '$replyPrefix: $text';
  }
}

/// 실습용 가짜 대화 — API를 붙이기 전까지 이 목록으로 화면을 만든다.
const List<ChatMessage> _defaultMessages = [
  ChatMessage(text: '오늘 뭐 배워?', isUser: true),
  ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
  ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
  ChatMessage(
    text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.',
    isUser: false,
  ),
];

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.initialMessages = _defaultMessages,
    this.reply,
  });

  final List<ChatMessage> initialMessages;

  /// 응답 함수. null이면 내장 Mock 응답을 쓴다.
  final ChatReply? reply;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final List<ChatMessage> _messages =
      List<ChatMessage>.of(widget.initialMessages);

  final TextEditingController _controller = TextEditingController();

  late final ChatReply _reply = widget.reply ?? _defaultReply;

  /// 요청 처리 중이면 true — 중복 전송/재시도를 막는다.
  bool _isSending = false;

  /// 실패한 사용자 메시지. 재시도할 때 그대로 다시 보낸다.
  String? _failedText;

  /// 재시도 처리 중이면 true — 오류 말풍선이 스피너를 보여 준다.
  bool _isRetrying = false;

  /// 마지막 실패의 종류. 429에서만 백오프를 적용한다.
  ChatErrorKind? _failedKind;

  /// 429 백오프 횟수 — 대기 시간은 1초, 2초, 4초(최대)로 늘어난다.
  int _retryAttempt = 0;

  /// 대기 중이면 남은 시간(초)을 담아 안내 문구로 보여 준다.
  int? _backoffSeconds;

  static Future<String> _defaultReply(String text) =>
      Future<String>.value('Mock 응답입니다: $text');

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    _retryAttempt = 0;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
    });

    await _requestReply(text);
  }

  /// 429일 때만 지수 백오프(1s → 2s → 4s)를 돌려준다.
  Duration? _backoffDelay() {
    if (_failedKind != ChatErrorKind.rateLimited) {
      return null;
    }
    final seconds = 1 << _retryAttempt;
    return Duration(seconds: seconds > 4 ? 4 : seconds);
  }

  Future<void> _requestReply(String text) async {
    if (_isSending) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final reply = await _reply(text);
      if (!mounted) {
        return;
      }
      setState(() {
        _failedText = null;
        _failedKind = null;
        _retryAttempt = 0;
        // 재시도가 성공하면 기존 오류 말풍선을 걷어낸다.
        if (_isRetrying) {
          _messages.removeWhere((message) => message.isError);
        }
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } on ChatFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failedText = text;
        _failedKind = failure.kind;
        _messages.removeWhere((message) => message.isError);
        _messages.add(
          ChatMessage(
            text: failure.message,
            isUser: false,
            error: failure.kind,
          ),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failedText = text;
        _failedKind = ChatErrorKind.server;
        _messages.removeWhere((message) => message.isError);
        _messages.add(
          ChatMessage(
            text: ChatErrorKind.server.message,
            isUser: false,
            error: ChatErrorKind.server,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _retry() async {
    final text = _failedText;
    if (text == null || _isSending || _isRetrying) {
      return;
    }

    final delay = _backoffDelay();

    // 오류 말풍선은 그대로 두고 스피너(또는 대기 안내)로 전환한다.
    setState(() {
      _isRetrying = true;
      _backoffSeconds = delay?.inSeconds;
    });

    try {
      if (delay != null) {
        await Future<void>.delayed(delay);
        if (!mounted) {
          return;
        }
        _retryAttempt++;
        setState(() => _backoffSeconds = null);
      }
      await _requestReply(text);
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _backoffSeconds = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 할 일 5 — 키보드가 입력창을 가리지 않게
      //    · Scaffold의 resizeToAvoidBottomInset은 기본값(true)이 키보드 높이만큼
      //      body를 줄여 주므로 별도 설정 없이 그대로 둔다.
      //    · body를 SafeArea로 감싸 홈 인디케이터와 노치를 피한다.
      //    · 목록은 Expanded + ListView라 화면이 줄어도 스크롤로 동작하고,
      //      입력창은 Column의 마지막 자식이라 항상 화면 하단에 붙는다.
      appBar: AppBar(title: const Text('AI Chat — 실습 1')),
      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 4 — 빈 상태
            //    ListView를 Stack으로 감싸고, 목록이 비었을 때만
            //    Center(child: Text('무엇이든 물어보세요'))를 위에 띄운다.
            // ─────────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          _messages[_messages.length - 1 - index];
                      return _Bubble(
                        message: message,
                        onRetry: message.isError &&
                                _failedText != null &&
                                !_isSending &&
                                !_isRetrying
                            ? _retry
                            : null,
                        isRetrying: message.isError && _isRetrying,
                        backoffSeconds:
                            message.isError ? _backoffSeconds : null,
                      );
                    },
                  ),
                  if (_messages.isEmpty)
                    const Center(
                      child: Text('무엇이든 물어보세요'),
                    ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────
            // TODO 3 — 입력창 (TextField + 전송 버튼)
            // TIP:
            //  · final _controller = TextEditingController(); 를 State에 둔다.
            //  · Row(children: [Expanded(TextField(...)), IconButton.filled(...)])
            //  · TextField(textInputAction: TextInputAction.send,
            //             onSubmitted: (_) => _send())
            //  · 보낼 때 _controller.clear() 하고 setState로 목록에 추가한다.
            //  · dispose()에서 _controller.dispose()를 잊지 않는다.
            // ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    tooltip: '전송',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────
/// TODO 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
///
/// 지금은 글자만 보이는 상자다. 다음을 채워 넣자.
///
/// TIP:
///  · Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft)
///  · Container(
///      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
///      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
///      constraints: BoxConstraints(maxWidth: 420),
///      decoration: BoxDecoration(
///        color: isUser ? colorScheme.primaryContainer
///                      : colorScheme.surfaceContainerHighest,
///        borderRadius: BorderRadius.circular(14),
///      ),
///    )
///  · 색은 Theme.of(context).colorScheme에서 꺼내면 다크 모드에서도 안전하다.
///  · 긴 글은 자동으로 줄바꿈된다. maxWidth만 잡아 주면 된다.
/// ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.onRetry,
    this.isRetrying = false,
    this.backoffSeconds,
  });

  final ChatMessage message;

  /// 오류 말풍선에서만 쓰인다. null이면 "다시 시도" 버튼은 비활성.
  final VoidCallback? onRetry;

  /// 재시도 처리 중이면 버튼 대신 스피너를 보여 준다.
  final bool isRetrying;

  /// 429 대기 중이면 "N초 후 다시 시도" 안내를 보여 준다.
  final int? backoffSeconds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    if (message.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.error!.message,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: backoffSeconds != null
                    ? Padding(
                        key: const ValueKey('backoff'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$backoffSeconds초 후 다시 시도',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isRetrying
                        ? Padding(
                            key: const ValueKey('retrying'),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          )
                        : TextButton.icon(
                            key: const ValueKey('retry'),
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('다시 시도'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onErrorContainer,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
