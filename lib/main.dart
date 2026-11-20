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
  int _score = 0;
  int _tickCount = 0;
  bool _matchOver = false;
  String _statusText = 'استعد للمواجهة';
  Offset _moveDir = Offset.zero;

  late Fighter _player;
  final List<Fighter> _bots = [];
  final List<Bullet> _bullets = [];
  final List<LootItem> _lootDrops = [];
  final List<Rect> _obstacles = [];

  @override
  void initState() {
    super.initState();
    _initMatch();
    _startLoop();
  }

  void _initMatch() {
    final center = Offset(_arenaSize.width / 2, _arenaSize.height / 2);
    _zoneRadius = min(_arenaSize.width, _arenaSize.height) * 0.46;
    _score = 0;
    _tickCount = 0;
    _matchOver = false;
    _statusText = 'المعركة بدأت! استعد للتحرك';

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

    _obstacles.addAll([
      Rect.fromCenter(center: center + const Offset(-75, -65), width: 48, height: 48),
      Rect.fromCenter(center: center + const Offset(75, -65), width: 48, height: 48),
      Rect.fromCenter(center: center + const Offset(-75, 65), width: 48, height: 48),
      Rect.fromCenter(center: center + const Offset(75, 65), width: 48, height: 48),
    ]);

    for (int i = 0; i < 6; i++) {
      final angle = (2 * pi * i) / 6;
      final radius = min(_arenaSize.width, _arenaSize.height) * 0.35;
      _bots.add(
        Fighter(
          pos: Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius),
          angle: angle + pi,
          hp: 75,
          maxHp: 75,
          shield: 20,
          isAlive: true,
          isPlayer: false,
        ),
      );
    }

    for (int i = 0; i < 6; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = 30 + _rng.nextDouble() * 100;
      _lootDrops.add(
        LootItem(
          pos: Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist),
          kind: i.isEven ? LootKind.medkit : LootKind.shield,
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
    shooter.fireCooldown = shooter.isPlayer ? 7 : 36;
    const speed = 8.0;
    final muzzle = Offset(
      shooter.pos.dx + cos(angle) * 20,
      shooter.pos.dy + sin(angle) * 20,
    );
    _bullets.add(
      Bullet(
        pos: muzzle,
        vel: Offset(cos(angle) * speed, sin(angle) * speed),
        fromPlayer: shooter.isPlayer,
      ),
    );
  }

  bool _hitsObstacle(Offset pos, double radius) {
    final hitRect = Rect.fromCircle(center: pos, radius: radius);
    for (final rect in _obstacles) {
      if (rect.overlaps(hitRect)) return true;
    }
    return false;
  }

  void _updateGame() {
    if (_matchOver) return;
    _tickCount++;

    final center = Offset(_arenaSize.width / 2, _arenaSize.height / 2);

    if (_player.isAlive) {
      if (_player.fireCooldown > 0) _player.fireCooldown--;
      if (_moveDir != Offset.zero) {
        final len = _moveDir.distance;
        final nx = _moveDir.dx / len;
        final ny = _moveDir.dy / len;
        const speed = 3.8;
        final nextPos = Offset(
          (_player.pos.dx + nx * speed).clamp(18.0, _arenaSize.width - 18.0),
          (_player.pos.dy + ny * speed).clamp(18.0, _arenaSize.height - 18.0),
        );
        if (!_hitsObstacle(nextPos, 14)) {
          _player.pos = nextPos;
        }
      }
    }

    for (int i = _lootDrops.length - 1; i >= 0; i--) {
      final item = _lootDrops[i];
      if (_player.isAlive && (_player.pos - item.pos).distance < 24) {
        if (item.kind == LootKind.medkit) {
          _player.hp = min(_player.maxHp, _player.hp + 35);
        } else {
          _player.shield = min(100, _player.shield + 40);
        }
        _score += 25;
        _lootDrops.removeAt(i);
      }
    }

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
        _bullets.removeAt(i);
        continue;
      }

      if (b.fromPlayer) {
        bool hit = false;
        for (final bot in _bots) {
          if (bot.isAlive && (bot.pos - b.pos).distance < 16) {
            _damageFighter(bot, 25);
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
          _damageFighter(_player, 6);
          _bullets.removeAt(i);
          continue;
        }
      }
    }

    final botsCanShoot = _tickCount > 90; // مهلة 3 ثوانٍ في بداية الجولة

    for (final bot in _bots) {
      if (!bot.isAlive) continue;
      if (bot.fireCooldown > 0) bot.fireCooldown--;

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

      const botSpeed = 1.7;
      final nextBotPos = Offset(
        (bot.pos.dx + bot.aiDir.dx * botSpeed).clamp(18.0, _arenaSize.width - 18.0),
        (bot.pos.dy + bot.aiDir.dy * botSpeed).clamp(18.0, _arenaSize.height - 18.0),
      );
      if (!_hitsObstacle(nextBotPos, 14)) {
        bot.pos = nextBotPos;
      }

      final toPlayer = _player.pos - bot.pos;
      final distPlayer = toPlayer.distance;
      if (distPlayer < 320 && _player.isAlive) {
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

    if (_zoneRadius > 110) {
      _zoneRadius = max(110, _zoneRadius - 0.06);
    }

    final aliveBots = _bots.where((b) => b.isAlive).length;
    if (!_player.isAlive) {
      _matchOver = true;
      _statusText = 'تم إقصاؤك! الخصوم الباقون: $aliveBots';
      _loopTimer?.cancel();
    } else if (aliveBots == 0) {
      _matchOver = true;
      _statusText = 'انتصار! سيطرت على ميدان الغنائم';
      _loopTimer?.cancel();
    } else {
      _statusText = botsCanShoot
          ? 'الخصوم المتبقون: $aliveBots | الغنائم: $_score'
          : 'استعد! هجوم الخصوم يبدأ خلال لحظات...';
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
      if (!target.isPlayer) {
        _score += 100;
        _lootDrops.add(
          LootItem(
            pos: target.pos,
            kind: _rng.nextBool() ? LootKind.medkit : LootKind.shield,
          ),
        );
      }
    }
  }

  void _restartMatch() {
    _loopTimer?.cancel();
    _initMatch();
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
        title: const Text('ميدان الغنائم'),
        actions: [
          IconButton(
            onPressed: _restartMatch,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة اللعب',
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
                          player: _player,
                          bots: _bots,
                          bullets: _bullets,
                          lootDrops: _lootDrops,
                          obstacles: _obstacles,
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
                            border: Border.all(color: Colors.amber, width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _statusText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'مجموع الغنائم والنقاط: $_score',
                                style: const TextStyle(color: Colors.amber),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _restartMatch,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.replay),
                                label: const Text('لعب مرة أخرى'),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    const SizedBox(width: 6),
                    _MoveButton(
                      icon: Icons.arrow_downward,
                      onPressedDown: () => _moveDir = Offset(_moveDir.dx, 1),
                      onPressedUp: () => _moveDir = Offset(_moveDir.dx, 0),
                    ),
                    const SizedBox(width: 6),
                    _MoveButton(
                      icon: Icons.arrow_back,
                      onPressedDown: () => _moveDir = Offset(-1, _moveDir.dy),
                      onPressedUp: () => _moveDir = Offset(0, _moveDir.dy),
                    ),
                    const SizedBox(width: 6),
                    _MoveButton(
                      icon: Icons.arrow_forward,
                      onPressedDown: () => _moveDir = Offset(1, _moveDir.dy),
                      onPressedUp: () => _moveDir = Offset(0, _moveDir.dy),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _triggerFire,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.my_location),
                  label: const Text('إطلاق'),
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

  void _triggerFire() {
    if (_matchOver || !_player.isAlive) return;
    _shootFrom(_player, _player.angle);
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF243447),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
  int life = 45;

  Bullet({
    required this.pos,
    required this.vel,
    required this.fromPlayer,
  });
}

enum LootKind { medkit, shield }

class LootItem {
  final Offset pos;
  final LootKind kind;

  LootItem({required this.pos, required this.kind});
}

class ArenaPainter extends CustomPainter {
  final Fighter player;
  final List<Fighter> bots;
  final List<Bullet> bullets;
  final List<LootItem> lootDrops;
  final List<Rect> obstacles;
  final double zoneRadius;

  ArenaPainter({
    required this.player,
    required this.bots,
    required this.bullets,
    required this.lootDrops,
    required this.obstacles,
    required this.zoneRadius,
  });

  void _drawCharacter(Canvas canvas, Fighter f) {
    canvas.save();
    canvas.translate(f.pos.dx, f.pos.dy);

    // شريط صحة صغير فوق الخصم
    if (!f.isPlayer && f.isAlive) {
      const barW = 28.0;
      const barH = 4.0;
      final ratio = (f.hp / f.maxHp).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, -24, barW, barH),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, -24, barW * ratio, barH),
        Paint()..color = Colors.redAccent,
      );
    }

    canvas.rotate(f.angle);

    final bodyColor = f.isPlayer ? Colors.blueAccent : Colors.redAccent;
    final shoulderColor = f.isPlayer ? Colors.lightBlue.shade200 : Colors.orange.shade300;

    // الكتفان / الدرع
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -14, 14, 28),
        const Radius.circular(6),
      ),
      Paint()..color = shoulderColor,
    );

    // السلاح الأمامي
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, -3, 18, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFCFD8DC),
    );

    // الرأس / الخوذة
    canvas.drawCircle(Offset.zero, 9.5, Paint()..color = bodyColor);
    canvas.drawCircle(
      const Offset(3, 0),
      4,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final bgPaint = Paint()..color = const Color(0xFF131C26);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // شبكة أرضية خفيفة لإحساس الحركة
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // المنطقة الآمنة
    final zonePaint = Paint()
      ..color = Colors.amber.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, zoneRadius, zonePaint);

    // العوائق / السواتر
    final obsFill = Paint()..color = const Color(0xFF263545);
    final obsBorder = Paint()
      ..color = const Color(0xFF4A6078)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final rect in obstacles) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, obsFill);
      canvas.drawRRect(rrect, obsBorder);
    }

    // الغنائم (إسعاف ودرع)
    for (final item in lootDrops) {
      if (item.kind == LootKind.medkit) {
        canvas.drawCircle(item.pos, 8, Paint()..color = Colors.green.shade800);
        canvas.drawRect(
          Rect.fromCenter(center: item.pos, width: 10, height: 3.5),
          Paint()..color = Colors.white,
        );
        canvas.drawRect(
          Rect.fromCenter(center: item.pos, width: 3.5, height: 10),
          Paint()..color = Colors.white,
        );
      } else {
        canvas.drawCircle(item.pos, 8, Paint()..color = Colors.cyan.shade700);
        canvas.drawCircle(item.pos, 4, Paint()..color = Colors.cyanAccent);
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

    // الطلقات
    final bulletPaint = Paint()..color = Colors.yellowAccent;
    for (final bl in bullets) {
      canvas.drawCircle(bl.pos, 4, bulletPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
