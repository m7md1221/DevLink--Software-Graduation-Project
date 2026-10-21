import 'package:flutter/material.dart';

class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key});

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // ✅ أرقام تجريبية (بعدين بنربطها بالباك)
  final Map<String, dynamic> _stats = {
    'totalUsers': 1234,
    'customers': 812,
    'programmers': 422,
    'posts': 2540,
    'pendingPosts': 15,
    'verifiedProgrammers': 287,
    'supportMessages': 56,
    'unreadSupportMessages': 5,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          'Statistics',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: RefreshIndicator(
            color: const Color(0xFF3B82F6),
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final crossAxisCount = isDesktop ? 3 : 2;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Header =====
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Platform Overview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Live statistics of DevLink',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ===== Main Stats Grid =====
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.2 : 1.4,
                        children: [
                          _statCard(
                            'Total Users',
                            '${_stats['totalUsers']}',
                            Icons.people_alt_rounded,
                            const Color(0xFF3B82F6),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                          _statCard(
                            'Customers',
                            '${_stats['customers']}',
                            Icons.person_rounded,
                            const Color(0xFF10B981),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                          _statCard(
                            'Programmers',
                            '${_stats['programmers']}',
                            Icons.code_rounded,
                            const Color(0xFF8B5CF6),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ===== Secondary Stats =====
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.2 : 1.4,
                        children: [
                          _statCard(
                            'Total Posts',
                            '${_stats['posts']}',
                            Icons.article_rounded,
                            const Color(0xFFF59E0B),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                          _statCard(
                            'Pending Posts',
                            '${_stats['pendingPosts']}',
                            Icons.pending_actions_rounded,
                            const Color(0xFFEF4444),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                          _statCard(
                            'Verified Prog.',
                            '${_stats['verifiedProgrammers']}',
                            Icons.verified_rounded,
                            const Color(0xFF06B6D4),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ===== Support =====
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.2 : 1.4,
                        children: [
                          _statCard(
                            'Support Messages',
                            '${_stats['supportMessages']}',
                            Icons.support_agent_rounded,
                            const Color(0xFF0EA5E9),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                          _statCard(
                            'Unread Messages',
                            '${_stats['unreadSupportMessages']}',
                            Icons.mark_email_unread_rounded,
                            const Color(0xFFEC4899),
                            cardColor,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}