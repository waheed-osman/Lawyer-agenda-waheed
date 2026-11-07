import 'package:flutter/material.dart';

import '../services/security.dart';

/// Wraps the whole app. Shows a lock overlay above everything (including
/// pushed routes) when a password is set and the app is opened/resumed.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = false;
  DateTime? _pausedAt;
  static const _grace = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Security.lockSignal.addListener(_lockNow);
    _init();
  }

  Future<void> _init() async {
    final has = await Security.hasPassword();
    if (!mounted) return;
    setState(() {
      _locked = has;
      _ready = true;
    });
  }

  Future<void> _lockNow() async {
    if (await Security.hasPassword() && mounted) setState(() => _locked = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (!Security.suspend && away >= _grace && await Security.hasPassword() && mounted) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Security.lockSignal.removeListener(_lockNow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (!_ready)
        Positioned.fill(child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor))
      else if (_locked)
        Positioned.fill(
          child: Overlay(initialEntries: [
            OverlayEntry(builder: (_) => LockScreen(onUnlocked: () => setState(() => _locked = false))),
          ]),
        ),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pw = TextEditingController();
  bool _bio = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final enabled = await Security.biometricEnabled();
    final avail = enabled && await Security.biometricAvailable();
    if (!mounted) return;
    setState(() => _bio = avail);
    if (avail) _tryBio();
  }

  Future<void> _tryBio() async {
    if (await Security.authenticate()) widget.onUnlocked();
  }

  Future<void> _submit() async {
    if (await Security.verify(_pw.text)) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'كلمة المرور غير صحيحة');
      _pw.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.balance, size: 72, color: cs.primary),
                const SizedBox(height: 12),
                Text('أجندة المحامي القانونية',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 28),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  autofocus: !_bio,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: 'كلمة المرور', errorText: _error),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('فتح'))),
                if (_bio) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _tryBio,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('استخدام بصمة الإصبع'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
