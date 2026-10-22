import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const navy = Color(0xFF061526);
const navy2 = Color(0xFF0A1F38);
const blue = Color(0xFF2F80FF);
const gold = Color(0xFFF5C75D);
const soft = Color(0xFF9DAABD);
const card = Color(0xFF0D223B);
const danger = Color(0xFFFF6B6B);

void main() => runApp(const LifeInboxApp());

class LifeInboxApp extends StatefulWidget {
  const LifeInboxApp({super.key});
  @override
  State<LifeInboxApp> createState() => _LifeInboxAppState();
}

class _LifeInboxAppState extends State<LifeInboxApp> {
  final store = LoopStore();
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Life Inbox',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      fontFamily: 'Arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 1.2),
        ),
      ),
    ),
    home: !ready ? const SplashScreen() : AppGate(store: store),
  );
}

class LoopStore extends ChangeNotifier {
  static const key = 'life_inbox_loops';
  final List<OpenLoop> loops = [];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    loops.clear();
    if (raw != null) {
      loops.addAll((jsonDecode(raw) as List).map((e) => OpenLoop.fromJson(e)));
    } else {
      // Seed demo examples only on a fresh install; do not recreate deleted loops later.
      loops.addAll(demoLoops());
      await p.setString(key, jsonEncode(loops.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(loops.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> add(OpenLoop l) async {
    loops.insert(0, l);
    await save();
  }

  Future<void> update(OpenLoop l) async {
    final i = loops.indexWhere((x) => x.id == l.id);
    if (i >= 0) loops[i] = l;
    await save();
  }

  Future<void> remove(String id) async {
    loops.removeWhere((x) => x.id == id);
    await save();
  }
}

enum LoopType { money, order, promise, issue }

enum LoopStatus {
  active,
  waiting,
  dueSoon,
  overdue,
  followUp,
  resolved,
  cancelled,
}

class OpenLoop {
  final String id, title, description, responsible, expectedOutcome, source;
  final LoopType type;
  LoopStatus status;
  final DateTime createdAt;
  DateTime? expectedDate, resolvedAt;
  final double? amount;
  final String? reference;
  final List<String> evidence;
  final List<TimelineEvent> events;
  OpenLoop({
    required this.id,
    required this.title,
    required this.description,
    required this.responsible,
    required this.expectedOutcome,
    required this.source,
    required this.type,
    required this.status,
    required this.createdAt,
    this.expectedDate,
    this.resolvedAt,
    this.amount,
    this.reference,
    this.evidence = const [],
    this.events = const [],
  });
  OpenLoop copyWith({
    String? title,
    String? description,
    String? responsible,
    String? expectedOutcome,
    LoopStatus? status,
    DateTime? expectedDate,
    DateTime? resolvedAt,
    double? amount,
    String? reference,
    List<String>? evidence,
    List<TimelineEvent>? events,
  }) => OpenLoop(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    responsible: responsible ?? this.responsible,
    expectedOutcome: expectedOutcome ?? this.expectedOutcome,
    source: source,
    type: type,
    status: status ?? this.status,
    createdAt: createdAt,
    expectedDate: expectedDate ?? this.expectedDate,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    amount: amount ?? this.amount,
    reference: reference ?? this.reference,
    evidence: evidence ?? this.evidence,
    events: events ?? this.events,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'responsible': responsible,
    'expectedOutcome': expectedOutcome,
    'source': source,
    'type': type.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expectedDate': expectedDate?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'amount': amount,
    'reference': reference,
    'evidence': evidence,
    'events': events.map((e) => e.toJson()).toList(),
  };
  factory OpenLoop.fromJson(Map<String, dynamic> j) => OpenLoop(
    id: j['id'],
    title: j['title'],
    description: j['description'],
    responsible: j['responsible'],
    expectedOutcome: j['expectedOutcome'],
    source: j['source'],
    type: LoopType.values.byName(j['type']),
    status: LoopStatus.values.byName(j['status']),
    createdAt: DateTime.parse(j['createdAt']),
    expectedDate: j['expectedDate'] == null
        ? null
        : DateTime.parse(j['expectedDate']),
    resolvedAt: j['resolvedAt'] == null
        ? null
        : DateTime.parse(j['resolvedAt']),
    amount: (j['amount'] as num?)?.toDouble(),
    reference: j['reference'],
    evidence: List<String>.from(j['evidence'] ?? []),
    events: (j['events'] as List? ?? [])
        .map((e) => TimelineEvent.fromJson(e))
        .toList(),
  );
}

class TimelineEvent {
  final DateTime time;
  final String text;
  TimelineEvent(this.time, this.text);
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'text': text,
  };
  factory TimelineEvent.fromJson(Map<String, dynamic> j) =>
      TimelineEvent(DateTime.parse(j['time']), j['text']);
}

List<OpenLoop> demoLoops() => [
  OpenLoop(
    id: '1',
    title: 'Amazon refund ₹2,499',
    description: 'Refund expected after return was completed.',
    responsible: 'Amazon',
    expectedOutcome: '₹2,499 refund received',
    source: 'Demo',
    type: LoopType.money,
    status: LoopStatus.waiting,
    createdAt: DateTime.now().subtract(const Duration(days: 6)),
    expectedDate: DateTime.now().add(const Duration(days: 1)),
    amount: 2499,
    reference: 'REF-2499',
    events: [
      TimelineEvent(
        DateTime.now().subtract(const Duration(days: 6)),
        'Return completed and refund requested',
      ),
    ],
  ),
  OpenLoop(
    id: '2',
    title: 'AC repair callback',
    description: 'Service centre promised a technician visit.',
    responsible: 'Service Centre',
    expectedOutcome: 'Technician visits and repair is completed',
    source: 'Demo',
    type: LoopType.issue,
    status: LoopStatus.overdue,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    expectedDate: DateTime.now().subtract(const Duration(days: 1)),
    events: [
      TimelineEvent(
        DateTime.now().subtract(const Duration(days: 3)),
        'Technician promised for yesterday',
      ),
    ],
  ),
  OpenLoop(
    id: '3',
    title: 'Kunal owes ₹5,000',
    description: 'Repayment promised.',
    responsible: 'Kunal',
    expectedOutcome: '₹5,000 repaid',
    source: 'Demo',
    type: LoopType.promise,
    status: LoopStatus.dueSoon,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    expectedDate: DateTime.now().add(const Duration(days: 2)),
    amount: 5000,
    events: [
      TimelineEvent(
        DateTime.now().subtract(const Duration(days: 2)),
        'Promise recorded',
      ),
    ],
  ),
  OpenLoop(
    id: '4',
    title: 'Flipkart return pickup',
    description: 'Return pickup scheduled.',
    responsible: 'Flipkart',
    expectedOutcome: 'Return picked up and replacement/refund completed',
    source: 'Demo',
    type: LoopType.order,
    status: LoopStatus.active,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    expectedDate: DateTime.now().add(const Duration(days: 1)),
    reference: 'OD-7788',
    events: [
      TimelineEvent(
        DateTime.now().subtract(const Duration(days: 1)),
        'Return request captured',
      ),
    ],
  ),
];

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020B17), Color(0xFF061526), Color(0xFF00121F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/life_inbox_logo.png',
                  width: 124,
                  height: 124,
                ),
                const SizedBox(height: 22),
                const Text(
                  'LIFE INBOX',
                  style: TextStyle(
                    fontSize: 29,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "IF IT'S NOT RESOLVED, IT'S NOT DONE.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.7,
                    color: Color(0xFFF3E8CF),
                  ),
                ),
                const SizedBox(height: 38),
                const Text(
                  'Capture Today   •   Stay on Track   •   Close Tomorrow',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF69B2FF), fontSize: 11),
                ),
                const SizedBox(height: 52),
                Container(
                  width: 46,
                  height: 3,
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'A more organised you.\nA lighter tomorrow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: soft, height: 1.8, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final pc = PageController();
  int page = 0;
  final data = const [
    [
      'assets/images/onboarding_capture.png',
      'Capture what matters',
      'Keep screenshots, promises, refunds, orders, complaints and important things in one place.',
    ],
    [
      'assets/images/onboarding_tracking.png',
      'Know what you are waiting on',
      'Life Inbox keeps track of people, companies and outcomes that are still unresolved.',
    ],
    [
      'assets/images/onboarding_resolve.png',
      'Stay on it until it is resolved',
      'A reminder is not completion. Life Inbox stays with you until the outcome is actually closed.',
    ],
  ];
  Future<void> next() async {
    if (page < 2) {
      pc.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('li_onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  Future<void> skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('li_onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020B17),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: skipOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pc,
                itemCount: data.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (context, i) {
                  final item = data[i];
                  return Column(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: Image.asset(
                            item[0],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          item[1],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          item[2],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: soft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(
                        data.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 7),
                          width: i == page ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == page ? gold : Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF00151C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            page == 2 ? 'Get Started' : 'Continue',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 9),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF041124), navy, Color(0xFF03101F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/life_inbox_logo.png',
                      width: 112,
                      height: 112,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'LIFE INBOX',
                      style: TextStyle(
                        fontSize: 23,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "IF IT'S NOT RESOLVED, IT'S NOT DONE.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF3E8CF),
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                "Let's get you started",
                style: TextStyle(color: soft, fontSize: 15),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => showInfo(
                    context,
                    'Google sign-in will be connected with the authentication provider.',
                  ),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: blue.withValues(alpha: .65)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => showInfo(
                    context,
                    'Apple sign-in will be connected when authentication is configured.',
                  ),
                  icon: const Icon(Icons.phone_iphone_rounded, size: 22),
                  label: const Text('Continue with Apple'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  icon: const Icon(Icons.mail_outline_rounded, size: 21),
                  label: const Text('Continue with Email'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Already have an account?  Log in'),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: soft, fontSize: 10, height: 1.5),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (name.text.trim().isEmpty ||
        !email.text.contains('@') ||
        pass.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your name, a valid email, and a password of at least 6 characters.',
          ),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('li_profile_name', name.text.trim());
    await prefs.setString('li_profile_email', email.text.trim());
    await prefs.setBool('li_logged_in', true);
    await prefs.setBool('li_onboarding_done', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(store: globalStore!)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext c) => AuthScaffold(
    title: 'Create your account',
    subtitle: 'Start organising the things you are waiting on.',
    children: [
      field('Full name', name, 'Your full name', Icons.person_outline),
      field(
        'Email address',
        email,
        'you@example.com',
        Icons.mail_outline,
        keyboard: TextInputType.emailAddress,
      ),
      field(
        'Password',
        pass,
        'Create a password',
        Icons.lock_outline,
        obscure: obscure,
        suffix: IconButton(
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: create,
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: navy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Create Account  →',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacement(
            c,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text('Already have an account?  Log in'),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your captured information stays on this device in this local prototype. Secure account sync is a separate integration step.',
        style: TextStyle(color: soft, fontSize: 11, height: 1.45),
      ),
    ],
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty ||
        !email.text.contains('@') ||
        pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email and password to continue.'),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('li_profile_email', email.text.trim());
    if ((prefs.getString('li_profile_name') ?? '').isEmpty)
      await prefs.setString('li_profile_name', 'Life Inbox user');
    await prefs.setBool('li_logged_in', true);
    await prefs.setBool('li_onboarding_done', true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(store: globalStore!)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext c) => AuthScaffold(
    title: 'Welcome back',
    subtitle: 'Good to see you again.',
    children: [
      field(
        'Email address',
        email,
        'you@example.com',
        Icons.mail_outline,
        keyboard: TextInputType.emailAddress,
      ),
      field(
        'Password',
        pass,
        'Your password',
        Icons.lock_outline,
        obscure: obscure,
        suffix: IconButton(
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      Row(
        children: [
          const Icon(Icons.check_box_rounded, color: gold, size: 18),
          const SizedBox(width: 8),
          const Text('Remember me', style: TextStyle(fontSize: 12)),
          const Spacer(),
          TextButton(
            onPressed: () => showInfo(
              c,
              'Password reset will be connected with the authentication provider.',
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: login,
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: navy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'Log In  →',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacement(
            c,
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          ),
          child: const Text("Don't have an account?  Sign up"),
        ),
      ),
    ],
  );
}

Widget field(
  String label,
  TextEditingController ctl,
  String hint,
  IconData icon, {
  TextInputType? keyboard,
  bool obscure = false,
  Widget? suffix,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: ctl,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: blue),
          suffixIcon: suffix,
        ),
      ),
    ],
  ),
);

class AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.pop(c),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/images/life_inbox_logo.png',
                width: 62,
                height: 62,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: soft, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

LoopStore? globalStore;

class AppGate extends StatefulWidget {
  final LoopStore store;
  const AppGate({super.key, required this.store});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool loaded = false;
  bool loggedIn = false;
  bool onboardingDone = false;
  @override
  void initState() {
    super.initState();
    globalStore = widget.store;
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      loggedIn = prefs.getBool('li_logged_in') ?? false;
      onboardingDone = prefs.getBool('li_onboarding_done') ?? false;
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const SplashScreen();
    if (loggedIn) return HomeScreen(store: widget.store);
    if (onboardingDone) return const WelcomeScreen();
    return const OnboardingScreen();
  }
}

class HomeScreen extends StatefulWidget {
  final LoopStore store;
  const HomeScreen({super.key, required this.store});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final pages = [
      HomeTab(
        store: widget.store,
        onNotifications: () => showInfo(c, 'Notifications'),
      ),
      WaitingTab(store: widget.store),
      const SizedBox(),
      SearchTab(store: widget.store),
      ProfileTab(store: widget.store),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: _LifeInboxBottomNav(
        selectedIndex: tab,
        onSelected: (i) {
          if (i == 2) {
            showCaptureSheet(c, widget.store);
            return;
          }
          setState(() => tab = i);
        },
      ),
    );
  }
}

class _LifeInboxBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LifeInboxBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF061526),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .07)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _navItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
              _navItem(Icons.hourglass_empty_rounded, Icons.hourglass_top_rounded, 'Waiting On', 1),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Add to Life Inbox',
                    child: InkWell(
                      onTap: () => onSelected(2),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 49,
                        height: 49,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD878), Color(0xFFE4AD3D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withValues(alpha: .22),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: navy, size: 29),
                      ),
                    ),
                  ),
                ),
              ),
              _navItem(Icons.search_rounded, Icons.search_rounded, 'Search', 3),
              _navItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData selectedIcon, String label, int index) {
    final selected = selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        child: SizedBox(
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected ? gold : const Color(0xFF8192A9),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? const Color(0xFFF4D58D) : const Color(0xFF8192A9),
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final LoopStore store;
  final VoidCallback? onNotifications;

  const HomeTab({super.key, required this.store, this.onNotifications});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String profileName = 'there';
  String? photoBase64;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedName = (prefs.getString('li_profile_name') ?? '').trim();
    setState(() {
      profileName = savedName.isEmpty ? 'there' : savedName.split(' ').first;
      photoBase64 = prefs.getString('li_profile_photo_base64');
    });
  }

  Widget _profileAvatar() {
    final encoded = photoBase64;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gold.withValues(alpha: .78), width: 1.2),
      ),
      child: CircleAvatar(
        radius: 21,
        backgroundColor: const Color(0xFF173A65),
        backgroundImage: encoded == null || encoded.isEmpty
            ? null
            : MemoryImage(base64Decode(encoded)),
        child: encoded == null || encoded.isEmpty
            ? const Icon(Icons.person_rounded, color: Color(0xFFB9D7FF), size: 23)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final active = widget.store.loops
        .where((l) => l.status != LoopStatus.resolved && l.status != LoopStatus.cancelled)
        .toList();
    final waiting = widget.store.loops
        .where((l) => [LoopStatus.waiting, LoopStatus.dueSoon, LoopStatus.followUp].contains(l.status))
        .length;
    final overdue = widget.store.loops.where((l) => l.status == LoopStatus.overdue).length;
    final recent = [...active]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      onRefresh: widget.store.load,
      color: gold,
      backgroundColor: card,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              _profileAvatar(),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, $profileName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: soft, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Your Command Center',
                      style: TextStyle(fontSize: 22, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: IconButton(
                  tooltip: 'Notifications',
                  padding: EdgeInsets.zero,
                  onPressed: widget.onNotifications ?? () => showInfo(c, 'Notifications'),
                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFBFD8FF), size: 23),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1455A1), Color(0xFF0B2C55), Color(0xFF0B1B32)],
              ),
              border: Border.all(color: const Color(0x554A9AFF)),
              boxShadow: const [BoxShadow(color: Color(0x221C72D8), blurRadius: 22, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.inbox_rounded, color: Color(0xFFC8E2FF), size: 18),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text('YOUR LIFE INBOX', style: TextStyle(color: Color(0xFFB8D8FF), fontSize: 10, letterSpacing: 1.45, fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.auto_awesome_rounded, color: gold, size: 17),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'You have ${active.length} Open Loops',
                  style: const TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -.35),
                ),
                const SizedBox(height: 5),
                const Text('Keep every pending outcome in sight.', style: TextStyle(color: Color(0xFFB8D0EC), fontSize: 11.5)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _dashboardMetric('${active.length}', 'Open', const Color(0xFF78BAFF))),
                    const SizedBox(width: 8),
                    Expanded(child: _dashboardMetric('$waiting', 'Waiting', gold)),
                    const SizedBox(width: 8),
                    Expanded(child: _dashboardMetric('$overdue', 'Overdue', const Color(0xFFFF8585))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 21),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quick Add', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: () => showCaptureSheet(c, widget.store),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add anything'),
                style: TextButton.styleFrom(foregroundColor: gold, visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _quickAdd(c, Icons.photo_outlined, 'Photo', const Color(0xFF3595FF), widget.store)),
              const SizedBox(width: 9),
              Expanded(child: _quickAdd(c, Icons.mic_none_rounded, 'Voice', const Color(0xFF8C76FF), widget.store)),
              const SizedBox(width: 9),
              Expanded(child: _quickAdd(c, Icons.edit_note_rounded, 'Note', const Color(0xFF20C9AF), widget.store)),
              const SizedBox(width: 9),
              Expanded(child: _quickAdd(c, Icons.description_outlined, 'Document', const Color(0xFFFFA954), widget.store)),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Open Loops', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('${active.length} active', style: const TextStyle(fontSize: 10.5, color: soft)),
            ],
          ),
          const SizedBox(height: 11),
          if (recent.isEmpty)
            const EmptyState()
          else
            ...recent.take(5).map(
              (l) => DashboardLoopTile(
                loop: l,
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => LoopDetailScreen(store: widget.store, loop: l)),
                ),
              ),
            ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'A reminder is not a resolution.',
              style: TextStyle(color: Color(0xFF71849B), fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardMetric(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0x44202F4D),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
      ],
    ),
  );
}

