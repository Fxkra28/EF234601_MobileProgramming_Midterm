import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/category_controller.dart';
import '../models/category_model.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CategoryController>();
    final categories = controller.categories;
    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.errorMessage!)),
        );
        controller.clearError();
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Labels',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A90E2),
              fontSize: 22),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final c = categories[index];
          return _CategoryRow(category: c);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        onPressed: () => _editDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('cat-${category.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          final cats = context.read<CategoryController>();
          final ok = await cats.deleteCategory(category);
          if (!ok && context.mounted && cats.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(cats.errorMessage!)),
            );
            cats.clearError();
          }
          return ok;
        },
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _editDialog(context, category),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(category.colorHex),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<int> _kPalette = [
  0xFF4A90E2,
  0xFF50C878,
  0xFFFF8C42,
  0xFFE94B6A,
  0xFF8E63E5,
  0xFF38C5BD,
  0xFFFFC857,
  0xFF607D8B,
];

Future<void> _editDialog(BuildContext context, Category? existing) async {
  final controller = context.read<CategoryController>();
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  int colorHex = existing?.colorHex ?? _kPalette.first;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New Label' : 'Edit Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kPalette.map((hex) {
                  final selected = hex == colorHex;
                  return GestureDetector(
                    onTap: () => setLocal(() => colorHex = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Colors.black87
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (existing == null) {
                  await controller.addCategory(name, colorHex);
                } else {
                  await controller.updateCategory(existing,
                      name: name, colorHex: colorHex);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      );
    },
  );
}
