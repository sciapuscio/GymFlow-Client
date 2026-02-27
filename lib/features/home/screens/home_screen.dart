import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../models/portal_block.dart';
import '../../schedule/screens/my_reservations_screen.dart';

// ── Data class for portal response ───────────────────────────────────────────
class _PortalData {
  final List<PortalBlock> blocks;
  final Map<String, dynamic>? membership;
  final Map<String, dynamic>? nextClass;

  const _PortalData({
    required this.blocks,
    this.membership,
    this.nextClass,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _PortalData? _portal;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPortal();
    // Also refresh member data on every Home visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPortal() async {
    if (!mounted) return;
    setState(() {
      _loading = _portal == null; // only show full loader on first load
      _error = null;
    });
    try {
      final data = await ApiClient.get(
        '${AppConstants.gymPortalUrl}?action=blocks',
      );
      if (!mounted) return;
      final rawBlocks = data['blocks'] as List<dynamic>? ?? [];
      setState(() {
        _portal = _PortalData(
          blocks: rawBlocks
              .map((e) => PortalBlock.fromJson(e as Map<String, dynamic>))
              .toList(),
          membership: data['membership'] as Map<String, dynamic>?,
          nextClass: data['next_class'] as Map<String, dynamic>?,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadPortal(),
      context.read<AuthProvider>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;

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
              // ── Compact header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _CompactHeader(member: member),
              ),

              // ── Stats bar ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _StatsBar(
                  portal: _portal,
                  onDetailTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyReservationsScreen(),
                    ),
                  ),
                ),
              ),

              // ── Separator ───────────────────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Loading / Error / Blocks ─────────────────────────────────
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: GFColors.accent),
                  ),
                )
              else if (_error != null && (_portal?.blocks.isEmpty ?? true))
                SliverFillRemaining(
                  child: _ErrorState(onRetry: _loadPortal),
                )
              else if (_portal != null && _portal!.blocks.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final block = _portal!.blocks[i];
                      return block.isImage
                          ? _ImageBlock(block: block)
                          : _RichTextBlock(block: block);
                    },
                    childCount: _portal!.blocks.length,
                  ),
                )
              else
                SliverFillRemaining(
                  child: _EmptyPortal(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact Header ─────────────────────────────────────────────────────────
class _CompactHeader extends StatelessWidget {
  final dynamic member; // Member or null

  const _CompactHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    final initials = member?.name.isNotEmpty == true
        ? member!.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    final gymLogoUrl = context.watch<AuthProvider>().gymLogoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          // Gym logo or GymFlow wordmark
          gymLogoUrl != null
              ? _GymLogoHeader(logoUrl: gymLogoUrl)
              : const Text(
                  'GymFlow',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: GFColors.accent,
                    letterSpacing: -0.5,
                  ),
                ),
          const Spacer(),
          // Avatar
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [GFColors.accent, Color(0xFF00BFFF)],
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

// ── Gym Logo in Header ────────────────────────────────────────────────────────
class _GymLogoHeader extends StatelessWidget {
  final String logoUrl;
  const _GymLogoHeader({required this.logoUrl});

  String get _resolvedUrl => logoUrl.startsWith('http')
      ? logoUrl
      : '${AppConstants.baseUrl}/$logoUrl';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Image.network(
        _resolvedUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'GymFlow',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: GFColors.accent,
            letterSpacing: -0.5,
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          // While loading, show a subtle shimmer placeholder
          return Container(
            width: 80,
            height: 34,
            decoration: BoxDecoration(
              color: GFColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          );
        },
      ),
    );
  }
}

// ── (Resto de widgets sin cambios) ────────────────────────────────────────────
// _StatsBar, _StatCell, _Divider, _ImageBlock, _RichTextBlock, _EmptyPortal, _ErrorState

