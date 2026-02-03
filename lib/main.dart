import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _maxLevel = 10;
const int _xpPerLevel = 100;

class ScienceGameState {
  ScienceGameState({
    int initialLevel = 1,
    int initialXp = 0,
    Set<String>? completedMissions,
    Set<String>? earnedBadges,
  })  : level = initialLevel,
        totalXp = max(initialXp, _xpForLevel(initialLevel)),
        completedMissions = completedMissions ?? <String>{},
        earnedBadges = earnedBadges ?? <String>{};

  int level;
  int totalXp;
  final Set<String> completedMissions;
  final Set<String> earnedBadges;

  bool get isMaxLevel => level >= _maxLevel;

  int get xpWithinCurrentLevel => isMaxLevel ? 0 : totalXp - _xpForLevel(level);

  int get xpNeededForNextLevel => isMaxLevel ? 0 : _xpPerLevel;

  int get xpToLevelUp => isMaxLevel ? 0 : xpNeededForNextLevel - xpWithinCurrentLevel;

  double get progressToNextLevel => isMaxLevel || xpNeededForNextLevel == 0
      ? 1
      : xpWithinCurrentLevel / xpNeededForNextLevel;

  int get displayedXp => totalXp;

  bool canAccessMission(ScienceMission mission) => level >= mission.requiredLevel;

  bool hasCompletedMission(String missionId) => completedMissions.contains(missionId);

  void addXp(int amount) {
    if (amount <= 0) {
      return;
    }
    totalXp += amount;
    while (!isMaxLevel && totalXp >= _xpForLevel(level + 1)) {
      level++;
    }
  }

  void markMissionComplete(String missionId) {
    completedMissions.add(missionId);
  }

  void grantBadge(String badgeId) {
    earnedBadges.add(badgeId);
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'totalXp': totalXp,
        'completedMissions': completedMissions.toList(),
        'earnedBadges': earnedBadges.toList(),
      };

  factory ScienceGameState.fromJson(Map<String, dynamic> json) {
    final state = ScienceGameState(
      initialLevel: json['level'] as int? ?? 1,
      initialXp: json['totalXp'] as int? ?? 0,
      completedMissions: (json['completedMissions'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      earnedBadges: (json['earnedBadges'] as List<dynamic>?)?.map((e) => e as String).toSet(),
    );
    return state;
  }
}

class GameStorageService {
  static const _gameStateKey = 'game_state';
  static const _streakKey = 'play_streak';
  static const _playerNameKey = 'player_name';

  final SharedPreferences _prefs;

  GameStorageService(this._prefs);

  Future<void> saveGameState(ScienceGameState state) async {
    await _prefs.setString(_gameStateKey, jsonEncode(state.toJson()));
  }

  ScienceGameState loadGameState() {
    final jsonStr = _prefs.getString(_gameStateKey);
    if (jsonStr == null) {
      return ScienceGameState();
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ScienceGameState.fromJson(json);
    } catch (_) {
      return ScienceGameState();
    }
  }

  Future<void> saveStreak(List<bool> streak) async {
    await _prefs.setStringList(_streakKey, streak.map((b) => b ? '1' : '0').toList());
  }

  List<bool> loadStreak() {
    final list = _prefs.getStringList(_streakKey);
    if (list == null || list.length != 7) {
      return List.filled(7, false);
    }
    return list.map((s) => s == '1').toList();
  }

  Future<void> markTodayPlayed() async {
    final streak = loadStreak();
    final todayIndex = DateTime.now().weekday - 1; // Monday = 0
    streak[todayIndex] = true;
    await saveStreak(streak);
  }

  Future<void> savePlayerName(String name) async {
    await _prefs.setString(_playerNameKey, name);
  }

  String loadPlayerName() {
    return _prefs.getString(_playerNameKey) ?? 'Star Kid';
  }
}

int _xpForLevel(int level) => max(0, (level - 1) * _xpPerLevel);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storage = GameStorageService(prefs);
  runApp(KidsScienceApp(storage: storage));
}

class KidsScienceApp extends StatelessWidget {
  const KidsScienceApp({super.key, required this.storage});

