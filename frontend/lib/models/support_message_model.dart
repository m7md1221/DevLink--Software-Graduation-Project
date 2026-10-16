class SupportMessageModel {
  final int id;
  final int? userId;
  final String? userName;
  final String? userType;
  final String name;
  final String email;
  final String subject;
  final String message;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;
  final DateTime? readAt;

  SupportMessageModel({
    required this.id,
    this.userId,
    this.userName,
    this.userType,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
    this.readAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] ?? 0,
      userId: json['userId'],
      userName: json['userName'],
      userType: json['userType'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'New',
      adminReply: json['adminReply'],
      repliedAt: json['repliedAt'] != null
          ? DateTime.tryParse(json['repliedAt'])
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'])
          : null,
    );
  }

  bool get isNew => status == 'New';
  bool get isReplied => status == 'Replied';
  bool get isRead => status == 'Read';
}