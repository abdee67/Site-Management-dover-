class User {
  final int id;
  final String username;
  final String password;
  // other fields...

  User({
    required this.id,
    required this.username,
    required this.password,
    // ...
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      // ...
    );
  }
}