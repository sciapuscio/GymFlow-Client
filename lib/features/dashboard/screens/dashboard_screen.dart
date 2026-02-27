import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../../core/constants.dart';
import '../../../models/member.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnim =
        CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refresh();
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    _progressController.reset();
    await context.read<AuthProvider>().refresh();
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;

    return Scaffold(
      backgroundColor: GFColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: GFColors.accent,
          backgroundColor: GFColors.surface,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DashHeader(member: member),
              ),
              if (auth.loadingMember && member == null)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: GFColors.accent),
                  ),
                )
              else if (member == null)
                const SliverFillRemaining(
                  child: _NoMemberState(),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _MembershipCard(
                    member: member,
                    progressAnim: _progressAnim,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StatsGrid(member: member),
                ),
                SliverToBoxAdapter(
                  child: _QuickActions(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard Header ──────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final Member? member;
  const _DashHeader({required this.member});

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _todayLabel() {
    final now = DateTime.now();
    // weekday: 1=Lunes..7=Domingo; AppConstants.weekDays[0]=Domingo
    final wd = AppConstants.weekDays[now.weekday % 7];
    return '$wd ${now.day} de ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final initials = member?.name.isNotEmpty == true
        ? member!.name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '\u00a1Buenos\u00a0d\u00edas'
        : hour < 19
            ? '\u00a1Buenas\u00a0tardes'
            : '\u00a1Buenas\u00a0noches';
    final firstName = member?.name.split(' ').first ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $firstName!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: GFColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _todayLabel(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: GFColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [GFColors.accent, Color(0xFF00BFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: GFColors.bg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Membership Hero Card ──────────────────────────────────────────────────────
class _MembershipCard extends StatelessWidget {
  final Member member;
  final Animation<double> progressAnim;

  const _MembershipCard({required this.member, required this.progressAnim});

  @override
  Widget build(BuildContext context) {
    final ms = member.membership;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: ms != null && ms.isActive
              ? const LinearGradient(
                  colors: [Color(0xFF0D1F2D), Color(0xFF0A1628)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF1A0A0A), Color(0xFF200D0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: ms != null
                ? ms.statusColor.withValues(alpha: 0.35)
                : const Color(0xFF3A1515),
          ),
          boxShadow: [
            BoxShadow(
              color: (ms?.statusColor ?? const Color(0xFF333355))
                  .withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ms == null
              ? _NoMembershipContent()
              : _ActiveMembershipContent(ms: ms, progressAnim: progressAnim),
        ),
      ),
    );
  }
}

class _NoMembershipContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1010),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.card_membership_outlined,
              color: Color(0xFFEF4444), size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sin membres\u00eda activa',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Contact\u00e1 al staff para activar tu plan.',
                style: TextStyle(color: GFColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveMembershipContent extends StatelessWidget {
  final Membership ms;
  final Animation<double> progressAnim;

  const _ActiveMembershipContent(
      {required this.ms, required this.progressAnim});

  @override
  Widget build(BuildContext context) {
    final daysLeft = ms.daysUntilExpiry.clamp(0, 9999);
    final creditsLeft = ms.creditsRemaining;
    final isUnlimited = creditsLeft == null;
    final usageRatio = ms.usageRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ms.statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.fitness_center_rounded,
                  color: ms.statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ms.planName ?? 'Membres\u00eda',
                    style: const TextStyle(
                      color: GFColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ms.isActive ? 'Vigente' : 'Vencida',
                    style: TextStyle(
                      color: ms.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ms.statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ms.statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '$daysLeft',
                    style: TextStyle(
                      color: ms.statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'd\u00edas',
                    style: TextStyle(
                      color: ms.statusColor.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            _DateItem(
              label: 'Inicio',
              date: ms.startDate,
              icon: Icons.play_circle_outline,
            ),
            const Spacer(),
            _DateItem(
              label: 'Vencimiento',
              date: ms.endDate,
              icon: Icons.event_outlined,
              alignRight: true,
              color: daysLeft <= 5
                  ? const Color(0xFFF59E0B)
                  : GFColors.textPrimary,
            ),
          ],
        ),

        if (!isUnlimited) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Clases usadas',
                style: TextStyle(color: GFColors.textMuted, fontSize: 12),
              ),
              Text(
                '${ms.sessionsUsed} / ${ms.sessionsLimit}',
                style: const TextStyle(
                    color: GFColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: progressAnim,
              builder: (_, __) {
                return LinearProgressIndicator(
                  value: (usageRatio * progressAnim.value).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: const Color(0xFF1A1A2E),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usageRatio > 0.8
                        ? const Color(0xFFEF4444)
                        : usageRatio > 0.5
                            ? const Color(0xFFF59E0B)
                            : GFColors.accent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$creditsLeft clases restantes',
            style: TextStyle(
              color: creditsLeft <= 2
                  ? const Color(0xFFEF4444)
                  : GFColors.textMuted,
              fontSize: 11,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.all_inclusive_rounded,
                  color: GFColors.accent.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 6),
              const Text(
                'Clases ilimitadas',
                style: TextStyle(color: GFColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DateItem extends StatelessWidget {
  final String label;
  final DateTime date;
  final IconData icon;
  final bool alignRight;
  final Color color;

  const _DateItem({
    required this.label,
    required this.date,
    required this.icon,
    this.alignRight = false,
    this.color = GFColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignRight) ...[
              Icon(icon, size: 12, color: GFColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(color: GFColors.textMuted, fontSize: 11),
            ),
            if (alignRight) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 12, color: GFColors.textMuted),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('dd/MM/yyyy').format(date),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final Member member;
  const _StatsGrid({required this.member});

  @override
  Widget build(BuildContext context) {
    final ms = member.membership;
    final creditsLeft = ms?.creditsRemaining;
    final isUnlimited = ms != null && creditsLeft == null;

    final items = [
      _StatItem(
        label: 'Clases tomadas',
        value: ms != null ? '${ms.sessionsUsed}' : '\u2014',
        icon: Icons.fitness_center_outlined,
        color: GFColors.accent,
      ),
      _StatItem(
        label: 'Cr\u00e9ditos restantes',
        value: isUnlimited ? '\u221e' : (creditsLeft != null ? '$creditsLeft' : '\u2014'),
        icon: Icons.bolt_outlined,
        color: const Color(0xFF00BFFF),
      ),
      _StatItem(
        label: 'D\u00edas restantes',
        value: ms != null ? '${ms.daysUntilExpiry.clamp(0, 9999)}' : '\u2014',
        icon: Icons.timer_outlined,
        color: ms != null && ms.daysUntilExpiry <= 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFF8B5CF6),
      ),
      _StatItem(
        label: 'Estado de pago',
        value: ms != null
            ? (ms.paymentStatus == 'paid'
                ? 'Al d\u00eda'
                : ms.paymentStatus == 'pending'
                    ? 'Pendiente'
                    : ms.paymentStatus)
            : '\u2014',
        icon: ms?.paymentStatus == 'paid'
            ? Icons.check_circle_outline
            : Icons.pending_outlined,
        color: ms?.paymentStatus == 'paid'
            ? GFColors.accent
            : const Color(0xFFF59E0B),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: items,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: GFColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: GFColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Accesos r\u00e1pidos',
              style: TextStyle(
                color: GFColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Ver Horario',
                  icon: Icons.calendar_today_outlined,
                  color: GFColors.accent,
                  onTap: () => context.go('/schedule'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Mis Reservas',
                  icon: Icons.bookmark_outline,
                  color: const Color(0xFF00BFFF),
                  onTap: () => context.go('/my-reservations'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: GFColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── No member state ───────────────────────────────────────────────────────────
class _NoMemberState extends StatelessWidget {
  const _NoMemberState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: GFColors.textMuted),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar tu perfil',
              style: TextStyle(
                color: GFColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tir\u00e1 hacia abajo para reintentar.',
              style: TextStyle(color: Color(0xFF555566), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
