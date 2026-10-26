import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

class _AdminPostsPageState extends State<AdminPostsPage>
    with TickerProviderStateMixin {
  List<PostModel> _pendingPosts = [];
  bool _isLoading = true;

  int _totalPending = 0;
  int _totalImages = 0;

  late AnimationController _entranceController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _entranceController.forward();
    _load();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await PostService.getPendingPosts();
    if (!mounted) return;
    setState(() {
      _pendingPosts = list;
      _totalPending = list.length;
      _totalImages = list.fold(0, (sum, post) => sum + post.images.length);
      _isLoading = false;
    });
  }

  Future<void> _approve(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Post?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Approve this post by ${post.authorName}?', style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await PostService.approvePost(post.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _showSnack('✅ Post approved', const Color(0xFF10B981));
      _load();
    } else {
      _showSnack(result['message'] ?? 'Failed', const Color(0xFFEF4444));
    }
  }

  Future<void> _reject(PostModel post) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Post', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject post by ${post.authorName}?', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            const Text('Leave a note explaining the reason. The user will receive it via email.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Leave a note *',
                hintText: 'e.g. Please remove inappropriate content...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isEmpty) {
                _showSnack('Please write a note', const Color(0xFFF59E0B));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await PostService.rejectPost(
      postId: post.id,
      reason: noteController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _showSnack('❌ Post rejected', const Color(0xFFEF4444));
      _load();
    } else {
      _showSnack(result['message'] ?? 'Failed', const Color(0xFFEF4444));
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
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
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Icon(
                Icons.arrow_back_rounded,
                color: textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_rounded, color: Color(0xFFF59E0B), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Posts Management',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: const [], 
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                  : Column(
                      children: [
                        _buildGuidelinesCard(isDark, cardColor, textPrimary, textSecondary),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Pending Posts',
                                  '$_totalPending',
                                  Icons.pending_actions_rounded,
                                  const Color(0xFFF59E0B),
                                  cardColor,
                                  textPrimary,
                                  textSecondary,
                                  borderColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Images',
                                  '$_totalImages',
                                  Icons.image_rounded,
                                  const Color(0xFF3B82F6),
                                  cardColor,
                                  textPrimary,
                                  textSecondary,
                                  borderColor,
                                ),
                              ),
                              if (isDesktop) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Status',
                                    'Needs Review',
                                    Icons.info_outline_rounded,
                                    const Color(0xFFEF4444),
                                    cardColor,
                                    textPrimary,
                                    textSecondary,
                                    borderColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        Expanded(
                          child: _pendingPosts.isEmpty
                              ? _buildEmptyState(textPrimary, textSecondary)
                              : RefreshIndicator(
                                  color: const Color(0xFFF59E0B),
                                  onRefresh: _load,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                                    itemCount: _pendingPosts.length,
                                    itemBuilder: (_, i) => _buildPostCard(
                                      _pendingPosts[i],
                                      isDark,
                                      cardColor,
                                      textPrimary,
                                      textSecondary,
                                      borderColor,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelinesCard(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(isDark ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Guidelines',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Before approving a post, please ensure it does not contain any political or offensive language. The idea of the project must align with ethical and community standards.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary)),
            Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, size: 56, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          Text('All Caught Up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
          const SizedBox(height: 6),
          Text('No pending posts to review', style: TextStyle(fontSize: 13.5, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post, bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return _HoverCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (post.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withOpacity(0.12),
                    border: Border.all(color: post.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981), width: 2),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      PostService.getUserAvatarUrl(post.userId),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        post.authorType == 'Programmer' ? Icons.code_rounded : Icons.person_rounded,
                        color: post.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary)),
                      Text(post.authorType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: post.authorType == 'Programmer' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (post.content != null && post.content!.trim().isNotEmpty)
              Text(post.content!, style: TextStyle(fontSize: 14.5, color: textPrimary, height: 1.5)),

            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.images.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        PostService.getPostImageUrl(post.images[i].id),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Color(0xFF94A3B8))),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(post),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}