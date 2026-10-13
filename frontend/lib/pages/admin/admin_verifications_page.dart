import 'package:devlink/main.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/theme_toggle.dart';
import 'admin_verification_details_page.dart';

class AdminVerificationsPage extends StatefulWidget {
  const AdminVerificationsPage({super.key});

  @override
  State<AdminVerificationsPage> createState() =>
      _AdminVerificationsPageState();
}

class _AdminVerificationsPageState
    extends State<AdminVerificationsPage> {
  final Color primary = const Color(0xFF3B82F6);
  final Color accentGreen = const Color(0xFF10B981);
  final Color accentAmber = const Color(0xFFF59E0B);

  // ✅ نفس maxWidth المستخدم في AdminDashboardPage
  static const double maxWidth = 1200;

  List<dynamic> _allProgrammers = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _filter = 'All';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProgrammers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgrammers() async {
    setState(() => _isLoading = true);

    final result = await ApiService.getProgrammersForVerification();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _allProgrammers = result.data?['programmers'] ?? [];
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();

    _filtered = _allProgrammers.where((p) {
      final isVerified = p['isVerified'] == true;

      if (_filter == 'Pending' && isVerified) return false;
      if (_filter == 'Verified' && !isVerified) return false;

      if (q.isEmpty) return true;

      final nickname = (p['nickname'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final specialty = (p['specialty'] ?? '').toString().toLowerCase();

      return nickname.contains(q) ||
          email.contains(q) ||
          specialty.contains(q);
    }).toList();
  }

  void _onSearchChanged(String v) {
    setState(() {
      _searchQuery = v;
      _applyFilters();
    });
  }

  void _onFilterChanged(String f) {
    setState(() {
      _filter = f;
      _applyFilters();
    });
  }

  Future<void> _openDetails(Map<String, dynamic> programmer) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVerificationDetailsPage(
          programmer: programmer,
        ),
      ),
    );

    if (changed == true) _loadProgrammers();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF064E3B);
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
                        Color(0xFF064E3B),
                      ]
                    : const [
                        Color(0xFFECFDF5),
                        Color(0xFFD1FAE5),
                        Color(0xFFEFF6FF),
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
              accentGreen.withOpacity(isDark ? 0.15 : 0.25),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _glow(
              300,
              primary.withOpacity(isDark ? 0.10 : 0.20),
            ),
          ),

          // ===== Content (Responsive + maxWidth) =====
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // ✅ نفس breakpoints الداشبورد
                final isDesktop = constraints.maxWidth > 1100;
                final isTablet = constraints.maxWidth > 700 &&
                    constraints.maxWidth <= 1100;

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
                        ),
                        _buildSearchAndFilter(
                          isDark,
                          cardColor,
                          textPrimary,
                          textSecondary,
                          inputFill,
                          isDesktop: isDesktop,
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
    );
  }

  // ============================================================
  // APP BAR (مع ThemeToggle) — responsive
  // ============================================================
  Widget _buildAppBar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color iconColor, {
    required bool isDesktop,
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
                  'User Verification',
                  style: TextStyle(
                    fontSize: isDesktop ? 26 : 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review CVs and verify programmers',
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
  // SEARCH + FILTER — responsive
  // ============================================================
  Widget _buildSearchAndFilter(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color inputFill, {
    required bool isDesktop,
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
                : accentGreen.withOpacity(0.10),
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
              hintText: 'Search by name, email, or specialty...',
              hintStyle: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF10B981),
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
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
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
                _filterChip('All', 'All', isDark),
                const SizedBox(width: 8),
                _filterChip('Pending', 'Pending', isDark),
                const SizedBox(width: 8),
                _filterChip('Verified', 'Verified', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, bool isDark) {
    final selected = _filter == value;

    Color color;
    IconData icon;

    switch (value) {
      case 'Pending':
        color = accentAmber;
        icon = Icons.pending_rounded;
        break;
      case 'Verified':
        color = accentGreen;
        icon = Icons.verified_rounded;
        break;
      default:
        color = primary;
        icon = Icons.list_rounded;
    }

    return GestureDetector(
      onTap: () => _onFilterChanged(value),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BODY — responsive
  // ============================================================
  Widget _buildBody(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_filtered.isEmpty) {
      return _buildEmpty(textPrimary, textSecondary);
    }

    // ✅ padding متغير حسب حجم الشاشة
    final hPad = isDesktop ? 40.0 : 20.0;
    final bottomPad = isDesktop ? 60.0 : 30.0;

    return RefreshIndicator(
      color: accentGreen,
      onRefresh: _loadProgrammers,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, bottomPad),
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          return _buildCard(
            _filtered[i],
            isDark,
            cardColor,
            textPrimary,
            textSecondary,
            isDesktop: isDesktop,
          );
        },
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> p,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    required bool isDesktop,
  }) {
    final userId = p['userId'] ?? 0;
    final nickname = p['nickname'] ?? 'User';
    final email = p['email'] ?? '';
    final specialty = p['specialty'] ?? '-';
    final university = p['university'] ?? '-';
    final isVerified = p['isVerified'] == true;
    final hasImage = p['hasImage'] == true;
    final hasCV = p['hasCV'] == true;
    final hasCertificate = p['hasCertificate'] == true;

    final statusColor = isVerified ? accentGreen : accentAmber;
    final avatarSize = isDesktop ? 64.0 : 56.0;

    return GestureDetector(
      onTap: () => _openDetails(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withOpacity(isDark ? 0.3 : 0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(isDark ? 0.12 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? Image.network(
                            ApiService.getProgrammerImageUrl(userId),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarFallback(statusColor),
                          )
                        : _avatarFallback(statusColor),
                  ),
                ),
                SizedBox(width: isDesktop ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isDesktop ? 17 : 15.5,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified
                                      ? Icons.verified_rounded
                                      : Icons.pending_rounded,
                                  size: 11,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isVerified ? 'Verified' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDesktop ? 13 : 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _miniTag(
                            Icons.workspace_premium_outlined,
                            specialty,
                            const Color(0xFF8B5CF6),
                          ),
                          if (hasCV)
                            _miniTag(
                              Icons.description_outlined,
                              'CV',
                              const Color(0xFF3B82F6),
                            ),
                          if (hasCertificate)
                            _miniTag(
                              Icons.verified_outlined,
                              'Cert',
                              const Color(0xFF10B981),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 14,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      university,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(Color color) {
    return Container(
      color: color.withOpacity(0.12),
      child: Icon(
        Icons.person_rounded,
        color: color,
        size: 28,
      ),
    );
  }

  Widget _miniTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: accentGreen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 48,
              color: accentGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Programmers Found',
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