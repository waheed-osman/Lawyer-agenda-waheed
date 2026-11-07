import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/backup.dart';
import '../services/notifications.dart';
import '../services/security.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasPw = false;
  bool _bio = false;
  bool _bioAvail = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await Security.hasPassword();
    final b = await Security.biometricEnabled();
    final a = await Security.biometricAvailable();
    if (mounted) {
      setState(() {
        _hasPw = h;
        _bio = b;
        _bioAvail = a;
      });
    }
  }

  Future<String?> _askPassword(String title, {bool confirmField = false}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: a,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: 'كلمة المرور', errorText: err)),
            if (confirmField) ...[
              const SizedBox(height: 10),
              TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            ],
            if (confirmField)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('تنبيه: لا يمكن استرجاع كلمة المرور إذا نُسيت. احتفظ بنسخة احتياطية.',
                    style: TextStyle(fontSize: 12)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (a.text.length < 4) {
                  setS(() => err = '٤ أحرف على الأقل');
                } else if (confirmField && a.text != b.text) {
                  setS(() => err = 'كلمتا المرور غير متطابقتين');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPassword() async {
    if (_hasPw) {
      final cur = await _askPassword('أدخل كلمة المرور الحالية');
      if (cur == null) return;
      if (!await Security.verify(cur)) {
        if (mounted) toast(context, 'كلمة المرور الحالية غير صحيحة');
        return;
      }
    }
    final pw = await _askPassword(_hasPw ? 'كلمة المرور الجديدة' : 'تعيين كلمة مرور', confirmField: true);
    if (pw == null) return;
    await Security.setPassword(pw);
    await _load();
    if (mounted) toast(context, 'تم حفظ كلمة المرور');
  }

  Future<void> _removePassword() async {
    final cur = await _askPassword('أدخل كلمة المرور لإلغاء القفل');
    if (cur == null) return;
    if (!await Security.verify(cur)) {
      if (mounted) toast(context, 'كلمة المرور غير صحيحة');
      return;
    }
    await Security.removePassword();
    await _load();
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final f = await Backup.export();
      await Security.guard(() => Share.shareXFiles([XFile(f.path)], subject: 'نسخة احتياطية - أجندة المحامي'));
    } catch (e) {
      if (mounted) toast(context, 'تعذّر إنشاء النسخة: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    if (!await confirm(context, 'سيتم استبدال كل البيانات الحالية ببيانات ملف النسخة الاحتياطية. هل أنت متأكد؟',
        ok: 'استعادة')) {
      return;
    }
    final res = await Security.guard(
        () => FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']));
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await Backup.restore(File(path));
      if (mounted) toast(context, 'تمت استعادة البيانات بنجاح');
    } catch (e) {
      if (mounted) toast(context, 'فشلت الاستعادة: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppSettings.themeMode,
                  builder: (_, m, __) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('فاتح')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('داكن')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('النظام')),
                      ],
                      selected: {m},
                      onSelectionChanged: (s) => AppSettings.setTheme(s.first),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(_hasPw ? 'تغيير كلمة المرور' : 'تعيين كلمة مرور للتطبيق'),
                subtitle: Text(_hasPw ? 'القفل مفعّل' : 'التطبيق غير محمي حاليًا'),
                onTap: _setPassword,
              ),
              if (_hasPw)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('الفتح بالبصمة'),
                  subtitle: Text(_bioAvail ? 'استخدم بصمة الإصبع بدل كلمة المرور' : 'غير متاحة على هذا الجهاز'),
                  value: _bio && _bioAvail,
                  onChanged: _bioAvail
                      ? (v) async {
                          if (v && !await Security.authenticate()) return;
                          await Security.setBiometric(v);
                          await _load();
                        }
                      : null,
                ),
              if (_hasPw)
                ListTile(
                  leading: const Icon(Icons.lock_clock),
                  title: const Text('قفل التطبيق الآن'),
                  onTap: () => Security.lockSignal.value++,
                ),
              if (_hasPw)
                ListTile(
                  leading: const Icon(Icons.lock_open),
                  title: const Text('إلغاء القفل'),
                  onTap: _removePassword,
                ),
            ]),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('نسخ احتياطي'),
                subtitle: const Text('تصدير كل البيانات والصور في ملف JSON واحد للحفظ أو المشاركة'),
                onTap: _busy ? null : _backup,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('استعادة نسخة احتياطية'),
                subtitle: const Text('استيراد ملف JSON (يستبدل البيانات الحالية)'),
                onTap: _busy ? null : _restore,
              ),
            ]),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('اختبار التنبيهات'),
              subtitle: const Text('تنبيه قبل الجلسة بيوم (6 مساءً) وصباح يوم الجلسة (7:30)'),
              onTap: () async {
                await Notifier.testNow();
                await Notifier.rescheduleAll();
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'أجندة المحامي القانونية • الإصدار 1.0\nجميع البيانات محفوظة على جهازك فقط، ولا يتصل التطبيق بالإنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
        if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
      ]),
    );
  }
}
