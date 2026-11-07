import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/db.dart';
import '../data/models.dart';

/// إضافة / تعديل موعد عام (اجتماع، سداد رسوم، استلام صورة حكم...).
class AppointmentFormScreen extends StatefulWidget {
  final int? appointmentId;
  final DateTime? initialDate;
  final int? caseId;
  const AppointmentFormScreen({super.key, this.appointmentId, this.initialDate, this.caseId});
  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = dayStart(DateTime.now());
  int? _minutes;
  int? _caseId;
  Appointment? _orig;
  List<LegalCase> _cases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _cases = await Db.i.cases();
    if (widget.initialDate != null) _date = dayStart(widget.initialDate!);
    _caseId = widget.caseId;
    if (widget.appointmentId != null) {
      final a = await Db.i.appointment(widget.appointmentId!);
      if (a != null) {
        _orig = a;
        _title.text = a.title;
        _notes.text = a.notes;
        _date = a.date;
        _minutes = a.minutes;
        _caseId = a.caseId;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'اكتب عنوان الموعد');
      return;
    }
    final a = _orig ?? Appointment(date: _date);
    a
      ..title = _title.text.trim()
      ..notes = _notes.text.trim()
      ..date = _date
      ..minutes = _minutes
      ..caseId = _caseId;
    await Db.i.saveAppointment(a);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant), borderRadius: BorderRadius.circular(12));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointmentId == null ? 'موعد جديد' : 'تعديل الموعد'),
        actions: [
          if (_orig != null)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'حذف هذا الموعد؟', ok: 'حذف')) {
                  await Db.i.deleteAppointment(_orig!.id!);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          IconButton(tooltip: 'حفظ', icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              tf(_title, 'عنوان الموعد', icon: Icons.event_note, required: true),
              ListTile(
                shape: shape,
                leading: const Icon(Icons.event),
                title: const Text('التاريخ'),
                subtitle: Text(fmtDate(_date)),
                onTap: () async {
                  final d = await pickDate(context, _date);
                  if (d != null) setState(() => _date = dayStart(d));
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: shape,
                leading: const Icon(Icons.access_time),
                title: Text(_minutes == null ? 'الوقت (اختياري)' : 'الوقت: ${fmtTime(_minutes!)}'),
                trailing: _minutes == null
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _minutes = null)),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: (_minutes ?? 540) ~/ 60, minute: (_minutes ?? 540) % 60),
                  );
                  if (t != null) setState(() => _minutes = t.hour * 60 + t.minute);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _cases.any((c) => c.id == _caseId) ? _caseId : null,
                isExpanded: true,
                decoration: dec('مرتبط بقضية (اختياري)', icon: Icons.gavel),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— بدون —')),
                  for (final c in _cases)
                    DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text('${caseLabel(c.number, c.year)}${c.clientName.isEmpty ? '' : ' - ${c.clientName}'}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _caseId = v),
              ),
              const SizedBox(height: 12),
              tf(_notes, 'ملاحظات', maxLines: 4),
              FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
            ]),
    );
  }
}
