import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RafiqApp());
}

class RafiqApp extends StatelessWidget {
  const RafiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رفيق',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F8C)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        fontFamily: null,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

class RafiqItem {
  RafiqItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isTask,
    this.done = false,
    required this.createdAt,
  });

  final String id;
  String title;
  String body;
  bool isTask;
  bool done;
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body, 'isTask': isTask,
    'done': done, 'createdAt': createdAt,
  };

  factory RafiqItem.fromJson(Map<String, dynamic> json) => RafiqItem(
    id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    isTask: json['isTask'] as bool? ?? false,
    done: json['done'] as bool? ?? false,
    createdAt: json['createdAt'] as int? ?? 0,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storageKey = 'rafiq_items_v1';
  final List<RafiqItem> _items = [];
  bool _loading = true;
  String _filter = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(decoded.map((e) =>
              RafiqItem.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      // Keep the app usable if saved data is damaged.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  List<RafiqItem> get _visibleItems {
    final result = _items.where((item) {
      if (_filter == 'المهام') return item.isTask;
      if (_filter == 'الملاحظات') return !item.isTask;
      if (_filter == 'غير المنجزة') return item.isTask && !item.done;
      return true;
    }).toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  int get _unfinished => _items.where((i) => i.isTask && !i.done).length;

  Future<void> _showEditor({bool isTask = false}) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isTask ? 'مهمة جديدة' : 'ملاحظة جديدة',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'اكتب عنوانًا أولًا' : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(sheetContext, true);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ على الهاتف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _items.add(RafiqItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: titleController.text.trim(),
          body: bodyController.text.trim(),
          isTask: isTask,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      });
      await _saveItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ على هذا الهاتف')),
        );
      }
    }
    titleController.dispose();
    bodyController.dispose();
  }

  Future<void> _toggle(RafiqItem item, bool? value) async {
    setState(() => item.done = value ?? false);
    await _saveItems();
  }

  Future<void> _delete(RafiqItem item) async {
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFD8F0EF),
              child: Icon(Icons.bolt, color: Color(0xFF087F8C)),
            ),
            SizedBox(width: 10),
            Text('رفيق', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'معلومات التطبيق',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'رفيق',
              applicationVersion: '0.1.0',
              children: const [
                Text('مساعد يومي بسيط. تُحفظ ملاحظاتك ومهامك محليًا على الهاتف.'),
                SizedBox(height: 8),
                Text('هذه نسخة أولية؛ احفظ نسخة احتياطية من المعلومات المهمة.'),
              ],
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087F8C), Color(0xFF155E75)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مساحتك اليومية، في مكان واحد',
                        style: TextStyle(color: Colors.white, fontSize: 19,
                          fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('لديك $_unfinished مهام غير منجزة',
                        style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _QuickButton(
                            icon: Icons.check_circle_outline,
                            label: 'مهمة جديدة',
                            onTap: () => _showEditor(isTask: true),
                          ),
                          const SizedBox(width: 10),
                          _QuickButton(
                            icon: Icons.note_add_outlined,
                            label: 'ملاحظة',
                            onTap: () => _showEditor(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('مساحتك', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['الكل', 'المهام', 'غير المنجزة', 'الملاحظات']
                      .map((filter) => ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          )).toList(),
                ),
                const SizedBox(height: 12),
                if (_visibleItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 44, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('لا توجد عناصر هنا بعد',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('أضف أول مهمة أو ملاحظة وابدأ.',
                          style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  )
                else
                  ..._visibleItems.map((item) => Card(
                    color: Colors.white,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: item.isTask
                          ? Checkbox(
                              value: item.done,
                              onChanged: (v) => _toggle(item, v),
                            )
                          : const CircleAvatar(
                              backgroundColor: Color(0xFFE1F3F1),
                              child: Icon(Icons.notes, color: Color(0xFF087F8C)),
                            ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: item.done ? TextDecoration.lineThrough : null,
                          color: item.done ? Colors.black45 : null,
                        ),
                      ),
                      subtitle: item.body.isEmpty
                          ? Text(item.isTask ? 'مهمة' : 'ملاحظة')
                          : Text(item.body, maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ),
                  )),
                const SizedBox(height: 12),
                const Text(
                  'تعمل النسخة الأولية دون حساب أو خادم. بياناتك محفوظة داخل التطبيق على هذا الجهاز.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(RafiqItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العنصر؟'),
        content: Text('سيتم حذف «${item.title}» من التطبيق على هذا الهاتف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _delete(item);
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon, required this.label, required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      label: Text(label),
    ),
  );
}