class DashboardLoopTile extends StatelessWidget {
  final OpenLoop loop;
  final VoidCallback onTap;
  const DashboardLoopTile({super.key, required this.loop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(loop.status);
    final subline = loop.amount != null
        ? '${loop.responsible}  ·  ${money(loop.amount!)}'
        : loop.responsible;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F34),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .065)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon(loop.type), color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loop.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: soft, fontSize: 10.5)),
                    if (loop.expectedDate != null) ...[
                      const SizedBox(height: 4),
                      Text('Due ${fmt(loop.expectedDate!)}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: StatusPill(loop.status)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF70839B)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _quickAdd(
  BuildContext context,
  IconData icon,
  String label,
  Color color,
  LoopStore store,
) => InkWell(
  onTap: () => showCaptureSheet(context, store),
  borderRadius: BorderRadius.circular(17),
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Column(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 7),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    ),
  ),
);

class SummaryCard extends StatelessWidget {
  final LoopStore store;
  const SummaryCard({super.key, required this.store});
  @override
  Widget build(BuildContext c) {
    final overdue = store.loops
        .where((l) => l.status == LoopStatus.overdue)
        .length;
    final waiting = store.loops
        .where((l) => l.status == LoopStatus.waiting)
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF102F54), Color(0xFF0B1D35)],
        ),
      ),
      child: Row(
        children: [
          _stat('$overdue', 'Overdue', danger),
          _stat('$waiting', 'Waiting', blue),
          _stat(
            '${store.loops.where((l) => l.status == LoopStatus.resolved).length}',
            'Closed',
            gold,
          ),
        ],
      ),
    );
  }

  Widget _stat(String a, String b, Color col) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: col,
          ),
        ),
        const SizedBox(height: 4),
        Text(b, style: const TextStyle(color: soft, fontSize: 12)),
      ],
    ),
  );
}

