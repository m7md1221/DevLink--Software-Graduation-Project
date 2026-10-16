class PostImage {
  final int id;
  final String url;

  PostImage({required this.id, required this.url});

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      id: json['id'] ?? 0,
      url: json['url'] ?? '',
    );
  }
}

class PostModel {
  final int id;
  final int userId;
  final String authorName;
  final String? authorImage;
  final String authorType;
  final String? content;
  final DateTime createdAt;
  final int imageCount;
  final int likeCount;
  final int commentCount;
  final int applicationsCount;
  final bool isClosed;
  bool isLikedByMe;
  final bool isMine;
  final List<PostImage> images;

  PostModel({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorImage,
    required this.authorType,
    this.content,
    required this.createdAt,
    required this.imageCount,
    required this.likeCount,
    required this.commentCount,
    required this.applicationsCount,
    required this.isClosed,
    required this.isLikedByMe,
    required this.isMine,
    required this.images,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      authorName: json['authorName'] ?? 'User',
      authorImage: json['authorImage'],
      authorType: json['authorType'] ?? 'Customer',
      content: json['content'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      imageCount: json['imageCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      applicationsCount: json['applicationsCount'] ?? 0,
      isClosed: json['isClosed'] == true,
      isLikedByMe: json['isLikedByMe'] == true,
      isMine: json['isMine'] == true,
      images: (json['images'] as List? ?? [])
          .map((e) => PostImage.fromJson(e))
          .toList(),
    );
  }
}

class CommentModel {
  final int id;
  final int postId;
  final int userId;
  final String authorName;
  final String? authorImage;
  final String authorType;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    this.authorImage,
    required this.authorType,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? 0,
      postId: json['postId'] ?? 0,
      userId: json['userId'] ?? 0,
      authorName: json['authorName'] ?? 'User',
      authorImage: json['authorImage'],
      authorType: json['authorType'] ?? 'Customer',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class UserSearchResult {
  final int userId;
  final String email;
  final String nickname;
  final String userType;
  final String? specialty;
  final bool hasImage;
  final String? avatarUrl;

  UserSearchResult({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.userType,
    this.specialty,
    required this.hasImage,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      userId: json['userId'] ?? 0,
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? 'User',
      userType: json['userType'] ?? '',
      specialty: json['specialty'],
      hasImage: json['hasImage'] == true,
      avatarUrl: json['avatarUrl'],
    );
  }
}

class UserPublicProfile {
  final int userId;
  final String email;
  final String userType;
  final String nickname;
  final String? country;
  final String? city;
  final String? phoneNumber;
  final String? specialty;
  final String? university;
  final String? linkedInUrl;
  final dynamic rating;
  final bool? isVerified;
  final bool hasImage;
  final String? avatarUrl;
  final int postCount;
  final DateTime? createdAt;

  UserPublicProfile({
    required this.userId,
    required this.email,
    required this.userType,
    required this.nickname,
    this.country,
    this.city,
    this.phoneNumber,
    this.specialty,
    this.university,
    this.linkedInUrl,
    this.rating,
    this.isVerified,
    required this.hasImage,
    this.avatarUrl,
    required this.postCount,
    this.createdAt,
  });

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    return UserPublicProfile(
      userId: json['userId'] ?? 0,
      email: json['email'] ?? '',
      userType: json['userType'] ?? '',
      nickname: json['nickname'] ?? 'User',
      country: json['country'],
      city: json['city'],
      phoneNumber: json['phoneNumber'],
      specialty: json['specialty'],
      university: json['university'],
      linkedInUrl: json['linkedInUrl'],
      rating: json['rating'],
      isVerified: json['isVerified'] == true,
      hasImage: json['hasImage'] == true,
      avatarUrl: json['avatarUrl'],
      postCount: json['postCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
    );
  }
}

class PostApplicationModel {
  final int id;
  final int postId;
  final int programmerId;
  final String programmerName;
  final String? programmerSpecialty;
  final dynamic programmerRating;
  final bool programmerIsVerified;
  final bool programmerHasImage;
  final String? programmerAvatarUrl;
  final String email;
  final String proposal;
  final dynamic price;
  final String? duration;
  final String status;
  final DateTime createdAt;

  PostApplicationModel({
    required this.id,
    required this.postId,
    required this.programmerId,
    required this.programmerName,
    this.programmerSpecialty,
    required this.programmerRating,
    required this.programmerIsVerified,
    required this.programmerHasImage,
    this.programmerAvatarUrl,
    required this.email,
    required this.proposal,
    this.price,
    this.duration,
    required this.status,
    required this.createdAt,
  });

  factory PostApplicationModel.fromJson(Map<String, dynamic> json) {
    return PostApplicationModel(
      id: json['id'] ?? 0,
      postId: json['postId'] ?? 0,
      programmerId: json['programmerId'] ?? 0,
      programmerName: json['programmerName'] ?? 'User',
      programmerSpecialty: json['programmerSpecialty'],
      programmerRating: json['programmerRating'],
      programmerIsVerified: json['programmerIsVerified'] == true,
      programmerHasImage: json['programmerHasImage'] == true,
      programmerAvatarUrl: json['programmerAvatarUrl'],
      email: json['email'] ?? '',
      proposal: json['proposal'] ?? '',
      price: json['price'],
      duration: json['duration'],
      status: json['status'] ?? 'Pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}