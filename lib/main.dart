import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(CandyKidsApp(storage: GameStorageService(prefs)));
}

// ============================================================================
// THEME & COLORS - Candy Crush / Toca Boca Style
// ============================================================================
class CandyColors {
  // Primary vibrant palette
  static const bubblegumPink = Color(0xFFFF6B9D);
  static const skyBlue = Color(0xFF4ECDC4);
  static const lemonYellow = Color(0xFFFFE66D);
  static const candyOrange = Color(0xFFFF9F43);
  static const grapeViolet = Color(0xFFAB7BFF);
  static const mintGreen = Color(0xFF7BED9F);
  static const cherryRed = Color(0xFFFF6B6B);
  static const cottonCandy = Color(0xFFFFB8D0);
  
  // Gradients
  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B9D),
    Color(0xFFFF9F43),
    Color(0xFFFFE66D),
  ];
  
  static const List<Color> oceanGradient = [
    Color(0xFF4ECDC4),
    Color(0xFF44B3FF),
    Color(0xFFAB7BFF),
  ];
  
  static const List<Color> candyGradient = [
    Color(0xFFFF6B9D),
    Color(0xFFAB7BFF),
    Color(0xFF4ECDC4),
  ];
}

// ============================================================================
// GAME STATE MODEL
// ============================================================================
class GameState {
  int currentLevel;
  int totalStars;
  int coins;
  Map<int, int> levelStars; // level -> stars (0-3)
  String playerName;
  List<bool> weeklyStreak;
  DateTime lastPlayedDate;
  
  GameState({
    this.currentLevel = 1,
    this.totalStars = 0,
    this.coins = 0,
    Map<int, int>? levelStars,
    this.playerName = '',
    List<bool>? weeklyStreak,
    DateTime? lastPlayedDate,
  }) : levelStars = levelStars ?? {},
       weeklyStreak = weeklyStreak ?? List.filled(7, false),
       lastPlayedDate = lastPlayedDate ?? DateTime.now();
  
  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      currentLevel: json['currentLevel'] ?? 1,
      totalStars: json['totalStars'] ?? 0,
      coins: json['coins'] ?? 0,
      levelStars: (json['levelStars'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(int.parse(k), v as int),
      ) ?? {},
      playerName: json['playerName'] ?? '',
      weeklyStreak: (json['weeklyStreak'] as List?)?.cast<bool>() ?? List.filled(7, false),
      lastPlayedDate: json['lastPlayedDate'] != null 
          ? DateTime.parse(json['lastPlayedDate']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'currentLevel': currentLevel,
    'totalStars': totalStars,
    'coins': coins,
    'levelStars': levelStars.map((k, v) => MapEntry(k.toString(), v)),
    'playerName': playerName,
    'weeklyStreak': weeklyStreak,
    'lastPlayedDate': lastPlayedDate.toIso8601String(),
  };
  
  GameState copyWith({
    int? currentLevel,
    int? totalStars,
    int? coins,
    Map<int, int>? levelStars,
    String? playerName,
    List<bool>? weeklyStreak,
    DateTime? lastPlayedDate,
  }) {
    return GameState(
      currentLevel: currentLevel ?? this.currentLevel,
      totalStars: totalStars ?? this.totalStars,
      coins: coins ?? this.coins,
      levelStars: levelStars ?? Map.from(this.levelStars),
      playerName: playerName ?? this.playerName,
      weeklyStreak: weeklyStreak ?? List.from(this.weeklyStreak),
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
    );
  }
  
  int getStarsForLevel(int level) => levelStars[level] ?? 0;
  
  bool isLevelUnlocked(int level) {
    if (level == 1) return true;
    return levelStars.containsKey(level - 1) && levelStars[level - 1]! > 0;
  }
}

// ============================================================================
// STORAGE SERVICE
// ============================================================================
class GameStorageService {
  final SharedPreferences _prefs;
  static const _stateKey = 'candy_kids_game_state';
  
  GameStorageService(this._prefs);
  
  Future<GameState> loadState() async {
    final json = _prefs.getString(_stateKey);
    if (json == null) return GameState();
    try {
      return GameState.fromJson(jsonDecode(json));
    } catch (_) {
      return GameState();
    }
  }
  