class LoopCard extends StatelessWidget {
  final OpenLoop loop;
  final VoidCallback onTap;
  const LoopCard({super.key, required this.loop, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final col = statusColor(loop.status);
    return Card(
      color: card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: col.withValues(alpha: .14),
                    child: Icon(typeIcon(loop.type), color: col, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loop.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StatusPill(loop.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                loop.description,
                style: const TextStyle(color: soft, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (loop.expectedDate != null)
                    Text(
                      'Due ${fmt(loop.expectedDate!)}',
                      style: TextStyle(
                        color: col,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    loop.responsible,
                    style: const TextStyle(color: soft, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final LoopStatus status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: statusColor(status).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      statusLabel(status),
      style: TextStyle(
        color: statusColor(status),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class WaitingTab extends StatelessWidget {
  final LoopStore store;
  const WaitingTab({super.key, required this.store});
  @override
  Widget build(BuildContext c) {
    final waiting = store.loops
        .where(
          (l) => [
            LoopStatus.waiting,
            LoopStatus.dueSoon,
            LoopStatus.overdue,
            LoopStatus.followUp,
          ].contains(l.status),
        )
        .toList();
    final amount = waiting.fold<double>(0, (s, l) => s + (l.amount ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        const Text(
          'Waiting On',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          "You're waiting on ${money(amount)} + ${waiting.length} outcomes.",
          style: const TextStyle(color: soft),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: card,
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Money, people, companies and unresolved outcomes stay visible here.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...waiting.map(
          (l) => LoopCard(
            loop: l,
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => LoopDetailScreen(store: store, loop: l),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SearchTab extends StatefulWidget {
  final LoopStore store;
  const SearchTab({super.key, required this.store});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String q = '';
  @override
  Widget build(BuildContext c) {
    final results = widget.store.loops
        .where(
          (l) =>
              ('${l.title} ${l.description} ${l.responsible} ${l.reference ?? ''}')
                  .toLowerCase()
                  .contains(q.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        const Text(
          'Search',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search loops, people, companies...',
          ),
        ),
        const SizedBox(height: 18),
        ...results.map(
          (l) => LoopCard(
            loop: l,
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => LoopDetailScreen(store: widget.store, loop: l),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileTab extends StatefulWidget {
  final LoopStore store;
  const ProfileTab({super.key, required this.store});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String name = 'Life Inbox user';
  String email = 'Add your email';
  String? photoBase64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('li_profile_name') ?? 'Life Inbox user';
      email = prefs.getString('li_profile_email') ?? 'Add your email';
      photoBase64 = prefs.getString('li_profile_photo_base64');
    });
  }

  Widget _avatar(double radius) {
    final bytes = photoBase64;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF173A65),
      backgroundImage: bytes == null || bytes.isEmpty
          ? null
          : MemoryImage(base64Decode(bytes)),
      child: bytes == null || bytes.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: const Color(0xFF9EC8FF),
              size: radius * 1.05,
            )
          : null,
    );
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          name: name,
          email: email,
          photoBase64: photoBase64,
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
    children: [
      const Text(
        'Profile',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      const Text(
        'Your space. Your preferences.',
        style: TextStyle(color: soft, fontSize: 13),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123C72), Color(0xFF0D223B)],
          ),
          border: Border.all(color: blue.withValues(alpha: .25)),
        ),
        child: Column(
          children: [
            _avatar(42),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: soft, fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: blue.withValues(alpha: .7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: gold),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your life, kept in confidence',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage the information stored on this device.',
                    style: TextStyle(color: soft, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      ...[
        'Manage Account',
        'Notifications',
        'Categories',
        'Data & Privacy',
        'Help & Support',
        'About Life Inbox',
      ].map(
        (x) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: card.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: Icon(
              _iconFor(
                x
                    .replaceAll('Manage Account', 'Account')
                    .replaceAll('Data & Privacy', 'Privacy & Security')
                    .replaceAll('Help & Support', 'Help')
                    .replaceAll('About Life Inbox', 'About'),
              ),
              color: const Color(0xFF89BFFF),
            ),
            title: Text(
              x,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: soft),
            onTap: () => showInfo(c, x),
          ),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('li_logged_in', false);
          if (!c.mounted) return;
          Navigator.pushAndRemoveUntil(
            c,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (_) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: danger,
          side: BorderSide(color: danger.withValues(alpha: .55)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text('Sign Out'),
      ),
    ],
  );
}

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String? photoBase64;
  const EditProfileScreen({
    super.key,
    required this.name,
    required this.email,
    this.photoBase64,
  });
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController nameController = TextEditingController(
    text: widget.name == 'Life Inbox user' ? '' : widget.name,
  );
  late final TextEditingController emailController = TextEditingController(
    text: widget.email == 'Add your email' ? '' : widget.email,
  );
  late final TextEditingController bioController = TextEditingController();
  final picker = ImagePicker();
  String? photoBase64;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    photoBase64 = widget.photoBase64;
    _loadBio();
  }

  Future<void> _loadBio() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    bioController.text = p.getString('li_profile_bio') ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => photoBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty ||
        !emailController.text.trim().contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name and a valid email address.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('li_profile_name', nameController.text.trim());
    await prefs.setString('li_profile_email', emailController.text.trim());
    await prefs.setString('li_profile_bio', bioController.text.trim());
    if (photoBase64 == null) {
      await prefs.remove('li_profile_photo_base64');
    } else {
      await prefs.setString('li_profile_photo_base64', photoBase64!);
    }
    if (!mounted) return;
    setState(() => saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) {
    final bytes = photoBase64;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          children: [
            const Text(
              'Personalise your experience',
              style: TextStyle(color: soft, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFF173A65),
                      backgroundImage: bytes == null
                          ? null
                          : MemoryImage(base64Decode(bytes)),
                      child: bytes == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF9EC8FF),
                              size: 52,
                            )
                          : null,
                    ),
                  ),
                  Material(
                    color: blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickPhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Change Profile Photo'),
              ),
            ),
            const SizedBox(height: 22),
            field(
              'Full name',
              nameController,
              'Your name',
              Icons.person_outline,
            ),
            field(
              'Email address',
              emailController,
              'you@example.com',
              Icons.mail_outline,
              keyboard: TextInputType.emailAddress,
            ),
            const Text(
              'Bio',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bioController,
              maxLines: 3,
              maxLength: 120,
              decoration: const InputDecoration(
                hintText: 'Organise today for a better tomorrow.',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => showInfo(
                  c,
                  'Profile photo is stored locally on this device in the current prototype.',
                ),
                child: const Text('Photo & data information'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String x) => switch (x) {
  'Notifications' => Icons.notifications_none,
  'Categories' => Icons.category_outlined,
  'Privacy & Security' => Icons.shield_outlined,
  'Manage Data' => Icons.storage_outlined,
  'Help' => Icons.help_outline,
  'About' => Icons.info_outline,
  _ => Icons.settings_outlined,
};

class LoopDetailScreen extends StatefulWidget {
  final LoopStore store;
  final OpenLoop loop;
  const LoopDetailScreen({super.key, required this.store, required this.loop});
  @override
  State<LoopDetailScreen> createState() => _LoopDetailScreenState();
}

class _LoopDetailScreenState extends State<LoopDetailScreen> {
  late OpenLoop l;
  @override
  void initState() {
    super.initState();
    l = widget.loop;
  }

  Future<void> _editLoop() async {
    final updated = await Navigator.push<OpenLoop>(
      context,
      MaterialPageRoute(builder: (_) => EditOpenLoopScreen(loop: l)),
    );
    if (updated == null) return;
    await widget.store.update(updated);
    if (!mounted) return;
    setState(() => l = updated);
  }

  Future<void> resolve(String action) async {
    if (action == 'Yes') {
      l = l.copyWith(
        status: LoopStatus.resolved,
        resolvedAt: DateTime.now(),
        events: [
          ...l.events,
          TimelineEvent(DateTime.now(), 'Outcome verified as resolved'),
        ],
      );
    } else if (action == 'Not yet') {
      l = l.copyWith(
        status: LoopStatus.followUp,
        events: [
          ...l.events,
          TimelineEvent(
            DateTime.now(),
            'User confirmed outcome has not happened yet',
          ),
        ],
      );
    } else {
      l = l.copyWith(
        status: LoopStatus.waiting,
        events: [
          ...l.events,
          TimelineEvent(DateTime.now(), 'Follow-up postponed'),
        ],
      );
    }
    await widget.store.update(l);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Loop'),
        actions: [
          IconButton(
            onPressed: _editLoop,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () async {
              await widget.store.remove(l.id);
              if (mounted) Navigator.pop(c);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor(l.status).withValues(alpha: .12),
                child: Icon(typeIcon(l.type), color: statusColor(l.status)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(l.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.description,
            style: const TextStyle(color: soft, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          InfoGrid(loop: l),
          const SizedBox(height: 20),
          if (l.status != LoopStatus.resolved)
            ResolveCard(
              onYes: () => resolve('Yes'),
              onNo: () => resolve('Not yet'),
              onLater: () => resolve('Later'),
            ),
          const SizedBox(height: 20),
          const Text(
            'Timeline',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...l.events.reversed.map((e) => TimelineTile(event: e)),
        ],
      ),
    );
  }
}

class InfoGrid extends StatelessWidget {
  final OpenLoop loop;
  const InfoGrid({super.key, required this.loop});
  @override
  Widget build(BuildContext c) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _box(c, 'Waiting on', loop.responsible),
      if (loop.expectedDate != null)
        _box(c, 'Expected', fmt(loop.expectedDate!)),
      _box(c, 'Outcome', loop.expectedOutcome),
      if (loop.amount != null) _box(c, 'Amount', money(loop.amount!)),
      if (loop.reference != null) _box(c, 'Reference', loop.reference!),
    ],
  );
  Widget _box(BuildContext c, String a, String b) => Container(
    width: MediaQuery.sizeOf(c).width / 2 - 26,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a, style: const TextStyle(color: soft, fontSize: 11)),
        const SizedBox(height: 6),
        Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class ResolveCard extends StatelessWidget {
  final VoidCallback onYes, onNo, onLater;
  const ResolveCard({
    super.key,
    required this.onYes,
    required this.onNo,
    required this.onLater,
  });
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF102A46),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: blue.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Did it happen?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'A reminder is not a resolution. Confirm the real-world outcome.',
          style: TextStyle(color: soft),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onYes,
                child: const Text('Yes, resolved'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onNo,
                child: const Text('Not yet'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onLater,
              icon: const Icon(Icons.snooze_outlined),
            ),
          ],
        ),
      ],
    ),
  );
}

class TimelineTile extends StatelessWidget {
  final TimelineEvent event;
  const TimelineTile({super.key, required this.event});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(color: blue, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.text),
              const SizedBox(height: 3),
              Text(
                fmt(event.time),
                style: const TextStyle(color: soft, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class EditOpenLoopScreen extends StatefulWidget {
  final OpenLoop loop;
  const EditOpenLoopScreen({super.key, required this.loop});

  @override
  State<EditOpenLoopScreen> createState() => _EditOpenLoopScreenState();
}

class _EditOpenLoopScreenState extends State<EditOpenLoopScreen> {
  late final TextEditingController titleController = TextEditingController(text: widget.loop.title);
  late final TextEditingController descriptionController = TextEditingController(text: widget.loop.description);
  late final TextEditingController responsibleController = TextEditingController(text: widget.loop.responsible);
  late final TextEditingController outcomeController = TextEditingController(text: widget.loop.expectedOutcome);
  DateTime? expectedDate;

  @override
  void initState() {
    super.initState();
    expectedDate = widget.loop.expectedDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    responsibleController.dispose();
    outcomeController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: expectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (chosen != null && mounted) setState(() => expectedDate = chosen);
  }

  void _save() {
    if (titleController.text.trim().isEmpty || responsibleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and who you are waiting on.')),
      );
      return;
    }
    final updated = OpenLoop(
      id: widget.loop.id,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      responsible: responsibleController.text.trim(),
      expectedOutcome: outcomeController.text.trim(),
      source: widget.loop.source,
      type: widget.loop.type,
      status: widget.loop.status,
      createdAt: widget.loop.createdAt,
      expectedDate: expectedDate,
      resolvedAt: widget.loop.resolvedAt,
      amount: widget.loop.amount,
      reference: widget.loop.reference,
      evidence: widget.loop.evidence,
      events: [
        ...widget.loop.events,
        TimelineEvent(DateTime.now(), 'Open Loop details updated'),
      ],
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Open Loop')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text('Update the details you want to track.', style: TextStyle(color: soft, fontSize: 13)),
          const SizedBox(height: 20),
          field('Title', titleController, 'What needs to be resolved?', Icons.edit_outlined),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Add useful context...'),
          ),
          const SizedBox(height: 16),
          field('Waiting on', responsibleController, 'Person or company', Icons.person_outline_rounded),
          field('Expected outcome', outcomeController, 'What does resolved look like?', Icons.flag_outlined),
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined, color: blue),
              title: const Text('Expected date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(expectedDate == null ? 'No date selected' : fmt(expectedDate!), style: const TextStyle(color: soft, fontSize: 12)),
              onTap: _chooseDate,
              trailing: expectedDate == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Remove date',
                      onPressed: () => setState(() => expectedDate = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showCaptureSheet(BuildContext context, LoopStore store) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A1B2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => CaptureSheet(store: store),
  );
}

class CaptureSheet extends StatefulWidget {
  final LoopStore store;
  const CaptureSheet({super.key, required this.store});
  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  final text = TextEditingController();
  final picker = ImagePicker();
  final speech = stt.SpeechToText();
  bool listening = false;
  String? source;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> photo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => source = x.name);
  }

  Future<void> document() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    if (r != null) setState(() => source = r.files.single.name);
  }

  Future<void> voice() async {
    if (!await speech.initialize()) return;
    setState(() => listening = true);
    speech.listen(
      onResult: (r) => setState(() => text.text = r.recognizedWords),
    );
  }

  Future<void> stopVoice() async {
    await speech.stop();
    setState(() => listening = false);
  }

  Future<void> create() async {
    if (text.text.trim().isEmpty && source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add text, voice, image or document first.'),
        ),
      );
      return;
    }
    final parsed = SmartParser.parse(text.text);
    final l = OpenLoop(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: parsed.title,
      description: text.text.isEmpty ? 'Captured evidence: $source' : text.text,
      responsible: parsed.person,
      expectedOutcome: parsed.outcome,
      source: source ?? 'Text',
      type: parsed.type,
      status: LoopStatus.active,
      createdAt: DateTime.now(),
      expectedDate: parsed.date,
      amount: parsed.amount,
      reference: parsed.reference,
      events: [
        TimelineEvent(DateTime.now(), 'Captured via ${source ?? 'text'}'),
      ],
    );
    await widget.store.add(l);
    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(store: widget.store, loop: l),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(c).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add to Life Inbox',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                captureButton(Icons.photo, 'Photo', photo),
                captureButton(Icons.description, 'Document', document),
                captureButton(
                  listening ? Icons.stop : Icons.mic,
                  listening ? 'Stop voice' : 'Voice',
                  listening ? stopVoice : voice,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type what you are waiting on...',
              ),
            ),
            if (source != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Attached: $source',
                  style: const TextStyle(color: soft),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text(
                  'Analyze & Continue',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget captureButton(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 105,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: blue),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}

class ReviewScreen extends StatelessWidget {
  final LoopStore store;
  final OpenLoop loop;
  const ReviewScreen({super.key, required this.store, required this.loop});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('AI Detection')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: gold),
                  SizedBox(width: 8),
                  Text(
                    'We found an Open Loop',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ReviewRow('Type', loop.type.name.toUpperCase()),
              ReviewRow('Title', loop.title),
              ReviewRow('Waiting on', loop.responsible),
              if (loop.amount != null) ReviewRow('Amount', money(loop.amount!)),
              if (loop.expectedDate != null)
                ReviewRow('Expected', fmt(loop.expectedDate!)),
              ReviewRow('Outcome', loop.expectedOutcome),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check the details before tracking. You stay in control.',
          style: TextStyle(color: soft),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.popUntil(c, (r) => r.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: navy,
            ),
            child: const Text(
              'Track this Open Loop',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class ReviewRow extends StatelessWidget {
  final String a, b;
  const ReviewRow(this.a, this.b, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(a, style: const TextStyle(color: soft, fontSize: 12)),
        ),
        Expanded(
          child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class ClosedTab extends StatelessWidget {
  final LoopStore store;
  const ClosedTab({super.key, required this.store});
  @override
  Widget build(BuildContext c) {
    final done = store.loops
        .where((l) => l.status == LoopStatus.resolved)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Closed Loops')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: done.isEmpty
            ? [const EmptyState()]
            : done
                  .map(
                    (l) => LoopCard(
                      loop: l,
                      onTap: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) =>
                              LoopDetailScreen(store: store, loop: l),
                        ),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});
  @override
  Widget build(BuildContext c) => const Padding(
    padding: EdgeInsets.all(40),
    child: Column(
      children: [
        Icon(Icons.check_circle_outline, color: gold, size: 48),
        SizedBox(height: 12),
        Text(
          'Nothing closed yet.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 5),
        Text(
          'Resolved outcomes will stay searchable here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: soft),
        ),
      ],
    ),
  );
}

class SmartParser {
  static Parsed parse(String s) {
    final low = s.toLowerCase();
    double? amount;
    final m = RegExp(
      r'(?:₹|rs\.?|inr\s*)([0-9][0-9,]*(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) amount = double.tryParse(m.group(1)!.replaceAll(',', ''));
    LoopType type =
        low.contains('refund') ||
            low.contains('owe') ||
            low.contains('repay') ||
            low.contains('money')
        ? LoopType.money
        : low.contains('return') ||
              low.contains('order') ||
              low.contains('delivery') ||
              low.contains('replacement')
        ? LoopType.order
        : low.contains('repair') ||
              low.contains('complaint') ||
              low.contains('technician')
        ? LoopType.issue
        : LoopType.promise;
    DateTime? date;
    final dm = RegExp(
      r'(today|tomorrow|day after tomorrow)',
      caseSensitive: false,
    ).firstMatch(low);
    if (dm != null) {
      date = DateTime.now();
      if (dm.group(1)!.toLowerCase() == 'tomorrow')
        date = date.add(const Duration(days: 1));
      if (dm.group(1)!.toLowerCase() == 'day after tomorrow')
        date = date.add(const Duration(days: 2));
    }
    String person = 'Not specified';
    final names = RegExp(
      r'(?:rahul|amazon|flipkart|service center|technician)',
      caseSensitive: false,
    ).firstMatch(s);
    if (names != null) person = names.group(0)!;
    final title = amount != null
        ? '${type.name[0].toUpperCase()}${type.name.substring(1)} ${money(amount!)}'
        : (s.trim().isEmpty ? 'New Open Loop' : s.trim().split('\n').first);
    String outcome = type == LoopType.money
        ? 'Money received'
        : type == LoopType.order
        ? 'Return/replacement completed'
        : type == LoopType.issue
        ? 'Issue fixed/resolved'
        : 'Promise fulfilled';
    return Parsed(title, person, outcome, type, date, amount, null);
  }
}

class Parsed {
  final String title, person, outcome;
  final LoopType type;
  final DateTime? date;
  final double? amount;
  final String? reference;
  Parsed(
    this.title,
    this.person,
    this.outcome,
    this.type,
    this.date,
    this.amount,
    this.reference,
  );
}

Color statusColor(LoopStatus s) => switch (s) {
  LoopStatus.overdue => danger,
  LoopStatus.dueSoon => gold,
  LoopStatus.waiting => blue,
  LoopStatus.followUp => Colors.orange,
  LoopStatus.resolved => Colors.green,
  LoopStatus.cancelled => Colors.grey,
  _ => Colors.lightBlueAccent,
};
String statusLabel(LoopStatus s) => switch (s) {
  LoopStatus.dueSoon => 'Due soon',
  LoopStatus.followUp => 'Follow-up',
  LoopStatus.resolved => 'Resolved',
  LoopStatus.overdue => 'Overdue',
  LoopStatus.waiting => 'Waiting',
  LoopStatus.cancelled => 'Cancelled',
  _ => 'Active',
};
IconData typeIcon(LoopType t) => switch (t) {
  LoopType.money => Icons.payments_outlined,
  LoopType.order => Icons.local_shipping_outlined,
  LoopType.promise => Icons.handshake_outlined,
  LoopType.issue => Icons.build_outlined,
};
String fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
String money(double n) =>
    '₹${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}';
void showInfo(BuildContext c, String title) => showDialog(
  context: c,
  builder: (_) => AlertDialog(
    title: Text(title),
    content: const Text(
      'This V1 foundation is ready for the next configuration step. Your data stays local until secure backend services are connected.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
    ],
  ),
);
