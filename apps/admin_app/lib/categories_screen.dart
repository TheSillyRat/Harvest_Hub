import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'admin_app.dart';

class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categoryService = CategoryService();

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Product Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HhColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CategoryForm(),
            ),
          );
        },
      ),
      body: StreamBuilder<List<Category>>(
        stream: categoryService.streamAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: HhColors.primary),
            );
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories found. Tap "+ Add Category" to create one.',
                style: TextStyle(color: HhColors.muted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cat = categories[index];

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: HhColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      '#${cat.sortOrder}',
                      style: const TextStyle(
                        color: HhColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryDisplayName(cat.id, cat.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (cat.isActive ? Colors.green : Colors.red)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cat.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cat.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Category ID: ${cat.id}',
                    style: const TextStyle(fontSize: 12, color: HhColors.muted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: HhColors.primary),
                        tooltip: 'Edit Category',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CategoryForm(category: cat),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          cat.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: cat.isActive ? HhColors.danger : Colors.green,
                        ),
                        tooltip: cat.isActive
                            ? 'Deactivate Category'
                            : 'Activate Category',
                        onPressed: () async {
                          await categoryService.save(
                            cat.copyWith(isActive: !cat.isActive),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
