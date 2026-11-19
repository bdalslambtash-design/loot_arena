import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const LootArenaApp());
}

class LootArenaApp extends StatelessWidget {
  const LootArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ميدان الغنائم',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: const LobbyScreen(),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _bestWins = 0;
  int _botCount = 5;

  Future<void> _startMatch() async {
    final won = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(botCount: _botCount),
      ),
    );
    if (won == true && mounted) {
      setState(() => _bestWins++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF101820), Color(0xFF1E2D3D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.emoji_events, color: Colors.amber),
                        label: Text('الانتصارات: $_bestWins'),
                      ),
                      const Chip(
                        avatar: Icon(Icons.shield, color: Colors.lightBlueAccent),
                        label: Text('تكتيكي • أكشن'),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.gps_fixed, size: 72, color: Colors.amber),
                      const SizedBox(height: 12),
                      const Text(
                        'ميدان الغنائم',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ابقَ داخل المنطقة الآمنة، اجمع الذخيرة والصحة، واقضِ على الخصوم',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Text('عدد الخصوم في الساحة: $_botCount'),
                              Slider(
                                min: 3,
                                max: 10,
                                divisions: 7,
                                value: _botCount.toDouble(),
                                onChanged: (v) => setState(() => _botCount = v.round()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _startMatch,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ابدأ المعركة', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Fighter {
  Offset pos;
  double hp;
  double armor;
  int ammo;
  double angle;
  final bool isPlayer;
  int fireCooldown = 0;
  int aiTimer = 0;
  Offset aiDir = Offset.zero;

  Fighter({
    required this.pos,
    required this.isPlayer,
    this.hp = 100,
    this.armor = 50,
    this.ammo = 30,
    this.angle = 0,
  });

  bool get isAlive => hp > 0;
}

class Bullet {
  Offset pos;
  final Offset vel;
  final bool fromPlayer;
  int life = 45;

  Bullet({
    required this.pos,
    required this.vel,
    required this.fromPlayer,
  });
}

class LootCrate {
  final Offset pos;
  final bool isMedkit;
  bool collected = false;

  LootCrate({required this.pos, required this.isMedkit});
}

class BattleScreen extends StatefulWidget {
  final int botCount;
  const BattleScreen({super.key, required this.botCount});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const double mapSize = 1400;
  final Random _rng = Random();
  Timer? _timer;

  late Fighter _player;
  final List<Fighter> _bots = [];
  final List<Bullet> _bullets = [];
  final List<LootCrate> _crates = [];

  Offset _joystickDelta = Offset.zero;
  double _zoneRadius = 660;
  int _ticks = 0;
  bool _matchOver = false;
  bool _playerWon = false;

  @override
  void initState() {
    super.initState();
    _initMatch();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) => _step());
  }

  void _initMatch() {
    _player = Fighter(pos: const Offset(700, 700), isPlayer: true);
    _bots.clear();
    _bullets.clear();
    _crates.clear();

    for (int i = 0; i < widget.botCount; i++) {
      final angle = (2 * pi * i) / widget.botCount;
      final dist = 280 + _rng.nextDouble() * 240;
      _bots.add(
        Fighter(
          pos: Offset(700 + cos(angle) * dist, 700 + sin(angle) * dist),
          isPlayer: false,
          hp: 75,
          armor: 25,
          ammo: 999,
        ),
      );
    }

    for (int i = 0; i < 16; i++) {
      _crates.add(
        LootCrate(
          pos: Offset(150 + _rng.nextDouble() * 1100, 150 + _rng.nextDouble() * 1100),
          isMedkit: i.isEven,
        ),
      );
    }
  }

  void _shootFrom(Fighter shooter, double angle) {
    if (shooter.fireCooldown > 0 || shooter.ammo <= 0) return;
    if (shooter.isPlayer) shooter.ammo--;
    shooter.fireCooldown = shooter.isPlayer ? 6 : 22;
    const speed = 13.0;
    _bullets.add(
      Bullet(
        pos: shooter.pos + Offset(cos(angle) * 20, sin(angle) * 20),
        vel: Offset(cos(angle) * speed, sin(angle) * speed),
        fromPlayer: shooter.isPlayer,
      ),
    );
  }

  void _damageFighter(Fighter target, double dmg) {
    if (!target.isAlive) return;
    double rem = dmg;
    if (target.armor > 0) {
      final absorbed = min(target.armor, rem * 0.6);
      target.armor -= absorbed;
      rem -= absorbed;
    }
    target.hp -= rem;
    if (target.hp < 0) target.hp = 0;
  }

  void _step() {
    if (_matchOver || !mounted) return;
    _ticks++;

    if (_zoneRadius > 160 && _ticks % 4 == 0) {
      _zoneRadius -= 0.7;
    }

    if (_player.fireCooldown > 0) _player.fireCooldown--;

    if (_joystickDelta.distance > 0.05) {
      final norm = _joystickDelta / max(1.0, _joystickDelta.distance);
      _player.angle = atan2(norm.dy, norm.dx);
      _player.pos = Offset(
        (_player.pos.dx + norm.dx * 5.2).clamp(30, mapSize - 30),
        (_player.pos.dy + norm.dy * 5.2).clamp(30, mapSize - 30),
      );
    }

    const center = Offset(mapSize / 2, mapSize / 2);
    if ((_player.pos - center).distance > _zoneRadius && _ticks % 12 == 0) {
      _damageFighter(_player, 2.5);
    }

    for (final crate in _crates) {
      if (!crate.collected && (_player.pos - crate.pos).distance < 34) {
        crate.collected = true;
        if (crate.isMedkit) {
          _player.hp = min(100, _player.hp + 35);
          _player.armor = min(100, _player.armor + 35);
        } else {
          _player.ammo += 25;
        }
      }
    }

    for (final bot in _bots) {
      if (!bot.isAlive) continue;
      if (bot.fireCooldown > 0) bot.fireCooldown--;

      if (bot.aiTimer <= 0) {
        bot.aiTimer = 25 + _rng.nextInt(35);
        final distCenter = (bot.pos - center).distance;
        if (distCenter > _zoneRadius * 0.85) {
          final toCenter = center - bot.pos;
          final a = atan2(toCenter.dy, toCenter.dx);
          bot.aiDir = Offset(cos(a), sin(a));
        } else {
          final a = _rng.nextDouble() * 2 * pi;
          bot.aiDir = Offset(cos(a), sin(a));
        }
      } else {
        bot.aiTimer--;
      }

      bot.pos = Offset(
        (bot.pos.dx + bot.aiDir.dx * 3.0).clamp(30, mapSize - 30),
        (bot.pos.dy + bot.aiDir.dy * 3.0).clamp(30, mapSize - 30),
      );

      final toPlayer = _player.pos - bot.pos;
      final distPlayer = toPlayer.distance;
      if (distPlayer < 360 && _player.isAlive) {
        bot.angle = atan2(toPlayer.dy, toPlayer.dx);
        _shootFrom(bot, bot.angle);
      } else {
        bot.angle = atan2(bot.aiDir.dy, bot.aiDir.dx);
      }

      if ((bot.pos - center).distance > _zoneRadius && _ticks % 15 == 0) {
        _damageFighter(bot,
