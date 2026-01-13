import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: android);
  await notifications.initialize(initSettings);

  tz.initializeTimeZones();

  runApp(const HabitRoot());
}

/// ---------------- ROOT ----------------
class HabitRoot extends StatefulWidget {
  const HabitRoot({super.key});

  @override
  State<HabitRoot> createState() => _HabitRootState();
}

class _HabitRootState extends State<HabitRoot> {
  bool _dark = false;
  bool _loaded = false;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool("dark") ?? false;
    _seenOnboarding = prefs.getBool("onboarding") ?? false;
    setState(() => _loaded = true);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _dark = !_dark);
    await prefs.setBool("dark", _dark);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("onboarding", true);
    setState(() => _seenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: _seenOnboarding
          ? HabitHomePage(isDark: _dark, onToggleTheme: _toggleTheme)
          : Onboarding(onFinish: _finishOnboarding),
    );
  }
}

/// ---------------- ONBOARDING ----------------
class Onboarding extends StatefulWidget {
  final VoidCallback onFinish;
  const Onboarding({super.key, required this.onFinish});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _pc = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _page(
        Icons.flag,
        "Build Better Habits",
        "Create habits and stay consistent.",
      ),
      _page(Icons.insights, "Track Progress", "See streaks and your growth."),
      _page(
        Icons.notifications_active,
        "Stay Consistent",
        "Get reminders every day.",
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _index = i),
              children: pages,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (i) => Container(
                margin: const EdgeInsets.all(4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_index == pages.length - 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: widget.onFinish,
                child: const Text("Get Started"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _page(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// ---------------- MODEL ----------------
class Habit {
  String id;
  String name;
  String category;
  int streak;
  List<String> history;
  int? hour;
  int? minute;

  Habit({
    required this.id,
    required this.name,
    required this.category,
    this.streak = 0,
    List<String>? history,
    this.hour,
    this.minute,
  }) : history = history ?? [];

  factory Habit.newHabit(String name, String category) {
    return Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      category: category,
    );
  }

  Map<String, dynamic> toMap() => {
    "id": id,
    "name": name,
    "category": category,
    "streak": streak,
    "history": history,
    "hour": hour,
    "minute": minute,
  };

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map["id"],
      name: map["name"],
      category: map["category"],
      streak: map["streak"],
      history: List<String>.from(map["history"] ?? []),
      hour: map["hour"],
      minute: map["minute"],
    );
  }
}

/// ---------------- HOME ----------------
class HabitHomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const HabitHomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HabitHomePage> createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage> {
  List<Habit> habits = [];
  int _page = 0;
  final categories = ["General", "Health", "Study", "Fitness", "Mindset"];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("habits");
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    setState(() {
      habits = list.map((e) => Habit.fromMap(e)).toList();
    });
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "habits",
      jsonEncode(habits.map((e) => e.toMap()).toList()),
    );
  }

  void _addHabit() async {
    String name = "";
    String category = "General";

    final result = await showDialog<Habit>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Habit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(onChanged: (v) => name = v),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: category,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => category = v ?? "General",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                Navigator.pop(context, Habit.newHabit(name.trim(), category));
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => habits.add(result));
      _saveHabits();
    }
  }

  Future<void> _setReminder(Habit h) async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      h.hour = time.hour;
      h.minute = time.minute;
    });

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await notifications.zonedSchedule(
      int.parse(h.id),
      "Habit Reminder",
      "Time for: ${h.name}",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits',
          'Habits',
          importance: Importance.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    _saveHabits();
  }

  void _toggleComplete(Habit h) {
    final today = DateTime.now().toIso8601String().split("T").first;
    if (h.history.contains(today)) return;

    setState(() {
      h.history.add(today);
      h.streak += 1;
    });
    _saveHabits();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_buildHabits(), _buildProgress(), _buildAchievements()];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Habit Tracker"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: pages[_page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: "Habits"),
          NavigationDestination(icon: Icon(Icons.insights), label: "Progress"),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: "Achievements",
          ),
        ],
      ),
      floatingActionButton: _page == 0
          ? FloatingActionButton(
              onPressed: _addHabit,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHabits() {
    return habits.isEmpty
        ? const Center(child: Text("No habits yet"))
        : ListView(
            children: habits.map((h) {
              return Card(
                child: ListTile(
                  title: Text(h.name),
                  subtitle: Text("Streak: ${h.streak}"),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () => _setReminder(h),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _toggleComplete(h),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
  }

  Widget _buildProgress() {
    final today = DateTime.now().toIso8601String().split("T").first;
    final completedToday = habits
        .where((h) => h.history.contains(today))
        .length;
    final best = habits.isEmpty
        ? 0
        : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stat("Total Habits", habits.length),
          _stat("Completed Today", completedToday),
          _stat("Best Streak", best),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    final best = habits.isEmpty
        ? 0
        : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _badge("🥉 3-Day Streak", best >= 3),
        _badge("🥈 7-Day Streak", best >= 7),
        _badge("🥇 30-Day Streak", best >= 30),
      ],
    );
  }

  Widget _stat(String label, int value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String title, bool unlocked) {
    return Card(
      child: ListTile(
        leading: Icon(
          unlocked ? Icons.emoji_events : Icons.lock,
          color: unlocked ? Colors.amber : Colors.grey,
        ),
        title: Text(title),
        subtitle: Text(unlocked ? "Unlocked" : "Locked"),
      ),
    );
  }
}