  Future<void> saveState(GameState state) async {
    await _prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }
}

// ============================================================================
// SOUND SERVICE (SoundPool-like for game sounds)
// ============================================================================
class SoundService {
  final AudioPlayer _dingPlayer = AudioPlayer();
  final AudioPlayer _boingPlayer = AudioPlayer();
  final AudioPlayer _popPlayer = AudioPlayer();
  bool _initialized = false;
  
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Set low latency mode for game sounds
    await _dingPlayer.setReleaseMode(ReleaseMode.stop);
    await _boingPlayer.setReleaseMode(ReleaseMode.stop);
    await _popPlayer.setReleaseMode(ReleaseMode.stop);
  }
  
  Future<void> playDing() async {
    // High-pitched success sound - using system sound as placeholder
    HapticFeedback.lightImpact();
  }
  
  Future<void> playBoing() async {
    // Gentle wrong answer sound
    HapticFeedback.mediumImpact();
  }
  
  Future<void> playPop() async {
    // Button tap sound
    HapticFeedback.selectionClick();
  }
  
  void dispose() {
    _dingPlayer.dispose();
    _boingPlayer.dispose();
    _popPlayer.dispose();
  }
}

// ============================================================================
// MAIN APP
// ============================================================================
class CandyKidsApp extends StatelessWidget {
  final GameStorageService storage;
  
  const CandyKidsApp({super.key, required this.storage});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candy Kids Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Comic Sans MS',
        colorScheme: ColorScheme.fromSeed(
          seedColor: CandyColors.bubblegumPink,
          brightness: Brightness.light,
        ),
      ),
      home: GameShell(storage: storage),
    );
  }
}

// ============================================================================
// GAME SHELL - Main container with navigation
// ============================================================================
class GameShell extends StatefulWidget {
  final GameStorageService storage;
  
  const GameShell({super.key, required this.storage});
  
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with TickerProviderStateMixin {
  GameState _gameState = GameState();
  final SoundService _soundService = SoundService();
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGame();
    _soundService.init();
  }
  
  Future<void> _loadGame() async {
    final state = await widget.storage.loadState();
    _updateStreak(state);
    setState(() {
      _gameState = state;
      _isLoading = false;
    });
  }
  
  void _updateStreak(GameState state) {
    final now = DateTime.now();
    final lastPlayed = state.lastPlayedDate;
    
    // Reset week if it's a new week (Monday)
    if (now.weekday == DateTime.monday && 
        lastPlayed.isBefore(now.subtract(const Duration(days: 1)))) {
      state.weeklyStreak.fillRange(0, 7, false);
    }
    
    // Mark today as played
    state.weeklyStreak[now.weekday - 1] = true;
    state.lastPlayedDate = now;
  }
  
  void _updateGameState(GameState newState) {
    setState(() => _gameState = newState);
    widget.storage.saveState(newState);
  }
  
  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show name entry if new player
    if (_gameState.playerName.isEmpty) {
      return NameEntryScreen(
        onNameEntered: (name) {
          _updateGameState(_gameState.copyWith(playerName: name));
        },
      );
    }
    
    return LevelMapScreen(
      gameState: _gameState,
      soundService: _soundService,
      onGameStateUpdate: _updateGameState,
    );
  }
}

// ============================================================================
// NAME ENTRY SCREEN
// ============================================================================
class NameEntryScreen extends StatefulWidget {
  final Function(String) onNameEntered;
  
  const NameEntryScreen({super.key, required this.onNameEntered});
  
  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> 
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  
  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _bounceController.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: CandyColors.sunsetGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -_bounceAnimation.value),
                        child: child,
                      );
                    },
                    child: const Text(
                      '🍭',
                      style: TextStyle(fontSize: 80),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to\nCandy Quest!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's your name?",
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Candy3DButton(
                    text: "Let's Play! 🎮",
                    color: CandyColors.mintGreen,
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        widget.onNameEntered(_controller.text.trim());
                      }
                    },
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

// ============================================================================
// LEVEL MAP SCREEN - Winding path with levels
// ============================================================================
class LevelMapScreen extends StatefulWidget {
  final GameState gameState;
  final SoundService soundService;
  final Function(GameState) onGameStateUpdate;
  
  const LevelMapScreen({
    super.key,
    required this.gameState,
    required this.soundService,
    required this.onGameStateUpdate,
  });
  
  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> 
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late List<AnimationController> _wiggleControllers;
  
  // Level configurations
  static const int totalLevels = 30;
  
