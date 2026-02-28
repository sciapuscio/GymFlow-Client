import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<dynamic> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.get('${AppConstants.bookingsUrl}?action=list');
      setState(() {
        _reservations = data['reservations'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    final slotId   = r['slot_id'];
    final date     = r['class_date'];

    // Formatear la fecha para el diálogo
    String dateLabel = date as String? ?? '';
    try {
      final dateObj = DateTime.parse(dateLabel);
      const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final dow = dayNames[(dateObj.weekday - 1).clamp(0, 6)];
      final month = DateFormat('d MMM').format(dateObj);
      dateLabel = '$dow $month';
    } catch (_) {}

    // Detectar si ya pasó el cancel_deadline (penalidad)
    bool isLate = false;
    try {
      final deadlineStr = r['cancel_deadline'] as String?;
      if (deadlineStr != null) {
        final deadline = DateTime.parse(deadlineStr);
        isLate = DateTime.now().isAfter(deadline);
      }
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF14141E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isLate ? '⚠️ Cancelación tardía' : 'Cancelar reserva',
          style: const TextStyle(color: Color(0xFFF0F0F0)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cancelar la clase ${r['class_name'] ?? ''} del $dateLabel?',
              style: const TextStyle(color: Color(0xFF888888)),
            ),
            if (isLate) ...[ 
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1500),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF8C42).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Ya pasó el tiempo de cancelación sin penalidad. Quedará registrado como Ausente y no se restaurará tu crédito.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFF8C42)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              isLate ? 'Aceptar penalidad' : 'Sí, cancelar',
              style: TextStyle(color: isLate ? const Color(0xFFFF8C42) : const Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ApiClient.delete(
        '${AppConstants.bookingsUrl}?action=cancel&slot_id=$slotId&class_date=$date',
      );
      if (!mounted) return;
      final wasAbsent = res['absent'] == true;
      messenger.showSnackBar(SnackBar(
        content: Text(res['message'] as String? ?? (wasAbsent ? 'Marcado como ausente.' : 'Reserva cancelada.')),
        backgroundColor: wasAbsent ? const Color(0xFF3A2000) : const Color(0xFF1E1E28),
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFF1E1E28)),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E18),
        foregroundColor: const Color(0xFFF0F0F0),
        title: const Text('Mis reservas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (!_loading)
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF444444)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
                    TextButton(onPressed: _load, child: const Text('Reintentar')),
                  ]),
                )
              : _reservations.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF2A2A3A)),
                        const SizedBox(height: 14),
                        const Text('No tenés reservas próximas',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('Reservá clases desde la Grilla',
                            style: TextStyle(color: Color(0xFF444455), fontSize: 12)),
                      ]),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00F5D4),
                      backgroundColor: const Color(0xFF14141E),
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: _reservations.length,
                        itemBuilder: (_, i) {
                          final r = _reservations[i] as Map<String, dynamic>;
                          return _ReservationCard(reservation: r, onCancel: () => _cancel(r));
                        },
                      ),
                    ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Map<String, dynamic> reservation;
  final VoidCallback onCancel;
  const _ReservationCard({required this.reservation, required this.onCancel});

  Color _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return const Color(0xFF00F5D4);
    final code = int.tryParse(hex.substring(1), radix: 16);
    return code != null ? Color(0xFF000000 | code) : const Color(0xFF00F5D4);
  }

  @override
  Widget build(BuildContext context) {
    final status    = reservation['status'] as String? ?? 'reserved';
    final className = reservation['class_name'] as String? ?? 'Clase';
    final date      = reservation['class_date'] as String? ?? '';
    final time      = (reservation['class_time'] as String? ?? '').substring(0, 5);
    final sala      = reservation['sala_name'] as String?;
    final instructor = reservation['instructor_name'] as String?;
    final color     = _parseColor(reservation['color'] as String?);

    DateTime? dateObj;
    try { dateObj = DateTime.parse(date); } catch (_) {}

    // Build full class datetime by combining class_date + class_time
    DateTime? classDateTime;
    if (dateObj != null && time.length == 5) {
      try {
        final parts = time.split(':');
        classDateTime = DateTime(
          dateObj.year, dateObj.month, dateObj.day,
          int.parse(parts[0]), int.parse(parts[1]),
        );
      } catch (_) {}
    }

    // A reservation is "past" if the class datetime already happened
    final now = DateTime.now();
    final isPast = classDateTime != null
        ? now.isAfter(classDateTime)          // class already started
        : (dateObj != null && dateObj.isBefore(DateTime(now.year, now.month, now.day)));
    final isActive  = status == 'reserved' && !isPast;

    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    String dateLabel = date;
    if (dateObj != null) {
      final dow = dateObj.weekday - 1; // 0=Mon..6=Sun
      final day = dayNames[dow.clamp(0, 6)];
      final month = DateFormat('d MMM').format(dateObj);
      dateLabel = '$day $month';
    }

    // Estado visual
    final bool isAttended  = status == 'attended' || status == 'present';
    final bool isAbsent    = (isPast && status != 'cancelled' && !isAttended) || status == 'absent';
    final bool isCancelled = status == 'cancelled';

    // Color de la barra lateral según estado
    final Color barColor = isActive
        ? color
        : isAttended
            ? const Color(0xFF00F5D4)
            : isAbsent
                ? const Color(0xFFFF8C42)
                : const Color(0xFF2A2A2A);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isActive
            ? color.withOpacity(0.08)
            : isAttended
                ? const Color(0xFF001A15)
                : isAbsent
                    ? const Color(0xFF1A1108)
                    : const Color(0xFF111118),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.35)
              : isAttended
                  ? const Color(0xFF00F5D4).withOpacity(0.2)
                  : isAbsent
                      ? const Color(0xFFFF8C42).withOpacity(0.2)
                      : const Color(0xFF252530),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(className,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: isActive ? const Color(0xFFF0F0F0) : const Color(0xFF666666),
                          )),
                    ),
                    if (isAttended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002A20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 10, color: Color(0xFF00F5D4)),
                            SizedBox(width: 4),
                            Text('Presente',
                                style: TextStyle(fontSize: 10, color: Color(0xFF00F5D4))),
                          ],
                        ),
                      )
                    else if (isAbsent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1A0A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Ausente',
                            style: TextStyle(fontSize: 10, color: Color(0xFFFF8C42))),
                      )
                    else if (isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Cancelada',
                            style: TextStyle(fontSize: 10, color: Color(0xFF666666))),
                      ),
                    const SizedBox(width: 8),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: isActive ? color.withOpacity(0.8) : const Color(0xFF444444)),
                    const SizedBox(width: 5),
                    Text('${dateLabel[0].toUpperCase()}${dateLabel.substring(1)} · $time',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
                  ]),
                  if (sala != null || instructor != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [if (sala != null) sala, if (instructor != null) instructor].join(' · '),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
                onPressed: onCancel,
                tooltip: 'Cancelar reserva',
              ),
            ),
        ],
      ),
    );
  }
}
