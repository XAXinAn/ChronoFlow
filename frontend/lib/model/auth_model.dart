class User {
  final int id;
  final String username;
  final String email;
  final String phone;

  User({required this.id, required this.username, required this.email, required this.phone});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int userId;
  final String username;
  final String nickname;
  final String email;
  final String phone;
  final bool riskRequired;
  final String? riskType;
  final String? riskToken;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.userId,
    required this.username,
    required this.nickname,
    required this.email,
    required this.phone,
    this.riskRequired = false,
    this.riskType,
    this.riskToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      riskRequired: json['riskRequired'] ?? false,
      riskType: json['riskType'],
      riskToken: json['riskToken'],
    );
  }

  bool get isRiskRequired => riskRequired == true;
}

class RegisterResponse {
  final int id;
  final String username;
  final String nickname;
  final String phone;

  RegisterResponse({
    required this.id,
    required this.username,
    required this.nickname,
    required this.phone,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}