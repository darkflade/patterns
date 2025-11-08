class ChatMessage {
  final String sender;
  final String role;
  final String text;

  ChatMessage({required this.sender, required this.role, required this.text});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      role: json['role'] as String,
      text: json['text'] as String,
    );
  }
}