  @override
  void initState() {
    super.initState();
    _wiggleControllers = List.generate(totalLevels, (index) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + Random().nextInt(400)),
        vsync: this,
      );
      // Stagger the animations
      Future.delayed(Duration(milliseconds: index * 100), () {
        if (mounted) controller.repeat(reverse: true);
      });
      return controller;
    });
    
    // Scroll to current level after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLevel();
    });
  }
  
  void _scrollToCurrentLevel() {
    final level = widget.gameState.currentLevel;
    final targetScroll = (totalLevels - level) * 120.0;
    _scrollController.animateTo(
      targetScroll.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }
  
  @override
  void dispose() {
    for (var c in _wiggleControllers) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onLevelTap(int level) {
    if (!widget.gameState.isLevelUnlocked(level)) {
      _showLockedDialog();
      return;
    }
    
    widget.soundService.playPop();
    Navigator.push(
      context,
      SpringPageRoute(
        child: LevelPlayScreen(
          level: level,
          gameState: widget.gameState,
          soundService: widget.soundService,
          onLevelComplete: (stars, coins) {
            _handleLevelComplete(level, stars, coins);
          },
        ),
      ),
    );
  }
  
  void _handleLevelComplete(int level, int stars, int coins) {
    final newLevelStars = Map<int, int>.from(widget.gameState.levelStars);
    final existingStars = newLevelStars[level] ?? 0;
    if (stars > existingStars) {
      newLevelStars[level] = stars;
    }
    
    int newTotalStars = 0;
    newLevelStars.forEach((_, v) => newTotalStars += v);
    
    final newState = widget.gameState.copyWith(
      levelStars: newLevelStars,
      totalStars: newTotalStars,
      coins: widget.gameState.coins + coins,
      currentLevel: level >= widget.gameState.currentLevel 
          ? level + 1 
          : widget.gameState.currentLevel,
    );
    
    widget.onGameStateUpdate(newState);
  }
  
  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [CandyColors.grapeViolet, CandyColors.bubblegumPink],
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text(
                'Level Locked!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete the previous level first!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Candy3DButton(
                text: 'OK! 👍',
                color: CandyColors.lemonYellow,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => ParentalGateDialog(
        onSuccess: () {
          Navigator.pop(ctx);
          _showSettingsPanel();
        },
      ),
    );
  }
  
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚙️ Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.refresh, color: CandyColors.cherryRed),
              title: const Text('Reset Progress'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onGameStateUpdate(GameState(
                  playerName: widget.gameState.playerName,
                ));
              },
            ),
            const SizedBox(height: 16),
            Candy3DButton(
              text: 'Close',
              color: CandyColors.skyBlue,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB), // Sky blue
              Color(0xFFB8E994), // Light green (grass)
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative clouds
              ...List.generate(5, (i) => Positioned(
                top: 20 + i * 100.0,
                left: (i.isEven ? 20 : null),
                right: (i.isOdd ? 20 : null),
                child: Opacity(
                  opacity: 0.8,
                  child: Text(
                    '☁️',
                    style: TextStyle(fontSize: 40 + i * 10.0),
                  ),
                ),
              )),
              
              // Main scrollable level map
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80, bottom: 100),
                      child: _buildLevelPath(),
                    ),
                  ),
                ],
              ),
              
              // Top bar with stats
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CandyColors.bubblegumPink.withOpacity(0.95),
            CandyColors.candyOrange.withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Settings button (with parental gate)
          GestureDetector(
            onTap: _showSettings,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 28),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Player name
          Expanded(
            child: Text(
              'Hi, ${widget.gameState.playerName}! 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Stars counter
          _StatBadge(
            icon: '⭐',
            value: widget.gameState.totalStars.toString(),
            color: CandyColors.lemonYellow,
          ),
          
          const SizedBox(width: 8),
          
          // Coins counter
          _StatBadge(
            icon: '🪙',
            value: widget.gameState.coins.toString(),
            color: CandyColors.candyOrange,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLevelPath() {
    return Column(
      children: List.generate(totalLevels, (i) {
        final level = totalLevels - i; // Reverse order (newest at top)
        final isUnlocked = widget.gameState.isLevelUnlocked(level);
        final stars = widget.gameState.getStarsForLevel(level);
        final isCurrentLevel = level == widget.gameState.currentLevel;
        
        // Zigzag pattern
        final isLeft = i % 2 == 0;
        
        return Padding(
          padding: EdgeInsets.only(
            left: isLeft ? 40 : 120,
            right: isLeft ? 120 : 40,
            bottom: 20,
          ),
          child: Row(
            children: [
              if (!isLeft) const Spacer(),
              _LevelNode(
                level: level,
                isUnlocked: isUnlocked,
                stars: stars,
                isCurrentLevel: isCurrentLevel,
                wiggleAnimation: _wiggleControllers[i],
                onTap: () => _onLevelTap(level),
              ),
              if (isLeft) const Spacer(),
            ],
          ),
        );
      }),
    );
  }
}

// Stat badge widget
class _StatBadge extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;
  
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Level node on the map
class _LevelNode extends StatelessWidget {
  final int level;
  final bool isUnlocked;
  final int stars;
  final bool isCurrentLevel;
  final AnimationController wiggleAnimation;
  final VoidCallback onTap;
  
  const _LevelNode({
    required this.level,
    required this.isUnlocked,
    required this.stars,
    required this.isCurrentLevel,
    required this.wiggleAnimation,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: wiggleAnimation,
        builder: (context, child) {
          // Only wiggle if it's the current unlocked level
          final wiggle = isCurrentLevel 
              ? sin(wiggleAnimation.value * 2 * pi) * 0.05 
              : 0.0;
          return Transform.rotate(
            angle: wiggle,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect for current level
            if (isCurrentLevel)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CandyColors.lemonYellow.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            
            // Main node
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getLevelColors(level),
                      )
                    : null,
                color: isUnlocked ? null : Colors.grey[400],
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 6),
                    blurRadius: 8,
                  ),
                  if (isUnlocked)
                    BoxShadow(
                      color: _getLevelColors(level)[0].withOpacity(0.4),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                ],
              ),
              child: Center(
                child: isUnlocked
                    ? Text(
                        '$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      )
                    : const Icon(Icons.lock, color: Colors.white, size: 32),
              ),
            ),
            
            // Stars below
            if (stars > 0)
              Positioned(
                bottom: -8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) => Text(
                    i < stars ? '⭐' : '☆',
                    style: TextStyle(
                      fontSize: 16,
                      color: i < stars ? null : Colors.grey[400],
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  List<Color> _getLevelColors(int level) {
    final colorSets = [
      [CandyColors.bubblegumPink, CandyColors.cherryRed],
      [CandyColors.skyBlue, CandyColors.grapeViolet],
      [CandyColors.lemonYellow, CandyColors.candyOrange],
      [CandyColors.mintGreen, CandyColors.skyBlue],
      [CandyColors.grapeViolet, CandyColors.bubblegumPink],
    ];
    return colorSets[(level - 1) % colorSets.length];
  }
}

// ============================================================================
// LEVEL PLAY SCREEN - Full game screen
// ============================================================================
class LevelPlayScreen extends StatefulWidget {
  final int level;
  final GameState gameState;
  final SoundService soundService;
  final Function(int stars, int coins) onLevelComplete;
  
  const LevelPlayScreen({
    super.key,
    required this.level,
    required this.gameState,
    required this.soundService,
    required this.onLevelComplete,
  });
  
  @override
  State<LevelPlayScreen> createState() => _LevelPlayScreenState();
}

class _LevelPlayScreenState extends State<LevelPlayScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _progressController;
  
  int _currentQuestion = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 5;
  bool _isAnswering = true;
  String? _selectedAnswer;
  bool? _isCorrect;
  
  late List<Question> _questions;
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _questions = _generateQuestions();
  }
  
  List<Question> _generateQuestions() {
    final random = Random();
    final allQuestions = [
      // Colors
      Question('🔴', 'What color is this?', ['Red', 'Blue', 'Green', 'Yellow'], 'Red'),
      Question('🔵', 'What color is this?', ['Red', 'Blue', 'Green', 'Yellow'], 'Blue'),
      Question('🟢', 'What color is this?', ['Red', 'Blue', 'Green', 'Yellow'], 'Green'),
      Question('🟡', 'What color is this?', ['Red', 'Blue', 'Green', 'Yellow'], 'Yellow'),
      Question('🟣', 'What color is this?', ['Purple', 'Pink', 'Orange', 'Brown'], 'Purple'),
      
      // Shapes
      Question('⬛', 'What shape is this?', ['Square', 'Circle', 'Triangle', 'Star'], 'Square'),
      Question('🔶', 'What shape is this?', ['Square', 'Circle', 'Diamond', 'Star'], 'Diamond'),
      Question('⭐', 'What shape is this?', ['Square', 'Circle', 'Heart', 'Star'], 'Star'),
      Question('❤️', 'What shape is this?', ['Square', 'Circle', 'Heart', 'Star'], 'Heart'),
      Question('🔺', 'What shape is this?', ['Square', 'Circle', 'Triangle', 'Star'], 'Triangle'),
      
      // Animals
      Question('🐶', 'What animal is this?', ['Cat', 'Dog', 'Bird', 'Fish'], 'Dog'),
      Question('🐱', 'What animal is this?', ['Cat', 'Dog', 'Bird', 'Fish'], 'Cat'),
      Question('🐦', 'What animal is this?', ['Cat', 'Dog', 'Bird', 'Fish'], 'Bird'),
      Question('🐠', 'What animal is this?', ['Cat', 'Dog', 'Bird', 'Fish'], 'Fish'),
      Question('🐰', 'What animal is this?', ['Rabbit', 'Bear', 'Lion', 'Elephant'], 'Rabbit'),
      
      // Numbers
      Question('1️⃣', 'What number is this?', ['One', 'Two', 'Three', 'Four'], 'One'),
      Question('2️⃣', 'What number is this?', ['One', 'Two', 'Three', 'Four'], 'Two'),
      Question('3️⃣', 'What number is this?', ['One', 'Two', 'Three', 'Four'], 'Three'),
      Question('🍎🍎', 'How many apples?', ['One', 'Two', 'Three', 'Four'], 'Two'),
      Question('⭐⭐⭐', 'How many stars?', ['One', 'Two', 'Three', 'Four'], 'Three'),
    ];
    
    allQuestions.shuffle(random);
    return allQuestions.take(_totalQuestions).toList();
  }
  
  void _selectAnswer(String answer) {
    if (!_isAnswering) return;
    
    setState(() {
      _selectedAnswer = answer;
      _isCorrect = answer == _questions[_currentQuestion].correctAnswer;
      _isAnswering = false;
    });
    
    if (_isCorrect!) {
      _correctAnswers++;
      widget.soundService.playDing();
      _confettiController.play();
    } else {
      widget.soundService.playBoing();
      _shakeController.forward(from: 0);
    }
    
    // Move to next question after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      if (_currentQuestion < _totalQuestions - 1) {
        setState(() {
          _currentQuestion++;
          _selectedAnswer = null;
          _isCorrect = null;
          _isAnswering = true;
        });
        _progressController.forward(from: 0);
      } else {
        _showResults();
      }
    });
  }
  
  void _showResults() {
    final stars = _correctAnswers >= 4 ? 3 : (_correctAnswers >= 2 ? 2 : (_correctAnswers >= 1 ? 1 : 0));
    final coins = _correctAnswers * 10;
    
    widget.onLevelComplete(stars, coins);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelCompleteDialog(
        level: widget.level,
        stars: stars,
        coins: coins,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalQuestions,
        onContinue: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    _shakeController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestion];
    
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: CandyColors.oceanGradient,
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _isCorrect == false 
                        ? sin(_shakeController.value * 3 * pi) * _shakeAnimation.value 
                        : 0,
                    0,
                  ),
                  child: child,
                );
              },
              child: Column(
                children: [
                  // Top bar with back button and progress
                  _buildTopBar(),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Question emoji
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Text(
                              question.emoji,
                              style: const TextStyle(fontSize: 100),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Question text
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              question.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Answer buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.2,
                      children: question.options.map((option) {
                        final isSelected = _selectedAnswer == option;
                        final isCorrectAnswer = option == question.correctAnswer;
                        
                        Color buttonColor;
                        if (_selectedAnswer != null) {
                          if (isCorrectAnswer) {
                            buttonColor = CandyColors.mintGreen;
                          } else if (isSelected) {
                            buttonColor = CandyColors.cherryRed.withOpacity(0.7);
                          } else {
                            buttonColor = Colors.grey[300]!;
                          }
                        } else {
                          buttonColor = CandyColors.lemonYellow;
                        }
                        
                              return Candy3DButton(
                                text: option,
                                color: buttonColor,
                                onPressed: () => _selectAnswer(option),
                                enabled: _isAnswering,
                              );
                            }).toList(),
                          ),
                        ),
                          
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
          
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                CandyColors.bubblegumPink,
                CandyColors.skyBlue,
                CandyColors.lemonYellow,
                CandyColors.mintGreen,
                CandyColors.grapeViolet,
              ],
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button (large arrow)
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Level indicator
          Text(
            'Level ${widget.level}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Progress bar (candy-themed)
          Expanded(
            flex: 2,
            child: _CandyProgressBar(
              progress: (_currentQuestion + 1) / _totalQuestions,
            ),
          ),
        ],
      ),
    );
  }
}

