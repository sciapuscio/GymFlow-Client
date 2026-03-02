import 'dart:convert';

/// A gym account saved locally for multi-account switching.
class SavedAccount {
  final String token;
  final String memberName;
  final String gymName;
  final String gymSlug;
  final String? gymLogoUrl;
  final String env; // "dev" | "prod"
  final bool isActive;

  const SavedAccount({
    required this.token,
    required this.memberName,
    required this.gymName,
    required this.gymSlug,
    this.gymLogoUrl,
    this.env = 'prod',
    this.isActive = false,
  });

  SavedAccount copyWith({
    String? token,
    String? memberName,
    String? gymName,
    String? gymSlug,
    String? gymLogoUrl,
    String? env,
    bool? isActive,
  }) =>
      SavedAccount(
        token: token ?? this.token,
        memberName: memberName ?? this.memberName,
        gymName: gymName ?? this.gymName,
        gymSlug: gymSlug ?? this.gymSlug,
        gymLogoUrl: gymLogoUrl ?? this.gymLogoUrl,
        env: env ?? this.env,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'member_name': memberName,
        'gym_name': gymName,
        'gym_slug': gymSlug,
        'gym_logo_url': gymLogoUrl,
        'env': env,
        'is_active': isActive,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        token: j['token'] as String,
        memberName: j['member_name'] as String? ?? '',
        gymName: j['gym_name'] as String? ?? '',
        gymSlug: j['gym_slug'] as String? ?? '',
        gymLogoUrl: j['gym_logo_url'] as String?,
        env: j['env'] as String? ?? 'prod',
        isActive: j['is_active'] as bool? ?? false,
      );

  static List<SavedAccount> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<SavedAccount> accounts) =>
      jsonEncode(accounts.map((a) => a.toJson()).toList());
}
