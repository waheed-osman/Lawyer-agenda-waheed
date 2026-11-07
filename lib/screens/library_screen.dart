import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils.dart';
import '../core/widgets.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../services/security.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _q = '';
  String? _cat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المكتبة القانونية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplateFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('نموذج'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'ابحث في العناوين والنصوص...', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                    label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
              ),
              for (final c in templateCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                      label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Live<List<LegalTemplate>>(
            load: () => Db.i.templates(q: _q, category: _cat),
            builder: (c, list) => list.isEmpty
                ? const EmptyState(icon: Icons.menu_book_outlined, text: 'لا توجد نماذج')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: list.length,
                    itemBuilder: (_, i) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(list[i].title),
                        subtitle: Text(list[i].category),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                            c, MaterialPageRoute(builder: (_) => TemplateViewScreen(id: list[i].id!))),
                      ),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class TemplateViewScreen extends StatelessWidget {
  final int id;
  const TemplateViewScreen({super.key, required this.id});

  Future<LegalTemplate?> _load() async {
    final all = await Db.i.templates();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Live<LegalTemplate?>(
      load: _load,
      builder: (c, t) {
        if (t == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.description, text: 'غير موجود'));
        return Scaffold(
          appBar: AppBar(
            title: Text(t.title, style: const TextStyle(fontSize: 17)),
            actions: [
              IconButton(
                tooltip: 'نسخ',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: t.body));
                  toast(c, 'تم نسخ النموذج');
                },
              ),
              IconButton(
                tooltip: 'مشاركة',
                icon: const Icon(Icons.share),
                onPressed: () => Security.guard(() => Share.share(t.body, subject: t.title)),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                    c, MaterialPageRoute(builder: (_) => TemplateFormScreen(template: t))),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(c, 'حذف هذا النموذج؟', ok: 'حذف')) {
                    await Db.i.deleteTemplate(t.id!);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(t.body, style: const TextStyle(fontSize: 16, height: 1.8)),
            ),
          ),
        );
      },
    );
  }
}

class TemplateFormScreen extends StatefulWidget {
  final LegalTemplate? template;
  const TemplateFormScreen({super.key, this.template});
  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.template?.title ?? '');
  late final _body = TextEditingController(text: widget.template?.body ?? '');
  late String _cat = templateCategories.contains(widget.template?.category)
      ? widget.template!.category
      : templateCategories.last;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final t = widget.template ?? LegalTemplate();
    t
      ..title = _title.text.trim()
      ..category = _cat
      ..body = _body.text;
    await Db.i.saveTemplate(t);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'نموذج جديد' : 'تعديل النموذج'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check), tooltip: 'حفظ')],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          tf(_title, 'عنوان النموذج', required: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _cat,
              decoration: dec('التصنيف'),
              items: [for (final c in templateCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _cat = v!),
            ),
          ),
          TextFormField(
            controller: _body,
            minLines: 14,
            maxLines: null,
            decoration: dec('نص النموذج'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        ]),
      ),
    );
  }
}
