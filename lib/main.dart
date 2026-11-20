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
        scaffoldBackgroundColor: const Color(0xFF0E141B),
      ),
      home: const ArenaScreen(),
    );
  }
}

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  final Random _rng = Random();
  Timer? _loopTimer;

  Size _arenaSize = const Size(380, 520);
  double _zoneRadius = 240;
  int _round = 1;
  int _score = 0;
  int _kills = 0;
  int _tickCount = 0;
  bool _matchOver = false;
  bool _roundWon = false;
  String _statusText = 'الجولة 1 - استعد للمواجهة';
  Offset _moveDir = Offset.zero;
  bool _isFiring = false;
  int _rapidFireTicks = 0;
  int _dashCooldown = 0;

  late Fighter _player;
  final List<Fighter> _bots = [];
  final List<Bullet> _bullets = [];
  final List<LootItem> _lootDrops = [];
  final List<CoverBlock> _obstacles = [];
  final List<HitSpark> _sparks = [];

  @override
  void initState() {
    super.initState();
    _initMatch(resetProgress: true);
    _startLoop();
  }

  void _initMatch({required bool resetProgress}) {
    if (resetProgress) {
      _round = 1;
      _score = 0;
      _kills = 0;
    }

    final center = Offset(_arenaSize.width / 2, _arenaSize.height / 2);
    _zoneRadius = min(_arenaSize.width, _arenaSize.height) * 0.47;
    _tickCount = 0;
    _matchOver = false;
    _roundWon = false;
    _isFiring = false;
    _rapidFireTicks = 0;
    _dashCooldown = 0;
    _statusText = 'الجولة $_round - استعد للتحرك!';

    _player = Fighter(
      pos: center,
      angle: 0,
      hp: 100,
      maxHp: 100,
      shield: 60,
      isAlive: true,
      isPlayer: true,
    );

    _bots.clear();
    _bullets.clear();
    _lootDrops.clear();
    _obstacles.clear();
    _sparks.clear();

    // توزيع السواتر حسب رقم الجولة لتنويع ساحات القتال
    final layoutType = _round % 3;
    if (layoutType == 1) {
      _obstacles.addAll([
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(-78, -68), width: 54, height: 34),
          isSandbag: false,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(78, -68), width: 54, height: 34),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(-78, 68), width: 54, height: 34),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(78, 68), width: 54, height: 34),
          isSandbag: false,
        ),
      ]);
    } else if (layoutType == 2) {
      _obstacles.addAll([
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(0, -88), width: 72, height: 28),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(0, 88), width: 72, height: 28),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(-92, 0), width: 28, height: 72),
          isSandbag: false,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(92, 0), width: 28, height: 72),
          isSandbag: false,
        ),
      ]);
    } else {
      _obstacles.addAll([
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(-65, -75), width: 46, height: 46),
          isSandbag: false,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(65, -75), width: 46, height: 46),
          isSandbag: false,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(-65, 75), width: 46, height: 46),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(65, 75), width: 46, height: 46),
          isSandbag: true,
        ),
        CoverBlock(
          rect: Rect.fromCenter(center: center + const Offset(0, -115), width: 44, height: 24),
          isSandbag: true,
        ),
      ]);
    }

    // زيادة عدد وقوة الخصوم تدريجياً في كل جولة
    final botCount = min(12, 5 + _round);
    final botHp = 70.0 + (_round - 1) * 10.0;
    final botShield = min(60.0, 15.0 + (_round - 1) * 5.0);

    for (int i = 0; i < botCount; i++) {
      final angle = (2 * pi * i) / botCount;
      final radius = min(_arenaSize.width, _arenaSize.height) * 0.36;
      _bots.add(
        Fighter(
          pos: Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius),
          angle: angle + pi,
          hp: botHp,
          maxHp: botHp,
          shield: botShield,
          isAlive: true,
          isPlayer: false,
        ),
      );
    }

    // غنائم متنوعة في الساحة (إسعاف، درع، ترقية سلاح)
    for (int i = 0; i < 7; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = 35 + _rng.nextDouble() * 105;
      final kind = i == 0
          ? LootKind.weaponBoost
          : (i.isEven ? LootKind.medkit : LootKind.shield);
      _lootDrops.add(
        LootItem(
          pos: Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist),
          kind: kind,
        ),
      );
    }
  }

  void _startLoop() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _updateGame();
    });
  }

  void _shootFrom(Fighter shooter, double angle) {
    if (!shooter.isAlive || shooter.fireCooldown > 0) return;

    if (shooter.isPlayer) {
      shooter.fireCooldown = _rapidFireTicks > 0 ? 4 : 8;
    } else {
      shooter.fireCooldown = max(22, 38 - _round * 2);
    }

    shooter.muzzleFlashTicks = 3;
    const speed = 8.8;
    final muzzle = Offset(
      shooter.pos.dx + cos(angle) * 21,
      shooter.pos.dy + sin(angle) * 21,
    );

    _bullets.add(
      Bullet(
        pos: muzzle,
        vel: Offset(cos(angle) * speed, sin(angle) * speed),
        fromPlayer: shooter.isPlayer,
      ),
    );

    // عند تفعيل ترقية السلاح يطلق اللاعب طلقة مزدوجة بزاوية خفيفة
    if (shooter.isPlayer && _rapidFireTicks > 0) {
      final spreadAngle = angle + 0.11;
      _bullets.add(
        Bullet(
          pos: muzzle,
          vel: Offset(cos(spreadAngle) * speed, sin(spreadAngle) * speed),
          fromPlayer: true,
        ),
      );
    }
  }

  bool _hitsObstacle(Offset pos, double radius) {
    final hitRect = Rect.fromCircle(center: pos, radius: radius);
    for (final block in _obstacles) {
      if (block.rect.overlaps(hitRect)) return true;
    }
    return false;
  }

  void _performDash() {
    if (_matchOver || !_player.isAlive || _dashCooldown > 0) return;
    _dashCooldown = 45;
    final dir = _moveDir != Offset.zero
        ? _moveDir / _moveDir.distance
        : Offset(cos(_player.angle), sin(_player.angle));

    for (double step = 12; step <= 48; step += 12) {
      final candidate = Offset(
        (_player.pos.dx + dir.dx * 12).clamp(18.0, _arenaSize.width - 18.0),
        (_player.pos.dy + dir.dy * 12).clamp(18.0, _arenaSize.height - 18.0),
      );
      if (!_hitsObstacle(candidate, 14)) {
        _player.pos = candidate;
      } else {
        break;
      }
    }
    _sparks.add(HitSpark(pos: _player.pos, color: Colors.cyanAccent, life: 10));
  }

  void _updateGame() {
    if (_matchOver) return;
    _tickCount++;

    if (_rapidFireTicks > 0) _rapidFireTicks--;
    if (_dashCooldown > 0) _dashCooldown--;

    final center = Offset(_arenaSize.width / 2, _arenaSize.height / 2);

    if (_player.isAlive) {
      if (_player.fireCooldown > 0) _player.fireCooldown--;
      if (_player.muzzleFlashTicks > 0) _player.muzzleFlashTicks--;

      if (_isFiring) {
        _shootFrom(_player, _player.angle);
      }

      if (_moveDir != Offset.zero) {
        final len = _moveDir.distance;
        final nx = _moveDir.dx / len;
        final ny = _moveDir.dy / len;
        const speed = 4.0;
        final nextPos = Offset(
          (_player.pos.dx + nx * speed).clamp(18.0, _arenaSize.width - 18.0),
          (_player.pos.dy + ny * speed).clamp(18.0, _arenaSize.height - 18.0),
        );
        if (!_hitsObstacle(nextPos, 14)) {
          _player.pos = nextPos;
        }
      }
    }

    // التقاط الغنائم
    for (int i = _lootDrops.length - 1; i >= 0; i--) {
      final item = _lootDrops[i];
      if (_player.isAlive && (_player.pos - item.pos).distance < 25) {
        if (item.kind == LootKind.medkit) {
          _player.hp = min(_player.maxHp, _player.hp + 35);
          _sparks.add(HitSpark(pos: item.pos, color: Colors.greenAccent, life: 12));
        } else if (item.kind == LootKind.shield) {
          _player.shield = min(100, _player.shield + 40);
          _sparks.add(HitSpark(pos: item.pos, color: Colors.cyanAccent, life: 12));
        } else {
          _rapidFireTicks = 240; // 8 ثوانٍ من الرشاش السريع المزدوج
          _sparks.add(HitSpark(pos: item.pos, color: Colors.amberAccent, life: 14));
        }
        _score += 30;
        _lootDrops.removeAt(i);
      }
    }

    // تحديث الطلقات
    for (int i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.pos += b.vel;
      b.life--;

      if (b.life <= 0 ||
          b.pos.dx < 0 ||
          b.pos.dx > _arenaSize.width ||
          b.pos.dy < 0 ||
          b.pos.dy > _arenaSize.height ||
          _hitsObstacle(b.pos, 3)) {
        _sparks.add(HitSpark(pos: b.pos, color: Colors.orangeAccent, life: 6));
        _bullets.removeAt(i);
        continue;
      }

      if (b.fromPlayer) {
        bool hit = false;
        for (final bot in _bots) {
          if (bot.isAlive && (bot.pos - b.pos).distance < 16) {
            _damageFighter(bot, 26);
            _sparks.add(HitSpark(pos: b.pos, color: Colors.redAccent, life: 9));
            hit = true;
            break;
          }
        }
        if (hit) {
          _bullets.removeAt(i);
          continue;
        }
      } else {
        if (_player.isAlive && (_player.pos - b.pos).distance < 16) {
          _damageFighter(_player, 5.5 + _round * 0.6);
          _sparks.add(HitSpark(pos: b.pos, color: Colors.yellowAccent, life: 9));
          _bullets.removeAt(i);
          continue;
        }
      }
    }

    // تحديث المؤثرات البصرية
    for (int i = _sparks.length - 1; i >= 0; i--) {
      _sparks[i].life--;
      if (_sparks[i].life <= 0) {
        _sparks.removeAt(i);
      }
    }

    final botsCanShoot = _tickCount > 75;

    for (final bot in _bots) {
      if (!bot.isAlive) continue;
      if (bot.fireCooldown > 0) bot.fireCooldown--;
      if (bot.muzzleFlashTicks > 0) bot.muzzleFlashTicks--;

      if (bot.aiTimer <= 0) {
        bot.aiTimer = 25 + _rng.nextInt(30);
        final distCenter = (bot.pos - center).distance;
        if (distCenter > _zoneRadius * 0.8) {
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

      final botSpeed = 1.65 + min(0.8, _round * 0.1);
      final nextBotPos = Offset(
        (bot.pos.dx + bot.aiDir.dx * botSpeed).clamp(18.0, _arenaSize.width - 18.0),
        (bot.pos.dy + bot.aiDir.dy * botSpeed).clamp(18.0, _arenaSize.height - 18.0),
      );
      if (!_hitsObstacle(nextBotPos, 14)) {
        bot.pos = nextBotPos;
      }

      final toPlayer = _player.pos - bot.pos;
      final distPlayer = toPlayer.distance;
      if (distPlayer < 330 && _player.isAlive) {
        bot.angle = atan2(toPlayer.dy, toPlayer.dx);
        if (botsCanShoot) {
          _shootFrom(bot, bot.angle);
        }
      } else {
        bot.angle = atan2(bot.aiDir.dy, bot.aiDir.dx);
      }

      if ((bot.pos - center).distance > _zoneRadius) {
        _damageFighter(bot, 0.12, fromZone: true);
      }
    }

    if ((_player.pos - center).distance > _zoneRadius) {
      _damageFighter(_player, 0.1, fromZone: true);
    }

    if (_zoneRadius > 105) {
      _zoneRadius = max(105, _zoneRadius - 0.06);
    }

    final aliveBots = _bots.where((b) => b.isAlive).length;
    if (!_player.isAlive) {
      _matchOver = true;
      _roundWon = false;
      _statusText = 'انتهت المعركة في الجولة $_round!';
      _loopTimer?.cancel();
    } else if (aliveBots == 0) {
      _matchOver = true;
      _roundWon = true;
      _score += _round * 150;
      _statusText = 'انتصار في الجولة $_round!';
      _loopTimer?.cancel();
    } else {
      final weaponTag = _rapidFireTicks > 0 ? ' | سلاح مزدوج!' : '';
      _statusText = botsCanShoot
          ? 'جولة $_round | الخصوم: $aliveBots | النقاط: $_score$weaponTag'
          : 'جولة $_round - تحرك واحتمِ بالسواتر!';
    }

    setState(() {});
  }

  void _damageFighter(Fighter target, double amount, {bool fromZone = false}) {
    if (!target.isAlive) return;
    if (target.shield > 0 && !fromZone) {
      final absorbed = min(target.shield, amount);
      target.shield -= absorbed;
      final remaining = amount - absorbed;
      target.hp -= remaining;
    } else {
      target.hp -= amount;
    }
    if (target.hp <= 0) {
      target.hp = 0;
      target.isAlive = false;
      _sparks.add(HitSpark(pos: target.pos, color: Colors.amber, life: 16));
      if (!target.isPlayer) {
        _kills++;
        _score += 100;
        final roll = _rng.nextInt(3);
        final dropKind = roll == 0
            ? LootKind.medkit
            : (roll == 1 ? LootKind.shield : LootKind.weaponBoost);
        _lootDrops.add(LootItem(pos: target.pos, kind: dropKind));
      }
    }
  }

  void _nextRound() {
    _loopTimer?.cancel();
    _round++;
    _initMatch(resetProgress: false);
    _startLoop();
    setState(() {});
  }

  void _restartFromBeginning() {
    _loopTimer?.cancel();
    _initMatch(resetProgress: true);
    _startLoop();
    setState(() {});
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E141B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151E28),
        foregroundColor: Colors.white,
        title: Text('ميدان الغنائم • الجولة $_round'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'إقصاء: $_kills',
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: _restartFromBeginning,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة من الجولة 1',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF182330),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('الصحة: ', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_player.hp / _player.maxHp).clamp(0.0, 1.0),
                        color: Colors.greenAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('الدرع: ', style: TextStyle(color: Colors.white70)),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: (_player.shield / 100).clamp(0.0, 1.0),
                        color: Colors.cyanAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _arenaSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    GestureDetector(
                      onPanStart: (details) => _handleAim(details.localPosition),
                      onPanUpdate: (details) => _handleAim(details.localPosition),
                      onTapDown: (details) => _handleAim(details.localPosition),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: ArenaPainter(
                          round: _round,
                          player: _player,
                          bots: _bots,
                          bullets: _bullets,
                          lootDrops: _lootDrops,
                          obstacles: _obstacles,
                          sparks: _sparks,
                          zoneRadius: _zoneRadius,
                        ),
                      ),
                    ),
                    if (_matchOver)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151E28).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _roundWon ? Colors.greenAccent : Colors.amber,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _statusText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'النقاط: $_score  |  الخصوم المقصون: $_kills',
                                style: const TextStyle(color: Colors.amber),
                              ),
                              const SizedBox(height: 16),
                              if (_roundWon)
                                ElevatedButton.icon(
                                  onPressed: _nextRound,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.arrow_forward),
                                  label: Text('الانتقال إلى الجولة ${_round + 1}'),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: _restartFromBeginning,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.replay),
                                  label: const Text('بدء من الجولة 1'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: const Color(0xFF151E28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _MoveButton(
                      icon: Icons.arrow_upward,
                      onPressedDown: () => _moveDir = Offset(_moveDir.dx, -1),
                      onPressedUp: () => _moveDir = Offset(_moveDir.dx, 0),
                    ),
                    const SizedBox(width: 5),
                    _MoveButton(
                      icon: Icons.arrow_downward,
                      onPressedDown: () => _moveDir = Offset(_moveDir.dx, 1),
                      onPressedUp: () => _moveDir = Offset(_moveDir.dx, 0),
                    ),
                    const SizedBox(width: 5),
                    _MoveButton(
                      icon: Icons.arrow_back,
                      onPressedDown: () => _moveDir = Offset(-1, _moveDir.dy),
                      onPressedUp: () => _moveDir = Offset(0, _moveDir.dy),
                    ),
                    const SizedBox(width: 5),
                    _MoveButton(
                      icon: Icons.arrow_forward,
                      onPressedDown: () => _moveDir = Offset(1, _moveDir.dy),
                      onPressedUp: () => _moveDir = Offset(0, _moveDir.dy),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _performDash,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: _dashCooldown == 0
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Listener(
                      onPointerDown: (_) {
                        _isFiring = true;
                        if (!_matchOver && _player.isAlive) {
                          _shootFrom(_player, _player.angle);
                        }
                      },
                      onPointerUp: (_) => _isFiring = false,
                      onPointerCancel: (_) => _isFiring = false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.my_location, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'إطلاق',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAim(Offset localPos) {
    final dx = localPos.dx - _player.pos.dx;
    final dy = localPos.dy - _player.pos.dy;
    _player.angle = atan2(dy, dx);
    setState(() {});
  }
}

class _MoveButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressedDown;
  final VoidCallback onPressedUp;

  const _MoveButton({
    required this.icon,
    required this.onPressedDown,
    required this.onPressedUp,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onPressedDown(),
      onPointerUp: (_) => onPressedUp(),
      onPointerCancel: (_) => onPressedUp(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF243447),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

class Fighter {
  Offset pos;
  double angle;
  double hp;
  double maxHp;
  double shield;
  bool isAlive;
  bool isPlayer;
  int fireCooldown = 0;
  int muzzleFlashTicks = 0;
  int aiTimer = 0;
  Offset aiDir = Offset.zero;

  Fighter({
    required this.pos,
    required this.angle,
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.isAlive,
    required this.isPlayer,
  });
}

class Bullet {
  Offset pos;
  Offset vel;
  bool fromPlayer;
  int life = 48;

  Bullet({
    required this.pos,
    required this.vel,
    required this.fromPlayer,
  });
}

enum LootKind { medkit, shield, weaponBoost }

class LootItem {
  final Offset pos;
  final LootKind kind;

  LootItem({required this.pos, required this.kind});
}

class CoverBlock {
  final Rect rect;
  final bool isSandbag;

  CoverBlock({required this.rect, required this.isSandbag});
}

class HitSpark {
  final Offset pos;
  final Color color;
  int life;

  HitSpark({required this.pos, required this.color, required this.life});
}

class ArenaPainter extends CustomPainter {
  final int round;
  final Fighter player;
  final List<Fighter> bots;
  final List<Bullet> bullets;
  final List<LootItem> lootDrops;
  final List<CoverBlock> obstacles;
  final List<HitSpark> sparks;
  final double zoneRadius;

  ArenaPainter({
    required this.round,
    required this.player,
    required this.bots,
    required this.bullets,
    required this.lootDrops,
    required this.obstacles,
    required this.sparks,
    required this.zoneRadius,
  });

  void _drawGroundDetails(Canvas canvas, Size size) {
    // تغيير طابع الأرضية حسب الجولة (إسفلت حضري / أرض صحراوية / قاعدة ليلية)
    final themeIndex = round % 3;
    final groundColor = themeIndex == 1
        ? const Color(0xFF232524)
        : (themeIndex == 2 ? const Color(0xFF332B21) : const Color(0xFF151C24));
    canvas.drawRect(Offset.zero & size, Paint()..color = groundColor);

    // بلاطات أرضية وتشققات واقعية خفيفة
    final tilePaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), tilePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), tilePaint);
    }

    // تشققات وحصى متفرقة
    final crackPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final gravelPaint = Paint()..color = Colors.white.withOpacity(0.05);

    for (int i = 1; i <= 14; i++) {
      final cx = (i * 73.0) % max(40.0, size.width - 20);
      final cy = (i * 119.0) % max(40.0, size.height - 20);
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + 12, cy + 7)
        ..lineTo(cx + 22, cy + 2);
      canvas.drawPath(path, crackPaint);
      canvas.drawCircle(Offset(cx + 6, cy + 14), 2.2, gravelPaint);
    }
  }

  void _drawCharacter(Canvas canvas, Fighter f) {
    // ظل واقعي أسفل الجندي
    canvas.drawOval(
      Rect.fromCenter(center: f.pos + const Offset(3, 5), width: 26, height: 22),
      Paint()..color = Colors.black.withOpacity(0.42),
    );

    canvas.save();
    canvas.translate(f.pos.dx, f.pos.dy);

    // شريط صحة فوق الخصم
    if (!f.isPlayer && f.isAlive) {
      const barW = 30.0;
      const barH = 4.0;
      final ratio = (f.hp / f.maxHp).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, -25, barW, barH),
        Paint()..color = Colors.black87,
      );
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, -25, barW * ratio, barH),
        Paint()..color = Colors.redAccent,
      );
    }

    canvas.rotate(f.angle);

    // خط تصويب ليزري خفيف للاعب
    if (f.isPlayer) {
      canvas.drawLine(
        const Offset(22, 0),
        const Offset(95, 0),
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.25)
          ..strokeWidth = 1.2,
      );
    }

    final vestColor = f.isPlayer ? const Color(0xFF2B5876) : const Color(0xFF6E352C);
    final helmetColor = f.isPlayer ? const Color(0xFF3E7CB1) : const Color(0xFF8C3B2B);

    // الأكتاف والسترة التكتيكية
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -14, 16, 28),
        const Radius.circular(6),
      ),
      Paint()..color = vestColor,
    );

    // الذراعان
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1, -12, 14, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF8D7B68),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1, 7, 14, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF8D7B68),
    );

    // البندقية
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, -2.5, 20, 5),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF1F2428),
    );

    // وميض الإطلاق من فوهة السلاح
    if (f.muzzleFlashTicks > 0) {
      canvas.drawCircle(
        const Offset(25, 0),
        6,
        Paint()..color = Colors.amberAccent.withOpacity(0.85),
      );
    }

    // الخوذة والرأس
    canvas.drawCircle(Offset.zero, 9.5, Paint()..color = helmetColor);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 7.5),
      -0.7,
      1.4,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawGroundDetails(canvas, size);

    // توهج المنطقة الآمنة
    final zoneGlow = Paint()
      ..color = Colors.amber.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, zoneRadius, zoneGlow);

    final zonePaint = Paint()
      ..color = Colors.amber.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, zoneRadius, zonePaint);

    // السواتر (حواجز خرسانية وأكياس رمل بظلال)
    for (final block in obstacles) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block.rect.shift(const Offset(4, 5)), const Radius.circular(6)),
        Paint()..color = Colors.black.withOpacity(0.45),
      );

      final fill = block.isSandbag ? const Color(0xFF7D6B52) : const Color(0xFF4F5861);
      final border = block.isSandbag ? const Color(0xFFA69276) : const Color(0xFF7B8794);
      final rrect = RRect.fromRectAndRadius(block.rect, const Radius.circular(5));
      canvas.drawRRect(rrect, Paint()..color = fill);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // الغنائم على الأرض
    for (final item in lootDrops) {
      canvas.drawCircle(item.pos + const Offset(2, 3), 9, Paint()..color = Colors.black38);
      if (item.kind == LootKind.medkit) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: item.pos, width: 18, height: 14),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF2E7D32),
        );
        canvas.drawRect(
          Rect.fromCenter(center: item.pos, width: 9, height: 3),
          Paint()..color = Colors.white,
        );
        canvas.drawRect(
          Rect.fromCenter(center: item.pos, width: 3, height: 9),
          Paint()..color = Colors.white,
        );
      } else if (item.kind == LootKind.shield) {
        canvas.drawCircle(item.pos, 9, Paint()..color = const Color(0xFF00838F));
        canvas.drawCircle(item.pos, 4.5, Paint()..color = Colors.cyanAccent);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: item.pos, width: 18, height: 12),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFFFF8F00),
        );
        canvas.drawCircle(item.pos, 3, Paint()..color = Colors.white);
      }
    }

    // الخصوم
    for (final b in bots) {
      if (!b.isAlive) continue;
      _drawCharacter(canvas, b);
    }

    // اللاعب
    if (player.isAlive) {
      _drawCharacter(canvas, player);
    }

    // الطلقات مع ذيل ضوئي
    for (final bl in bullets) {
      canvas.drawLine(
        bl.pos - bl.vel * 1.4,
        bl.pos,
        Paint()
          ..color = Colors.amberAccent.withOpacity(0.55)
          ..strokeWidth = 2.4,
      );
      canvas.drawCircle(bl.pos, 3.2, Paint()..color = Colors.yellowAccent);
    }

    // شرارات الإصابة والانفجار
    for (final sp in sparks) {
      canvas.drawCircle(
        sp.pos,
        (16 - sp.life).clamp(3, 14).toDouble(),
        Paint()
          ..color = sp.color.withOpacity((sp.life / 16).clamp(0.1, 0.9))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