// ── Stats Bar ────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final _PortalData? portal;
  final VoidCallback onDetailTap;

  const _StatsBar({required this.portal, required this.onDetailTap});

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final d = DateFormat('yyyy-MM-dd').parse(isoDate);
      return DateFormat('dd/MM/yy').format(d);
    } catch (_) {
      return isoDate;
    }
  }

  String _creditsLabel(Map<String, dynamic>? ms) {
    if (ms == null) return '—';
    final cr = ms['credits_remaining'];
    return cr == null ? '∞' : '$cr';
  }

  String _nextClassLabel(Map<String, dynamic>? nc) {
    if (nc == null) return 'Sin reservas';
    final date = nc['class_date'] as String?;
    final time = nc['class_time'] as String?;
    if (date == null) return 'Sin reservas';
    try {
      final d = DateFormat('yyyy-MM-dd').parse(date);
      final today = DateTime.now();
      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
      final tomorrow = today.add(const Duration(days: 1));
      final isTomorrow = d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day;
      final dayStr = isToday ? 'Hoy' : isTomorrow ? 'Mañana' : DateFormat('EEE d/M', 'es').format(d);
      return '$dayStr ${time ?? ''}';
    } catch (_) {
      return '$date ${time ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ms = portal?.membership;
    final nc = portal?.nextClass;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: GFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                _StatCell(
                  label: 'Vencimiento',
                  value: _formatDate(ms?['end_date'] as String?),
                  icon: Icons.calendar_today_outlined,
                  iconColor: ms == null
                      ? GFColors.textMuted
                      : ((ms['days_left'] as int? ?? 999) <= 5
                          ? const Color(0xFFF59E0B)
                          : GFColors.accent),
                ),
                const _Divider(),
                _StatCell(
                  label: 'Créditos',
                  value: _creditsLabel(ms),
                  icon: Icons.bolt_outlined,
                  iconColor: GFColors.accent,
                ),
                const _Divider(),
                _StatCell(
                  label: 'Próximo turno',
                  value: _nextClassLabel(nc),
                  flex: 2,
                  icon: Icons.fitness_center_outlined,
                  iconColor: const Color(0xFF00BFFF),
                ),
              ],
            ),
          ),
          // "Ver detalle" link
          GestureDetector(
            onTap: onDetailTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1A1A2A))),
              ),
              child: const Text(
                'Ver mis reservas →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GFColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final int flex;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: GFColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: GFColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: double.infinity,
      color: const Color(0xFF1A1A2A),
    );
  }
}

// ── Image Block ───────────────────────────────────────────────────────────────
class _ImageBlock extends StatelessWidget {
  final PortalBlock block;
  const _ImageBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              block.content,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: GFColors.surface,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: GFColors.textMuted, size: 40),
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: GFColors.surface,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: GFColors.accent, strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                block.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GFColors.textMuted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Rich Text Block ───────────────────────────────────────────────────────────
class _RichTextBlock extends StatelessWidget {
  final PortalBlock block;
  const _RichTextBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GFColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Html(
        data: block.content,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: GFColors.textPrimary,
            fontSize: FontSize(14),
          ),
          'a': Style(color: GFColors.accent),
          'strong': Style(
            color: GFColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          'h1': Style(
            color: GFColors.textPrimary,
            fontSize: FontSize(20),
            fontWeight: FontWeight.w800,
          ),
          'h2': Style(
            color: GFColors.textPrimary,
            fontSize: FontSize(17),
            fontWeight: FontWeight.w700,
          ),
          'h3': Style(
            color: GFColors.accent,
            fontSize: FontSize(14),
            fontWeight: FontWeight.w700,
          ),
          'p': Style(margin: Margins.only(bottom: 8)),
          'ul': Style(margin: Margins.only(bottom: 8)),
          'li': Style(color: GFColors.textPrimary),
        },
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────
class _EmptyPortal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: GFColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Sin contenido todavía',
              style: TextStyle(
                color: GFColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'El staff del gimnasio\naún no publicó nada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF555566), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 44, color: GFColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar',
              style: TextStyle(
                  color: GFColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tirá hacia abajo para reintentar.',
              style: TextStyle(color: GFColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GFColors.surface,
                foregroundColor: GFColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
