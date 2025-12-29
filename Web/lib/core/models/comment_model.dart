class Comment {
  final int commentID;
  final int movieID;
  final int userID;
  final String? userName;
  final String content;
  final int? parentID;
  final bool isEdited;
  final int? likeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Comment({
    required this.commentID,
    required this.movieID,
    required this.userID,
    this.userName,
    required this.content,
    this.parentID,
    required this.isEdited,
    this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      commentID: (json['commentID'] as num?)?.toInt() ?? 0,
      movieID: (json['movieID'] as num?)?.toInt() ?? 0,
      userID: (json['userID'] as num?)?.toInt() ?? 0,
      userName: json['userName'] as String?,
      content: json['content'] as String? ?? '',
      parentID: (json['parentID'] as num?)?.toInt(),
      isEdited: json['isEdited'] as bool? ?? false,
      likeCount: (json['likeCount'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
