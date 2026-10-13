import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import 'user_profile_page.dart';

class SearchUsersPage extends StatefulWidget {
  final int currentUserId;

  const SearchUsersPage({super.key, required this.currentUserId});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<UserSearchResult> _results = [];
  bool _isLoading = false;
  String _filter = 'All';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(q);
    });
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final type = _filter == 'All' ? null : _filter;
    final results = await PostService.searchUsers(query: q, userType: type);

    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _openProfile(int userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: userId,
          currentUserId: widget.currentUserId,
          authorName: 'User',
          authorType: 'Customer',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find People',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Search customers & programmers',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  style: TextStyle(color: textPrimary, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or specialty...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B5CF6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('All', 'All', isDark),
                    const SizedBox(width: 8),
                    _chip('Customer', 'Customers', isDark),
                    const SizedBox(width: 8),
                    _chip('Programmer', 'Programmers', isDark),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                  : _controller.text.isEmpty
                      ? _empty('Start typing to search', Icons.search_rounded, textSecondary)
                      : _results.isEmpty
                          ? _empty('No results found', Icons.person_off_rounded, textSecondary)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: _results.length,
                              itemBuilder: (_, i) => _userTile(
                                _results[i],
                                cardColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label, bool isDark) {
    final selected = _filter == value;
    final color = value == 'Programmer'
        ? const Color(0xFF8B5CF6)
        : value == 'Customer'
            ? const Color(0xFF10B981)
            : const Color(0xFF3B82F6);

    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _search(_controller.text);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(isDark ? 0.15 : 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _userTile(
    UserSearchResult u,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final isProg = u.userType == 'Programmer';
    final accent = isProg ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    return GestureDetector(
      onTap: () => _openProfile(u.userId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent, width: 2),
              ),
              child: ClipOval(
                child: u.hasImage
                    ? Image.network(
                        PostService.getUserAvatarUrl(u.userId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          isProg ? Icons.code_rounded : Icons.person_rounded,
                          color: accent,
                          size: 24,
                        ),
                      )
                    : Icon(
                        isProg ? Icons.code_rounded : Icons.person_rounded,
                        color: accent,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    u.specialty ?? u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                u.userType,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: color.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}