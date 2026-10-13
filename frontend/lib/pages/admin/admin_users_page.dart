import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import 'admin_user_form_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final Color primary = const Color(0xFF3B82F6);
  final Color primaryDark = const Color(0xFF1D4ED8);

  static const double maxWidth = 1200;

  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedType = 'All';

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
        _allUsers = result.data?['users'] ?? [];
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();

    _filteredUsers = _allUsers.where((u) {
      if (_selectedType != 'All' && u['userType'] != _selectedType) {
        return false;
      }

      if (q.isEmpty) return true;

      final email = (u['email'] ?? '').toString().toLowerCase();
      final nickname =
          (u['profile']?['nickname'] ?? '').toString().toLowerCase();

      return email.contains(q) || nickname.contains(q);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilters();
    });
  }

  void _onTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedType = value;
      _applyFilters();
    });
  }

  Future<void> _openAddForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminUserFormPage(),
      ),
    );

    if (created == true) _loadUsers();
  }

  Future<void> _openEditForm(Map<String, dynamic> user) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserFormPage(user: user),
      ),
    );

    if (updated == true) _loadUsers();
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete User?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete:\n${user['email']}?',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteUser(user['id']);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    if (result.success) _loadUsers();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Admin':
        return const Color(0xFF3B82F6);
      case 'Customer':
        return const Color(0xFF10B981);
      case 'Programmer':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E3A8A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final iconColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF1E293B);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return Scaffold(
      body: Stack(
        children: [
          // ===== Background Gradient =====
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF1E3A8A),
                      ]
                    : const [
                        Color(0xFFEEF2FF),
                        Color(0xFFE0E7FF),
                        Color(0xFFF5F3FF),
                      ],
              ),
            ),
          ),

          // ===== Glow Circles =====
          Positioned(
            top: -100,
            right: -100,
            child: _glow(
              280,
              primary.withOpacity(isDark ? 0.15 : 0.25),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _glow(
              300,
              primaryDark.withOpacity(isDark ? 0.10 : 0.20),
            ),
          ),

          // ===== Content =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;
                final isMobile = constraints.maxWidth <= 700;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      children: [
                        _buildAppBar(
                          isDark,
                          cardColor,
                          textPrimary,
                          textSecondary,
                          borderColor,
                          iconColor,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                        _buildSearchAndFilter(
                          isDark,
                          cardColor,
                          textPrimary,
                          textSecondary,
                          borderColor,
                          inputFill,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildBody(
                            isDark,
                            cardColor,
                            textPrimary,
                            textSecondary,
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                            isMobile: isMobile,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddForm,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add User',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  Widget _buildAppBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color iconColor, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    final hPad = isDesktop ? 40.0 : 20.0;
    final vTop = isDesktop ? 24.0 : 16.0;
    final vBottom = isDesktop ? 16.0 : 12.0;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, vBottom),
      child: Row(
        children: [
          Material(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            elevation: isDark ? 0 : 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: isDesktop ? 26 : 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage customers & programmers',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ThemeToggle(
            themeManager: themeManager,
            compact: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH + FILTER
  // ============================================================
  Widget _buildSearchAndFilter(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color inputFill, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final hPad = isDesktop ? 40.0 : 20.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: hPad),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search by email or nickname...',
              hintStyle: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: primary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: primary,
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _typeChip('All', 'All Users', isDark),
                const SizedBox(width: 8),
                _typeChip('Customer', 'Customers', isDark),
                const SizedBox(width: 8),
                _typeChip('Programmer', 'Programmers', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label, bool isDark) {
    final selected = _selectedType == value;
    final color = value == 'All' ? primary : _typeColor(value);

    return GestureDetector(
      onTap: () => _onTypeChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color
              : color.withOpacity(isDark ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================
  Widget _buildBody(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_filteredUsers.isEmpty) {
      return _buildEmpty(textPrimary, textSecondary);
    }

    final hPad = isDesktop ? 40.0 : 20.0;
    final bottomPad = isDesktop ? 60.0 : 100.0;

    return RefreshIndicator(
      color: primary,
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, bottomPad),
        itemCount: _filteredUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTableHeader(
              isDark,
              textPrimary,
              isDesktop: isDesktop,
              isMobile: isMobile,
            );
          }

          final user = _filteredUsers[index - 1];
          final isLast = index == _filteredUsers.length;

          return _buildUserRow(
            user,
            isLast,
            isDark,
            cardColor,
            textPrimary,
            textSecondary,
            isDesktop: isDesktop,
            isMobile: isMobile,
          );
        },
      ),
    );
  }

  // ============================================================
  // TABLE HEADER — عرض 80/90 بدل 70/80
  // ============================================================
  Widget _buildTableHeader(
    bool isDark,
    Color textPrimary, {
    required bool isDesktop,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: primary.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 32 : 40,
            child: Text(
              'ID',
              style: TextStyle(
                fontSize: isDesktop ? 12 : 11.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'EMAIL',
              style: TextStyle(
                fontSize: isDesktop ? 12 : 11.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'TYPE',
              style: TextStyle(
                fontSize: isDesktop ? 12 : 11.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // ✅ 80 بدل 70
          SizedBox(
            width: isMobile ? 80 : 90,
            child: Text(
              'ACTIONS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 12 : 11.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER ROW — عرض 80/90 بدل 70/80
  // ============================================================
  Widget _buildUserRow(
    Map<String, dynamic> user,
    bool isLast,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
    required bool isMobile,
  }) {
    final id = user['id'] ?? 0;
    final email = user['email'] ?? '';
    final userType = user['userType'] ?? '';
    final color = _typeColor(userType);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.10 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 32 : 40,
            child: Text(
              '$id',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    userType == 'Programmer'
                        ? Icons.code_rounded
                        : Icons.person_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  userType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
          // ✅ 80 بدل 70
          SizedBox(
            width: isMobile ? 80 : 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _openEditForm(user),
                ),
                const SizedBox(width: 6),
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => _confirmDelete(user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmpty(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Users Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ),
      ),
    );
  }
}