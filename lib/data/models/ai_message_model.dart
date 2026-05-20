class AIMessageModel {
  final String id;
  final int userId;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;

  // ── New fields from Autism Chatbot API v4.1.0 ──
  final String? categoryLabel;
  final String? urgency;
  final bool needsClarification;
  final String? clarificationQuestion;

  const AIMessageModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.error,
    this.categoryLabel,
    this.urgency,
    this.needsClarification = false,
    this.clarificationQuestion,
  });

  // Factory constructor from JSON
  factory AIMessageModel.fromJson(Map<String, dynamic> json) {
    return AIMessageModel(
      id: json['id'] as String,
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: json['is_loading'] as bool? ?? false,
      error: json['error'] as String?,
      categoryLabel: json['category_label'] as String?,
      urgency: json['urgency'] as String?,
      needsClarification: json['needs_clarification'] as bool? ?? false,
      clarificationQuestion: json['clarification_question'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'is_loading': isLoading,
      'error': error,
      'category_label': categoryLabel,
      'urgency': urgency,
      'needs_clarification': needsClarification,
      'clarification_question': clarificationQuestion,
    };
  }

  // CopyWith method
  AIMessageModel copyWith({
    String? id,
    int? userId,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
    String? categoryLabel,
    String? urgency,
    bool? needsClarification,
    String? clarificationQuestion,
  }) {
    return AIMessageModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      urgency: urgency ?? this.urgency,
      needsClarification: needsClarification ?? this.needsClarification,
      clarificationQuestion: clarificationQuestion ?? this.clarificationQuestion,
    );
  }

  // Helper methods
  bool get isAI => !isUser;
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isUrgent => urgency == 'high' || urgency == 'urgent';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIMessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AIMessageModel(id: $id, isUser: $isUser, content: ${content.length} chars, urgency: $urgency)';
  }
}
