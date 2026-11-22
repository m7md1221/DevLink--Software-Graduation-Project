import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All Users';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getAllUsers();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _allUsers = result.data?['users'] as List? ?? [];
        _applyFilter();
      } else {
        _allUsers = [];
        _filteredUsers = [];
      }
    });
  }

  void _applyFilter() {
    List<dynamic> filtered = _allUsers;

    if (_selectedFilter == 'Customers') {
      filtered = filtered.where((u) => u['userType'] == 'Customer').toList();
    } else if (_selectedFilter == 'Programmers') {
      filtered = filtered.where((u) => u['userType'] == 'Programmer').toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((u) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final nickname = (u['profile']?['nickname'] ?? '').toString().toLowerCase();
        return email.contains(query) || nickname.contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = filtered);
  }

  // ============================================
  // إضافة مستخدم (Create)
  // ============================================
  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedType = 'Customer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New User', style: TextStyle(fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'User Type'),
                  items: ['Customer', 'Programmer', 'Admin'].map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.createUser(
      email: emailController.text.trim(),
      password: passwordController.text,
      userType: selectedType,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) _loadUsers();
  }

  // ============================================
  // تعديل مستخدم (Update)
  // ============================================
  Future<void> _showUpdateUserDialog(dynamic user) async {
    final id = user['id'] as int;
    final emailController = TextEditingController(text: user['email']);
    final passwordController = TextEditingController();
    String selectedType = user['userType'] ?? 'Customer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Update User', style: TextStyle(fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password (Optional)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'User Type'),
                  items: ['Customer', 'Programmer', 'Admin'].map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.updateUser(
      id: id,
      email: emailController.text.trim(),
      password: passwordController.text.isEmpty ? null : passwordController.text,
      userType: selectedType,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) _loadUsers();
  }

  // ============================================
  // حذف مستخدم (Delete)
  // ============================================
  Future<void> _deleteUser(dynamic user) async {
    final id = user['id'] as int;
    final email = user['email'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteUser(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) _loadUsers();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Admin':
        return const Color(0xFF8B5CF6);
      case 'Customer':
        return const Color(0xFF10B981);
      case 'Programmer':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      case 'Customer':
        return Icons.person_rounded;
      case 'Programmer':
        return Icons.code_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
        ),
        title: Text(
          'User Management',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: Icon(Icons.refresh_rounded, color: textPrimary),
          ),
          IconButton(
            onPressed: _showAddUserDialog,
            icon: const Icon(Icons.add_rounded, color: Colors.blue),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilter(),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by email or nickname...',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ['All Users', 'Customers', 'Programmers'].map((f) {
                        final selected = _selectedFilter == f;
                        final color = f == 'All Users'
                            ? const Color(0xFF3B82F6)
                            : f == 'Customers'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF8B5CF6);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedFilter = f);
                              _applyFilter();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? color : color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : color,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 64, color: textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No Users Found',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try adjusting your search or filters',
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF3B82F6),
                            onRefresh: _loadUsers,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (_, i) {
                                final user = _filteredUsers[i];
                                final type = (user['userType'] ?? 'Unknown').toString();
                                final typeColor = _getTypeColor(type);
                                final profile = user['profile'];
                                final nickname = profile?['nickname'] ?? 'No nickname';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: typeColor.withOpacity(0.12),
                                          border: Border.all(color: typeColor, width: 2),
                                        ),
                                        child: Icon(_getTypeIcon(type), color: typeColor, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['email'] ?? '',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              nickname,
                                              style: TextStyle(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: typeColor),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                        onPressed: () => _showUpdateUserDialog(user),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                        onPressed: () => _deleteUser(user),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}