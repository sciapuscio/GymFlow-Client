import 'package:flutter/material.dart';

/// Gym branding data returned by the API
class GymInfo {
  final String name;
  final String? logoPath;
  final String? primaryColor;
  final String? secondaryColor;

  const GymInfo({
    required this.name,
    this.logoPath,
    this.primaryColor,
    this.secondaryColor,
  });

  factory GymInfo.fromJson(Map<String, dynamic> json) => GymInfo(
        name: json['name'] as String,
        logoPath: json['logo_path'] as String?,
        primaryColor: json['primary_color'] as String?,
        secondaryColor: json['secondary_color'] as String?,
      );
}

/// Member model — matches the `memberPayload` shape returned by member-auth.php
class Member {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? qrToken;
  final Membership? membership;
  final GymInfo? gym;

  const Member({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.qrToken,
    this.membership,
    this.gym,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        qrToken: json['qr_token'] as String?,
        membership: json['membership'] != null
            ? Membership.fromJson(json['membership'] as Map<String, dynamic>)
            : null,
        gym: json['gym'] != null
            ? GymInfo.fromJson(json['gym'] as Map<String, dynamic>)
            : null,
      );
}

/// Membership model — mirrors `member_memberships` row
class Membership {
  final int id;
  final String? planName;
  final DateTime startDate;
  final DateTime endDate;
  final int sessionsUsed;
  final int? sessionsLimit; // null = unlimited
  final String paymentStatus;

  const Membership({
    required this.id,
    this.planName,
    required this.startDate,
    required this.endDate,
    required this.sessionsUsed,
    this.sessionsLimit,
    required this.paymentStatus,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        id: json['id'] as int,
        planName: json['plan_name'] as String?,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        sessionsUsed: int.parse(json['sessions_used'].toString()),
        sessionsLimit: json['sessions_limit'] != null
            ? int.parse(json['sessions_limit'].toString())
            : null,
        paymentStatus: json['payment_status'] as String? ?? 'pending',
      );

  bool get isActive => endDate.isAfter(DateTime.now());

  int? get creditsRemaining =>
      sessionsLimit != null ? sessionsLimit! - sessionsUsed : null;

  double get usageRatio {
    if (sessionsLimit == null || sessionsLimit == 0) return 0.0;
    return (sessionsUsed / sessionsLimit!).clamp(0.0, 1.0);
  }

  int get daysUntilExpiry => endDate.difference(DateTime.now()).inDays;

  Color get statusColor {
    if (!isActive) return const Color(0xFFEF4444);
    if (daysUntilExpiry <= 5) return const Color(0xFFF59E0B);
    return const Color(0xFF00F5D4);
  }
}
