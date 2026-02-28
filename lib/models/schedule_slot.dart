import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Represents a member's reservation on a specific slot/date.
class SlotReservation {
  final int id;
  final String classDate;
  final String status; // 'reserved', 'cancelled', etc.

  const SlotReservation({
    required this.id,
    required this.classDate,
    required this.status,
  });

  factory SlotReservation.fromJson(Map<String, dynamic> json) => SlotReservation(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        classDate: json['class_date'] as String,
        status: json['status'] as String,
      );
}

/// ScheduleSlot — mirrors the enriched row returned by member-schedules.php
class ScheduleSlot {
  final int id;
  final int dayOfWeek;      // 0=Sun .. 6=Sat
  final String startTime;   // "HH:MM:SS"
  final String endTime;
  final String? className;
  final String? salaName;
  final String? sedeName;
  final int? sedeId;
  final String? instructorName;
  final String? color;      // hex e.g. "#00f5d4"
  final int? capacity;      // null = unlimited
  final String nextDate;    // "YYYY-MM-DD" of next occurrence
  final int bookedCount;    // active reservations for nextDate
  final SlotReservation? myReservation; // null if not booked

  const ScheduleSlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.className,
    this.salaName,
    this.sedeName,
    this.sedeId,
    this.instructorName,
    this.color,
    this.capacity,
    required this.nextDate,
    required this.bookedCount,
    this.myReservation,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        dayOfWeek: json['day_of_week'] is int
            ? json['day_of_week']
            : int.parse(json['day_of_week'].toString()),
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        className: json['class_name'] as String?,
        salaName: json['sala_name'] as String?,
        sedeName: json['sede_name'] as String?,
        sedeId: json['sede_id'] != null
            ? (json['sede_id'] is int ? json['sede_id'] : int.tryParse(json['sede_id'].toString()))
            : null,
        instructorName: json['instructor_name'] as String?,
        color: json['color'] as String?,
        capacity: json['capacity'] != null
            ? (json['capacity'] is int
                ? json['capacity']
                : int.parse(json['capacity'].toString()))
            : null,
        nextDate: json['next_date'] as String? ?? '',
        bookedCount: json['booked_count'] is int
            ? json['booked_count']
            : int.parse((json['booked_count'] ?? '0').toString()),
        myReservation: json['my_reservation'] != null
            ? SlotReservation.fromJson(
                json['my_reservation'] as Map<String, dynamic>)
            : null,
      );

  String get displayTime {
    final s = startTime.substring(0, 5);
    final e = endTime.substring(0, 5);
    return '$s – $e';
  }

  String get dayName => AppConstants.weekDays[dayOfWeek];

  bool get isBooked =>
      myReservation != null && myReservation!.status == 'reserved';

  bool get isPresent =>
      myReservation != null && myReservation!.status == 'present';

  bool get isFull => capacity != null && bookedCount >= capacity!;

  int get spotsLeft => capacity != null ? (capacity! - bookedCount) : 999;

  Color get slotColor {
    if (color != null && color!.startsWith('#') && color!.length == 7) {
      final hex = int.tryParse(color!.substring(1), radix: 16);
      if (hex != null) return Color(0xFF000000 | hex);
    }
    return const Color(0xFF00F5D4);
  }
}