// Candy-themed progress bar
class _CandyProgressBar extends StatelessWidget {
  final double progress;
  
  const _CandyProgressBar({required this.progress});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Progress fill
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CandyColors.bubblegumPink,
                      CandyColors.lemonYellow,
                      CandyColors.mintGreen,
                    ],
                  ),
                ),
              ),
            ),
            
            // Candy stripes overlay
            ...List.generate(10, (i) => Positioned(
              left: i * 20.0 - 10,
              top: -10,
              bottom: -10,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 4,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// Question model
class Question {
  final String emoji;
  final String text;
  final List<String> options;
  final String correctAnswer;
  
  Question(this.emoji, this.text, this.options, this.correctAnswer);
}

// ============================================================================
// LEVEL COMPLETE DIALOG
// ============================================================================
class LevelCompleteDialog extends StatefulWidget {
  final int level;
  final int stars;
  final int coins;
  final int correctAnswers;
  final int totalQuestions;
  final VoidCallback onContinue;
  
  const LevelCompleteDialog({
    super.key,
    required this.level,
    required this.stars,
    required this.coins,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.onContinue,
  });
  
  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _controller.forward();
    if (widget.stars >= 2) {
      _confettiController.play();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: CandyColors.sunsetGradient,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: CandyColors.bubblegumPink.withOpacity(0.5),
                    offset: const Offset(0, 10),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy or celebration
                  Text(
                    widget.stars >= 3 ? '🏆' : (widget.stars >= 2 ? '🎉' : '👏'),
                    style: const TextStyle(fontSize: 80),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    widget.stars >= 3 
                        ? 'PERFECT!' 
                        : (widget.stars >= 2 ? 'GREAT JOB!' : 'GOOD TRY!'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + i * 200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                i < widget.stars ? '⭐' : '☆',
                                style: TextStyle(
                                  fontSize: 48,
                                  color: i < widget.stars ? null : Colors.white38,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Score
                  Text(
                    '${widget.correctAnswers}/${widget.totalQuestions} Correct',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Coins earned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.coins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Candy3DButton(
                    text: 'Continue 🎮',
                    color: CandyColors.mintGreen,
                    onPressed: widget.onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              CandyColors.bubblegumPink,
              CandyColors.skyBlue,
              CandyColors.lemonYellow,
              CandyColors.mintGreen,
              CandyColors.grapeViolet,
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PARENTAL GATE DIALOG
// ============================================================================
class ParentalGateDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  
  const ParentalGateDialog({super.key, required this.onSuccess});
  
  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog> {
  final _controller = TextEditingController();
  late int _num1;
  late int _num2;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _generateProblem();
  }
  
  void _generateProblem() {
    final random = Random();
    _num1 = 10 + random.nextInt(11); // 10-20
    _num2 = 5 + random.nextInt(11);  // 5-15
  }
  
  void _checkAnswer() {
    final input = int.tryParse(_controller.text);
    if (input == _num1 + _num2) {
      widget.onSuccess();
    } else {
      setState(() {
        _error = 'That\'s not right. Try again!';
        _controller.clear();
        _generateProblem();
      });
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔒 Grown-ups Only',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'To enter settings, please solve:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'What is $_num1 + $_num2?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: CandyColors.grapeViolet,
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                hintText: 'Your answer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                errorText: _error,
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: Candy3DButton(
                    text: 'Cancel',
                    color: Colors.grey[400]!,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Candy3DButton(
                    text: 'Enter',
                    color: CandyColors.mintGreen,
                    onPressed: _checkAnswer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

// 3D Candy-style button
class Candy3DButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;
  
  const Candy3DButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.enabled = true,
  });
  
  @override
  State<Candy3DButton> createState() => _Candy3DButtonState();
}

class _Candy3DButtonState extends State<Candy3DButton> {
  bool _isPressed = false;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      } : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _isPressed ? [] : [
            BoxShadow(
              color: HSLColor.fromColor(widget.color)
                  .withLightness(
                    (HSLColor.fromColor(widget.color).lightness - 0.2).clamp(0, 1),
                  )
                  .toColor(),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 8),
              blurRadius: 8,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        transform: _isPressed 
            ? Matrix4.translationValues(0, 4, 0) 
            : Matrix4.identity(),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: _getTextColor(widget.color),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getTextColor(Color bgColor) {
    final luminance = bgColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF333333) : Colors.white;
  }
}

// Spring page route for transitions
class SpringPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  
  SpringPageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        );
}
