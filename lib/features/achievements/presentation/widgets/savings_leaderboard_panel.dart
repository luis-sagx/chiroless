import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/savings_leaderboard_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/savings_leaderboard_service.dart';

class SavingsLeaderboardPanel extends StatefulWidget {
  final String userId;
  final SavingsLeaderboardService? service;
  final DateTime Function()? now;
  const SavingsLeaderboardPanel({
    super.key,
    required this.userId,
    this.service,
    this.now,
  });
  @override
  State<SavingsLeaderboardPanel> createState() =>
      _SavingsLeaderboardPanelState();
}

class _SavingsLeaderboardPanelState extends State<SavingsLeaderboardPanel>
    with WidgetsBindingObserver {
  late SavingsLeaderboardService _service;
  final _alias = TextEditingController();
  StreamSubscription<List<SavingsEntry>>? _rankingSubscription;
  StreamSubscription<SavingsParticipation>? _profileSubscription;
  Timer? _rollover;
  String _month = '';
  List<SavingsEntry>? _entries;
  SavingsParticipation? _profile;
  bool _busy = false;
  int _generation = 0;
  final Set<String> _errors = {};
  String? _actionError;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? SavingsLeaderboardService();
    _listen();
    _rollover = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkMonth(),
    );
  }

  @override
  void didUpdateWidget(covariant SavingsLeaderboardPanel old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.service != widget.service) {
      _service = widget.service ?? SavingsLeaderboardService();
      _listen();
    }
  }

  void _checkMonth() {
    if (SavingsLeaderboardRules.monthKey(_now) != _month) setState(_listen);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkMonth();
  }

  void _listen() {
    _generation++;
    _busy = false;
    _actionError = null;
    _rankingSubscription?.cancel();
    _profileSubscription?.cancel();
    _month = SavingsLeaderboardRules.monthKey(_now);
    _entries = null;
    _profile = null;
    _errors.clear();
    _alias.clear();
    final uid = widget.userId;
    final month = _month;
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    _rankingSubscription = _service
        .watchMonth(month)
        .listen(
          (entries) {
            if (current()) {
              setState(() {
                _entries = entries;
                _errors.remove('ranking');
              });
            }
          },
          onError: (Object error) {
            if (current()) setState(() => _errors.add('ranking'));
          },
        );
    _profileSubscription = _service
        .watchParticipation(uid)
        .listen(
          (profile) {
            if (current()) {
              setState(() {
                _profile = profile;
                _errors.remove('profile');
              });
            }
          },
          onError: (Object error) {
            if (current()) setState(() => _errors.add('profile'));
          },
        );
  }

  Future<void> _change({required bool join}) async {
    final uid = widget.userId;
    final month = _month;
    final generation = _generation;
    final service = _service;
    bool current() => mounted && generation == _generation;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      if (join) {
        await service.participate(uid, _alias.text);
        if (!current()) return;
        await service.synchronizeMonth(uid, month, isCurrent: current);
      } else {
        await service.withdraw(uid);
      }
    } catch (error) {
      if (current()) {
        setState(
          () => _actionError = error is ArgumentError
              ? 'Elige un alias de 2 a 24 caracteres.'
              : 'No pudimos actualizar tu participación. Intenta de nuevo.',
        );
      }
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _rollover?.cancel();
    _rankingSubscription?.cancel();
    _profileSubscription?.cancel();
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries ?? <SavingsEntry>[];
    final rank = SavingsLeaderboardRules.rankOf(entries, widget.userId);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ahorradores del mes',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(_month, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tu ahorro como porcentaje de tus ingresos. Cada mes es una nueva oportunidad.',
          ),
          const SizedBox(height: 6),
          const Text(
            'Basado en movimientos registrados',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No pudimos actualizar la clasificación. Los datos anteriores se conservan.',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ],
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _actionError!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
          const SizedBox(height: 16),
          if (_entries == null && _errors.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_entries != null && entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Sé parte del primer podio de este mes. Aún no hay participantes con ingresos registrados.',
                ),
              ),
            ),
          if (entries.isNotEmpty) ...[
            _podium(context, entries.take(3).toList()),
            const SizedBox(height: 12),
            if (_profile?.enabled == true)
              Card(
                color: AppTheme.secondaryColor.withValues(alpha: .18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rank > 0
                        ? 'Tu posición: $rank'
                        : 'Tu posición está pendiente. Registra ingresos del mes para calcular tu porcentaje.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ...entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: entry.userId == widget.userId
                      ? AppTheme.secondaryColor
                      : AppTheme.borderColor,
                  child: Text(
                    '${SavingsLeaderboardRules.rankOf(entries, entry.userId)}',
                  ),
                ),
                title: Text(entry.alias, overflow: TextOverflow.ellipsis),
                subtitle: entry.userId == widget.userId
                    ? const Text('Tú')
                    : null,
                trailing: Text(
                  '${entry.savingsPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: entry.savingsPercent < 0
                        ? AppTheme.expenseColor
                        : AppTheme.incomeColor,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_profile == null && _errors.contains('profile'))
            const Text(
              'No pudimos cargar tu participación. Vuelve a abrir Ahorradores.',
            ),
          if (_profile != null && _profile!.enabled) ...[
            Text(
              'Participas como ${_profile!.alias}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (rank == 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Para aparecer en el ranking necesitas ingresos registrados este mes. Tu saldo inicial no cuenta.',
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => _change(join: false),
              child: const Text('Retirar mi participación'),
            ),
          ] else if (_profile != null) ...[
            const Text(
              'Participar es opcional. Solo compartes tu alias y porcentaje; tus importes y movimientos permanecen privados.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _alias,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: 'Tu alias público',
                hintText: 'Elige un apodo',
                border: OutlineInputBorder(),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _change(join: true),
              child: Text(_busy ? 'Guardando…' : 'Participar en Ahorradores'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Los empates comparten posición. Un porcentaje negativo indica que gastaste más de lo que ingresaste.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _podium(BuildContext context, List<SavingsEntry> entries) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5D6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (entry) => Expanded(
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: const [
                      Color(0xFFE5A800),
                      Color(0xFF8292A2),
                      Color(0xFFB87945),
                    ][entries.indexOf(entry)],
                    size: entries.indexOf(entry) == 0 ? 44 : 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${entry.savingsPercent.toStringAsFixed(2)}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}
