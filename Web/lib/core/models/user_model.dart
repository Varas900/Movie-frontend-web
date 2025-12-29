// Model simplified to remove codegen and subscription types
class User {
  final int userId;
  
  final String userName;
  final String? firstName;
  final String? lastName;
  final String name;
  final String email;
  final String? password;
  final UserRole role;
  final UserStatus status;
  final String? avatar;
  final String? profilePicture;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final String? address;
  final String? bio;
  final bool? isEmailVerified;
  final String createdAt;
  final String? lastLogin;
  final String? lastActiveAt;
  final bool? isOnline;
  final String? timeZone;
  final String? displayName;

  const User({
    required this.userId,
    required this.userName,
    this.firstName,
    this.lastName,
    required this.name,
    required this.email,
    this.password,
    required this.role,
    required this.status,
    this.avatar,
    this.profilePicture,
    this.phone,
    this.displayName,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.bio,
    this.isEmailVerified,
    required this.createdAt,
    this.lastLogin,
    this.lastActiveAt,
    this.isOnline,
    this.timeZone,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        userId: json['userID'] as int? ?? json['userId'] as int? ?? 0,
        userName: json['userName'] as String? ?? '',
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String?,
        role: _roleFromString(json['role'] as String? ?? 'User'),
        status: _statusFromString(json['status'] as String? ?? 'Active'),
        avatar: json['avatar'] as String?,
        profilePicture: json['profilePicture'] as String?,
        phone: json['phone'] as String?,
        displayName: json['displayName'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        gender: json['gender'] as String?,
        address: json['address'] as String?,
        bio: json['bio'] as String?,
        isEmailVerified: json['isEmailVerified'] as bool?,
        createdAt: json['createdAt'] as String? ?? '',
        lastLogin: json['lastLogin'] as String?,
        lastActiveAt: json['lastActiveAt'] as String?,
        isOnline: json['isOnline'] as bool?,
        timeZone: json['timeZone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'userID': userId,
        'userName': userName,
        'firstName': firstName,
        'lastName': lastName,
        'name': name,
        'email': email,
        'password': password,
        'role': _roleToString(role),
        'status': _statusToString(status),
        'avatar': avatar,
        'profilePicture': profilePicture,
        'phone': phone,
        'displayName': displayName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'address': address,
        'bio': bio,
        'isEmailVerified': isEmailVerified,
        'createdAt': createdAt,
        'lastLogin': lastLogin,
        'lastActiveAt': lastActiveAt,
        'isOnline': isOnline,
        'timeZone': timeZone,
      };

  User copyWith({
    int? userId,
    String? userName,
    String? firstName,
    String? lastName,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    UserStatus? status,
    String? avatar,
    String? profilePicture,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? address,
    String? bio,
    bool? isEmailVerified,
    String? createdAt,
    String? lastLogin,
    String? lastActiveAt,
    bool? isOnline,
    String? timeZone,
  }) {
    return User(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      profilePicture: profilePicture ?? this.profilePicture,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      timeZone: timeZone ?? this.timeZone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  String get fullDisplayName => displayName ?? (name.isNotEmpty ? name : userName);
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : userName[0].toUpperCase();
  }
  
  // Subscription-related getters removed
}


enum UserRole {
  admin,
  manager,
  moderator,
  user,
}

enum UserStatus {
  active,
  inactive,
}

UserRole _roleFromString(String value) {
  switch (value.toLowerCase()) {
    case 'admin':
      return UserRole.admin;
    case 'manager':
      return UserRole.manager;
    case 'moderator':
      return UserRole.moderator;
    default:
      return UserRole.user;
  }
}

String _roleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.moderator:
      return 'Moderator';
    case UserRole.user:
      return 'User';
  }
}

UserStatus _statusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'inactive':
      return UserStatus.inactive;
    case 'active':
    default:
      return UserStatus.active;
  }
}

String _statusToString(UserStatus status) {
  switch (status) {
    case UserStatus.active:
      return 'Active';
    case UserStatus.inactive:
      return 'Inactive';
  }
}

// Subscription types removed