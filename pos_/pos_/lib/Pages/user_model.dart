class User {
  final String username;
  final String role;

  User({required this.username, required this.role});

  // This function takes the "JSON" from the API and turns it into a User object
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      role: json['role'],
    );
  }
}