  final GameStorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny Science Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
          brightness: Brightness.light,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'ComicNeue',
            ),
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF2D1B69),
          indicatorColor: const Color(0xFFFF6B6B),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white, size: 28);
            }
            return const IconThemeData(color: Colors.white54, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
            }
            return const TextStyle(color: Colors.white54, fontSize: 11);
          }),
        ),
      ),
      home: ScienceQuestShell(storage: storage),
    );
  }
}

class ScienceQuestShell extends StatefulWidget {
  const ScienceQuestShell({super.key, required this.storage});

  final GameStorageService storage;

  @override
  State<ScienceQuestShell> createState() => _ScienceQuestShellState();
}

class _ScienceQuestShellState extends State<ScienceQuestShell> {
  int _tabIndex = 0;
  late ScienceGameState _gameState;
  late String _playerName;
  late List<bool> _weekStreak;

  GameStorageService get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _gameState = _storage.loadGameState();
    _playerName = _storage.loadPlayerName();
    _weekStreak = _storage.loadStreak();
  }

  Future<void> _saveProgress() async {
    await _storage.saveGameState(_gameState);
    await _storage.markTodayPlayed();
    if (mounted) {
      setState(() {
        _weekStreak = _storage.loadStreak();
      });
    }
  }

  Future<void> _updatePlayerName(String name) async {
    await _storage.savePlayerName(name);
    if (mounted) {
      setState(() {
        _playerName = name;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleMissionSelected(ScienceMission mission) async {
    if (!_gameState.canAccessMission(mission)) {
      _showSnackBar('Get to level ${mission.requiredLevel} to play this game.');
      return;
    }

    final questions = missionQuestions[mission.id];
    if (questions == null || questions.isEmpty) {
      _showSnackBar('More fun coming soon.');
      return;
    }

    final result = await Navigator.of(context).push<MissionPlayResult>(
      MaterialPageRoute(
        builder: (_) => MissionPlayPage(
          mission: mission,
          questions: questions,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final accuracy = result.accuracy;
    final earnedXp = (mission.xpReward * accuracy).round().clamp(50, mission.xpReward);
    final wasSuccessful = accuracy >= 0.5;
    final previousLevel = _gameState.level;
    late List<ScienceBadge> newlyEarnedBadges;
    
    setState(() {
      final newlyCompleted = wasSuccessful && !_gameState.hasCompletedMission(mission.id);
      _gameState.addXp(earnedXp);
      if (newlyCompleted) {
        _gameState.markMissionComplete(mission.id);
      }
      newlyEarnedBadges = _evaluateBadgeAwards(
        mission,
        result,
        wasSuccessful: wasSuccessful,
      );
      for (final badge in newlyEarnedBadges) {
        _gameState.grantBadge(badge.title);
      }
    });

    // Haptic feedback for success
    if (wasSuccessful) {
      HapticFeedback.mediumImpact();
    }

    // Show level up celebration
    if (_gameState.level > previousLevel && mounted) {
      await _showLevelUpCelebration(_gameState.level);
    }

    final badgeSummary = newlyEarnedBadges.isEmpty
      ? ''
      : ' + Stickers: ${newlyEarnedBadges.map((b) => b.title).join(', ')}';
    _showSnackBar('Awesome job! +$earnedXp stars$badgeSummary');

    // Persist progress
    await _saveProgress();
  }

  List<ScienceBadge> _evaluateBadgeAwards(
    ScienceMission mission,
    MissionPlayResult result, {
    required bool wasSuccessful,
  }) {
    final badgesEarned = <ScienceBadge>[];

    ScienceBadge? resolveBadge(String title) {
      for (final badge in scienceBadges) {
        if (badge.title == title) {
          return badge;
        }
      }
      return null;
    }

    void considerBadge(String title, bool condition) {
      if (!condition) {
        return;
      }
      if (_gameState.earnedBadges.contains(title)) {
        return;
      }
      if (badgesEarned.any((badge) => badge.title == title)) {
        return;
      }
      final badge = resolveBadge(title);
      if (badge != null) {
        badgesEarned.add(badge);
      }
    }

    considerBadge('Color Star', wasSuccessful);
    considerBadge('Shape Champ', _gameState.completedMissions.length >= 2);
    considerBadge('Super Listener', result.accuracy >= 0.95);
    considerBadge('Animal Helper', _gameState.level >= 7);

    return badgesEarned;
  }

  Future<void> _showLevelUpCelebration(int newLevel) async {
    HapticFeedback.heavyImpact();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LevelUpDialog(level: newLevel),
    );
  }

  void _goToGamesTab() {
    setState(() => _tabIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final views = <Widget>[
      ScienceMapView(gameState: _gameState),
      ScienceMissionsView(
        gameState: _gameState,
        onMissionSelected: _handleMissionSelected,
      ),
      ScienceProfileView(
        gameState: _gameState,
        playerName: _playerName,
        weekStreak: _weekStreak,
        onNameChanged: _updatePlayerName,
        onResumePressed: _goToGamesTab,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: views,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        height: 70,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore),
            label: 'Play Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.science),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'Me',
          ),
        ],
        onDestinationSelected: (value) {
          setState(() => _tabIndex = value);
        },
      ),
    );
  }
}

class ScienceMapView extends StatelessWidget {
  const ScienceMapView({super.key, required this.gameState});

  final ScienceGameState gameState;

  @override
  Widget build(BuildContext context) {
    final currentLevel = gameState.level;
    final totalLevels = _maxLevel;
    final levelProgress = currentLevel / totalLevels;
    final world = scienceWorlds.firstWhere(
      (w) => currentLevel >= w.startLevel && currentLevel <= w.endLevel,
      orElse: () => scienceWorlds.first,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _GalaxyHeader(currentLevel: currentLevel, world: world, progress: levelProgress),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final level = scienceLevels[index];
                    final isUnlocked = level.index <= currentLevel;
                    final isCurrent = level.index == currentLevel;
                    return LevelOrb(
                      level: level,
                      isUnlocked: isUnlocked,
                      isCurrent: isCurrent,
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: scienceLevels.length,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Play Zones',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: scienceWorlds.length,
                itemBuilder: (_, index) {
                  final item = scienceWorlds[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ScienceWorldCard(
                      world: item,
                      isActive: world == item,
                      progress: _worldProgress(item, currentLevel),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _worldProgress(ScienceWorld world, int currentLevel) {
    if (currentLevel < world.startLevel) {
      return 0;
    }
    if (currentLevel >= world.endLevel) {
      return 1;
    }
    final range = world.endLevel - world.startLevel;
    return (currentLevel - world.startLevel) / range;
  }
}

class ScienceMissionsView extends StatelessWidget {
  const ScienceMissionsView({
    super.key,
    required this.gameState,
    required this.onMissionSelected,
  });

  final ScienceGameState gameState;
  final ValueChanged<ScienceMission> onMissionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF), Color(0xFFFECDD3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          itemBuilder: (_, index) {
            final mission = scienceMissions[index];
            final isUnlocked = gameState.canAccessMission(mission);
            final isCompleted = gameState.hasCompletedMission(mission.id);
            return MissionCard(
              mission: mission,
              isUnlocked: isUnlocked,
              isCompleted: isCompleted,
              onPlay: () => onMissionSelected(mission),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: scienceMissions.length,
        ),
      ),
    );
  }
}

class MissionPlayResult {
  const MissionPlayResult({
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int correctAnswers;
  final int totalQuestions;

  double get accuracy => totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;
}

class MissionPlayPage extends StatefulWidget {
  const MissionPlayPage({
    super.key,
    required this.mission,
    required this.questions,
  });

  final ScienceMission mission;
  final List<ScienceQuestion> questions;

  @override
  State<MissionPlayPage> createState() => _MissionPlayPageState();
}

class _MissionPlayPageState extends State<MissionPlayPage> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _showFeedback = false;

  ScienceQuestion get _currentQuestion => widget.questions[_questionIndex];

  void _handleAnswerTap(int index) {
    if (_showFeedback) {
      return;
    }
    setState(() {
      _selectedAnswer = index;
      if (index == _currentQuestion.correctIndex) {
        _score++;
      }
      _showFeedback = true;
    });
  }

  void _goToNext() {
    if (!_showFeedback) {
      return;
    }
    final isLastQuestion = _questionIndex == widget.questions.length - 1;
    if (isLastQuestion) {
      Navigator.of(context).pop(
        MissionPlayResult(
          correctAnswers: _score,
          totalQuestions: widget.questions.length,
        ),
      );
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
      _showFeedback = false;
    });
  }

  Color _answerColor(int index) {
    if (!_showFeedback) {
      return Colors.white.withOpacity(0.12);
    }
    if (index == _currentQuestion.correctIndex) {
      return const Color(0xFF22C55E).withOpacity(0.85);
    }
    if (_selectedAnswer == index) {
      return const Color(0xFFEF4444).withOpacity(0.85);
    }
    return Colors.white.withOpacity(0.08);
  }

  IconData _answerIcon(int index) {
    if (!_showFeedback) {
      return Icons.help_outline;
    }
    if (index == _currentQuestion.correctIndex) {
      return Icons.check_circle_outline;
    }
    if (_selectedAnswer == index) {
      return Icons.cancel_outlined;
    }
    return Icons.circle_outlined;
  }

  Widget _buildAnswerOption(BuildContext context, int index) {
    final answer = _currentQuestion.answers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _answerColor(index),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleAnswerTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_answerIcon(index), color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    answer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final totalQuestions = widget.questions.length;
    final question = _currentQuestion;
    final theme = Theme.of(context);
    final isLastQuestion = _questionIndex == totalQuestions - 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mission.primaryColor,
        foregroundColor: Colors.white,
        title: Text(mission.title),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [mission.primaryColor, mission.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      backgroundColor: Colors.white.withOpacity(0.18),
                      label: Text(
                        'Score $_score',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      backgroundColor: Colors.white.withOpacity(0.18),
                      label: Text(
                        'Question ${_questionIndex + 1}/$totalQuestions',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.prompt,
                            style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 20),
                          for (var index = 0; index < question.answers.length; index++)
                            _buildAnswerOption(context, index),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_showFeedback && question.explanation.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      question.explanation,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showFeedback ? _goToNext : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.white,
                    foregroundColor: mission.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: Icon(isLastQuestion ? Icons.flag : Icons.arrow_forward_rounded),
                  label: Text(isLastQuestion ? 'Finish Mission' : 'Next Question'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScienceProfileView extends StatelessWidget {
  const ScienceProfileView({
    super.key,
    required this.gameState,
    required this.playerName,
    required this.weekStreak,
    required this.onNameChanged,
    required this.onResumePressed,
  });

  final ScienceGameState gameState;
  final String playerName;
  final List<bool> weekStreak;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onResumePressed;

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: playerName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What\'s your name?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type your name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                onNameChanged(newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = gameState.level;
    final xp = gameState.displayedXp;
    final badges = scienceBadges;
    final isMaxLevel = gameState.isMaxLevel;
    final xpProgress = gameState.progressToNextLevel;
    final xpToNext = gameState.xpToLevelUp;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4158D0), Color(0xFFC850C0), Color(0xFFFFCC70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B9DFF), Color(0xFF9B6CFF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showEditNameDialog(context),
                          child: Row(
                            children: [
                              Text(
                                playerName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit, color: Colors.white54, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level $currentLevel Super Kid',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                    _XpPill(xp: xp),
                ],
              ),
              const SizedBox(height: 32),
                if (!isMaxLevel) ...[
                  Text(
                    'Level Bar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 14,
                      color: const Color(0xFFF97316),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$xpToNext stars to level up',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  Text(
                    'Max Level Reached!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              Text(
                'Stickers',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final badge = badges[index];
                    final isUnlocked = gameState.earnedBadges.contains(badge.title);
                    return BadgeTile(badge: badge, isUnlocked: isUnlocked);
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: badges.length,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Play Week',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _StreakHeatmap(streak: weekStreak),
              const SizedBox(height: 24),
              _BouncingButton(
                onPressed: onResumePressed,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Play Games!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalaxyHeader extends StatelessWidget {
  const _GalaxyHeader({
    required this.currentLevel,
    required this.world,
    required this.progress,
  });

  final int currentLevel;
  final ScienceWorld world;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: world.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level $currentLevel',
                style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                world.title,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).round()}% to next level',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        Positioned(
          right: -20,
          top: -20,
          child: Transform.rotate(
            angle: -pi / 24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: world.gradient.reversed.toList()),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                world.icon,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LevelOrb extends StatelessWidget {
  const LevelOrb({
    super.key,
    required this.level,
    required this.isUnlocked,
    required this.isCurrent,
  });

  final ScienceLevel level;
  final bool isUnlocked;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent ? Colors.white : Colors.white24;
    final background = isUnlocked ? level.gradient : [Colors.white10, Colors.white12];
    final iconColor = isUnlocked ? Colors.white : Colors.white38;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        gradient: LinearGradient(
          colors: background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          if (isCurrent)
            const BoxShadow(
              color: Color(0x66FFFFFF),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(level.icon, color: iconColor, size: 28),
          const Spacer(),
          Text(
            'Level ${level.index}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            level.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class ScienceWorldCard extends StatelessWidget {
  const ScienceWorldCard({
    super.key,
    required this.world,
    required this.isActive,
    required this.progress,
  });

  final ScienceWorld world;
  final bool isActive;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isActive ? world.gradient : world.gradient.map((c) => c.withOpacity(0.6)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isActive ? Colors.white : Colors.white24,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(world.icon, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Levels ${world.startLevel}-${world.endLevel}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: Colors.white,
                    backgroundColor: Colors.white30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.isUnlocked,
    required this.isCompleted,
    required this.onPlay,
  });

  final ScienceMission mission;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mission.primaryColor, mission.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: mission.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  mission.levelLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Icon(isUnlocked ? mission.icon : Icons.lock_outline, color: Colors.white, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            mission.title,
            style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            mission.description,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.stars, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text('${mission.xpReward} XP', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
              const Spacer(),
              ElevatedButton(
                onPressed: isUnlocked ? onPlay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: mission.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(isUnlocked ? (isCompleted ? 'Replay' : 'Play') : 'Locked'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, required this.isUnlocked});

  final ScienceBadge badge;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1 : 0.45,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [badge.primaryColor, badge.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: badge.primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(badge.icon, color: Colors.white, size: 32),
            const Spacer(),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 4),
              Text(
                'Keep Playing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _XpPill extends StatelessWidget {
  const _XpPill({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(
            '$xp stars',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StreakHeatmap extends StatelessWidget {
  const _StreakHeatmap({required this.streak});

  final List<bool> streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(streak.length, (index) {
        final played = streak[index];
        final day = _weekdayLabel(index);
        final isToday = DateTime.now().weekday - 1 == index;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isToday ? 52 : 48,
              height: isToday ? 52 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: played
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: played ? null : Colors.white24,
                border: isToday ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: played
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: played
                    ? const Icon(Icons.star, color: Colors.white, size: 24)
                    : Text(
                        day.substring(0, 1),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isToday ? Colors.white : Colors.white70,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ],
        );
      }),
    );
  }

  String _weekdayLabel(int index) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index % labels.length];
  }
}

// Bouncing button animation widget
class _BouncingButton extends StatefulWidget {
  const _BouncingButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

// Level up celebration dialog
class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.level});

  final int level;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B), Color(0xFFC850C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              const Text(
                'LEVEL UP!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${widget.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are amazing! ⭐',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF6B6B),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Yay! 🎊',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScienceLevel {
  const ScienceLevel({
    required this.index,
    required this.title,
    required this.icon,
    required this.gradient,
  });

  final int index;
  final String title;
  final IconData icon;
  final List<Color> gradient;
}

class ScienceWorld {
  const ScienceWorld({
    required this.title,
    required this.startLevel,
    required this.endLevel,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final int startLevel;
  final int endLevel;
  final List<Color> gradient;
  final IconData icon;
}

class ScienceMission {
  const ScienceMission({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredLevel,
    required this.xpReward,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String id;
  final String title;
  final String description;
  final int requiredLevel;
  final int xpReward;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;

  String get levelLabel => 'Level $requiredLevel';
}

class ScienceQuestion {
  const ScienceQuestion({
    required this.prompt,
    required this.answers,
    required this.correctIndex,
    this.explanation = '',
  });

  final String prompt;
  final List<String> answers;
  final int correctIndex;
  final String explanation;
}

class ScienceBadge {
  const ScienceBadge({
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String title;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
}

final scienceWorlds = <ScienceWorld>[
  const ScienceWorld(
    title: 'Color Camp',
    startLevel: 0,
    endLevel: 3,
    gradient: [Color(0xFFFFF176), Color(0xFFFF8A65)],
    icon: Icons.palette,
  ),
  const ScienceWorld(
    title: 'Shape Sky',
    startLevel: 4,
    endLevel: 6,
    gradient: [Color(0xFF81D4FA), Color(0xFF4FC3F7)],
    icon: Icons.category,
  ),
  const ScienceWorld(
    title: 'Animal Meadow',
    startLevel: 7,
    endLevel: 10,
    gradient: [Color(0xFFA5D6A7), Color(0xFF66BB6A)],
    icon: Icons.pets,
  ),
];

final scienceLevels = List.generate(_maxLevel + 1, (index) {
  final levelName = _levelTitle(index);
  final palette = _levelGradient(index);
  final icon = _levelIcon(index);
  return ScienceLevel(
    index: index,
    title: levelName,
    icon: icon,
    gradient: palette,
  );
});

final scienceMissions = <ScienceMission>[
  const ScienceMission(
    id: 'color_match',
    title: 'Color Match Party',
    description: 'Tap the paint spots that look the same.',
    requiredLevel: 1,
    xpReward: 80,
    icon: Icons.color_lens,
    primaryColor: Color(0xFFFFF176),
    secondaryColor: Color(0xFFFFB74D),
  ),
  const ScienceMission(
    id: 'shape_hunt',
    title: 'Shape Hunt Picnic',
    description: 'Find the shapes that fit your blanket.',
    requiredLevel: 4,
    xpReward: 90,
    icon: Icons.extension,
    primaryColor: Color(0xFF4FC3F7),
    secondaryColor: Color(0xFF29B6F6),
  ),
  const ScienceMission(
    id: 'animal_calls',
    title: 'Animal Calling Game',
    description: 'Help the baby animals find their sound.',
    requiredLevel: 7,
    xpReward: 100,
    icon: Icons.pets,
    primaryColor: Color(0xFFA5D6A7),
    secondaryColor: Color(0xFF81C784),
  ),
];

final missionQuestions = <String, List<ScienceQuestion>>{
  'color_match': [
    const ScienceQuestion(
      prompt: 'Which color is the same as the sun?',
      answers: [
        'Yellow',
        'Blue',
        'Purple',
      ],
      correctIndex: 0,
      explanation: 'The sun in our picture is bright yellow.',
    ),
    const ScienceQuestion(
      prompt: 'Pick the color of grass.',
      answers: [
        'Green',
        'Pink',
        'Gray',
      ],
      correctIndex: 0,
      explanation: 'Fresh grass is green and comfy to sit on.',
    ),
    const ScienceQuestion(
      prompt: 'Which two colors make orange?',
      answers: [
        'Red and yellow',
        'Blue and green',
        'Purple and pink',
      ],
      correctIndex: 0,
      explanation: 'Mixing red and yellow paint makes orange.',
    ),
  ],
  'shape_hunt': [
    const ScienceQuestion(
      prompt: 'Which shape has three sides?',
      answers: [
        'Triangle',
        'Circle',
        'Square',
      ],
      correctIndex: 0,
      explanation: 'A triangle has three straight sides.',
    ),
    const ScienceQuestion(
      prompt: 'Which shape can roll like a wheel?',
      answers: [
        'Circle',
        'Rectangle',
        'Triangle',
      ],
      correctIndex: 0,
      explanation: 'Circles are round so they roll easily.',
    ),
    const ScienceQuestion(
      prompt: 'Pick the shape with four equal sides.',
      answers: [
        'Square',
        'Oval',
        'Star',
      ],
      correctIndex: 0,
      explanation: 'A square is like a box with matching sides.',
    ),
  ],
  'animal_calls': [
    const ScienceQuestion(
      prompt: 'Which animal says “moo”?',
      answers: [
        'Cow',
        'Duck',
        'Cat',
      ],
      correctIndex: 0,
      explanation: 'Cows make the gentle “moo” sound.',
    ),
    const ScienceQuestion(
      prompt: 'Who quacks on the pond?',
      answers: [
        'Duck',
        'Puppy',
        'Horse',
      ],
      correctIndex: 0,
      explanation: 'Ducks quack while they splash.',
    ),
    const ScienceQuestion(
      prompt: 'Which friend purrs when happy?',
      answers: [
        'Cat',
        'Frog',
        'Sheep',
      ],
      correctIndex: 0,
      explanation: 'Cats purr softly when they feel cozy.',
    ),
  ],
};

final scienceBadges = <ScienceBadge>[
  const ScienceBadge(
    title: 'Color Star',
    icon: Icons.color_lens,
    primaryColor: Color(0xFFFFF59D),
    secondaryColor: Color(0xFFFFEB3B),
  ),
  const ScienceBadge(
    title: 'Shape Champ',
    icon: Icons.extension,
    primaryColor: Color(0xFF4FC3F7),
    secondaryColor: Color(0xFF29B6F6),
  ),
  const ScienceBadge(
    title: 'Animal Helper',
    icon: Icons.pets,
    primaryColor: Color(0xFFA5D6A7),
    secondaryColor: Color(0xFF81C784),
  ),
  const ScienceBadge(
    title: 'Super Listener',
    icon: Icons.hearing,
    primaryColor: Color(0xFFFFCC80),
    secondaryColor: Color(0xFFFFB74D),
  ),
];

String _levelTitle(int level) {
  if (level == 0) {
    return 'Ready to Play';
  }
  if (level <= 3) {
    return 'Color Explorer';
  }
  if (level <= 6) {
    return 'Shape Detective';
  }
  if (level <= 10) {
    return 'Animal Friend';
  }
  return 'Super Star';
}

List<Color> _levelGradient(int level) {
  if (level <= 3) {
    return const [Color(0xFFFFF59D), Color(0xFFFFF176)];
  }
  if (level <= 6) {
    return const [Color(0xFF81D4FA), Color(0xFF4FC3F7)];
  }
  if (level <= 10) {
    return const [Color(0xFFA5D6A7), Color(0xFF66BB6A)];
  }
  return const [Color(0xFFFFCC80), Color(0xFFFFB74D)];
}

IconData _levelIcon(int level) {
  if (level <= 3) {
    return Icons.palette;
  }
  if (level <= 6) {
    return Icons.extension;
  }
  if (level <= 10) {
    return Icons.pets;
  }
  return Icons.star;
}
