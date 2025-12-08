class ChatMessage {
  final String sender;
  final String role;
  final String type;
  final String content;

  ChatMessage({
    required this.sender,
    required this.role,
    required this.type,
    required this.content,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      role: json['role'] as String,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? (json['text'] as String? ?? ''),
    );
  }
}

class UserStatus {
  final String username;
  String role;
  bool isInCall;

  UserStatus({
    required this.username,
    required this.role,
    this.isInCall = false,
  });
}
