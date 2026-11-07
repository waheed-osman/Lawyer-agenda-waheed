import 'package:flutter/material.dart';

import '../core/widgets.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموكلون')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'موكل جديد',
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen())),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف أو الرقم القومي', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: Live<List<Client>>(
            load: () => Db.i.clients(q: _q),
            builder: (c, list) => list.isEmpty
                ? const EmptyState(icon: Icons.people_outline, text: 'لا يوجد موكلون')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final cl = list[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(cl.name.isEmpty ? '?' : cl.name.characters.first)),
                          title: Text(cl.name),
                          subtitle: Text([cl.phone, '${cl.casesCount} قضية'].where((e) => e.isNotEmpty).join(' • ')),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.push(
                              c, MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: cl.id!))),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
