import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:devlink/main.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/media_url.dart';
import '../../widgets/own_avatar_image.dart';
import '../../widgets/sign_out_dialog.dart';
import '../../services/weather_service.dart';
import '../../services/location_service.dart'
    if (dart.library.html) '../../services/location_service_web.dart';
import '../../widgets/theme_toggle.dart';
import '../../widgets/notification_bell.dart';
import '../../theme/theme_manager.dart';
import '../Customer/search_users_page.dart';
import '../Customer/user_profile_page.dart';
import '../Customer/widgets/post_card.dart';
import 'programmer_dashboard_page.dart';
import 'programmer_saved_posts_page.dart';
import 'my_applications_page.dart';
import '../Common/active_work_page.dart';

class ProgrammerHomePage extends StatefulWidget {
  final int userId;
  final String authorName;
  final String authorType;

  const ProgrammerHomePage({
    super.key,
    required this.userId,
    this.authorName = 'Programmer',
    this.authorType = 'Programmer',
  });

  @override
  State<ProgrammerHomePage> createState() => _ProgrammerHomePageState();
}

class _ProgrammerHomePageState extends State<ProgrammerHomePage>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<PostModel> _posts = [];
  List<UserSearchResult> _suggestedPeople = [];
  bool _isLoading = true;

  WeatherData? _weather;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // ✅ الألوان صارت أزرق (للمبرمج)
  final Color primary = const Color(0xFF3B82F6);
  final Color primaryDark = const Color(0xFF1D4ED8);

  final List<Map<String, dynamic>> _proTips = [
    {
      'icon': Icons.rocket_launch_rounded,
      'title': 'Apply Fast',
      'desc': 'Submit proposals early to increase acceptance chances.',
      'color': const Color(0xFFF59E0B),
    },
    {
      'icon': Icons.star_rounded,
      'title': 'Build Your Rating',
      'desc': 'Deliver quality work to earn 5-star reviews.',
      'color': const Color(0xFF10B981),
    },
    {
      'icon': Icons.verified_rounded,
      'title': 'Get Verified',
      'desc': 'Upload certificates for the verified badge.',
      'color': const Color(0xFF3B82F6),
    },
  ];
  int _currentTipIndex = 0;

  static double _getFeedWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 700;
    if (width > 1100) return 650;
    if (width > 800) return 600;
    return width;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeed();
    _loadSuggestedPeople();
    _loadWeatherFromGps();

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWeatherFromGps();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final posts = await PostService.getFeed(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  Future<void> _loadSuggestedPeople() async {
    final people = await PostService.searchUsers(query: 'a');
    if (!mounted) return;
    setState(() {
      _suggestedPeople =
          people.where((p) => p.userId != widget.userId).take(5).toList();
    });
  }

  Future<void> _loadWeatherFromGps() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        await _loadWeatherFromProfile();
        return;
      }
      final weather = await WeatherService.getWeatherByLocation(
        position.latitude,
        position.longitude,
      );
      if (weather != null) {
        if (mounted) setState(() => _weather = weather);
        return;
      } else {
        await _loadWeatherFromProfile();
      }
    } catch (e) {
      await _loadWeatherFromProfile();
    }
  }

  Future<void> _loadWeatherFromProfile() async {
    try {
      final weather = await WeatherService.getWeather(widget.userId);
      if (mounted && weather != null) {
        setState(() => _weather = weather);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _logout() async {
    // M2.12 (F10): ends the session on the server too; offers "all devices".
    await showSignOutDialog(context);
  }

  void _openProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: userId,
          currentUserId: widget.userId,
          authorName: widget.authorName,
          authorType: widget.authorType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final pages = [
      _buildFeedTab(),
      SearchUsersPage(currentUserId: widget.userId),
      ProgrammerSavedPostsPage(
          userId: widget.userId, authorType: widget.authorType),
      ProgrammerDashboardPage(userId: widget.userId),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _currentIndex == 0
          ? AppBar(
              elevation: 0,
              toolbarHeight: 60,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x223B82F6),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.code_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DevLink',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Active work',
                  icon: const Icon(Icons.work_outline_rounded, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveWorkPage())),
                ),
                IconButton(
                  tooltip: 'My applications',
                  icon: const Icon(Icons.assignment_outlined, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyApplicationsPage(userId: widget.userId)),
                  ),
                ),
                NotificationBell(
                  userId: widget.userId,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                ThemeToggle(themeManager: themeManager, compact: true),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: cardColor,
            selectedItemColor: primary,
            unselectedItemColor:
                isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: 'Search'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_rounded), label: 'Saved'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1100;
        final feedWidth = _getFeedWidth(context);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 100),
                  child: _buildLeftSidebar(
                      isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: feedWidth),
                  child: _buildFeedContent(
                      isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
            ),
            if (isDesktop)
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 20, 100),
                  child: _buildRightSidebar(
                      isDark, cardColor, textPrimary, textSecondary, borderColor),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeedContent(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RefreshIndicator(
        color: primary,
        onRefresh: () async {
          await _loadFeed();
          await _loadWeatherFromGps();
        },
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.work_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find Projects',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Browse open projects and submit proposals',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!isDesktop)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 18, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _weather?.city ?? "Loading...",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary),
                                ),
                                Text(
                                  _weather?.weatherText ?? "Waiting for GPS...",
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _weather?.weatherIcon ?? "⏳",
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _weather != null
                                  ? '${_weather!.temperature.round()}°C'
                                  : '--°C',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                ),
              )
            else if (_posts.isEmpty)
              SliverToBoxAdapter(
                child: _emptyFeed(textPrimary, textSecondary),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => PostCard(
                      post: _posts[i],
                      currentUserId: widget.userId,
                      currentUserType: 'Programmer',
                      onChanged: _loadFeed,
                      onOpenProfile: () => _openProfile(_posts[i].userId),
                    ),
                    childCount: _posts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(
                  child: OwnAvatarImage(
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.code_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Programmer',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_proTips[_currentTipIndex]['icon'] as IconData,
                          size: 16,
                          color: _proTips[_currentTipIndex]['color'] as Color),
                      const SizedBox(width: 6),
                      Text(
                        'Pro Tip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentTipIndex =
                            (_currentTipIndex + 1) % _proTips.length;
                      });
                    },
                    child: Icon(Icons.refresh_rounded,
                        size: 16, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _proTips[_currentTipIndex]['title'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _proTips[_currentTipIndex]['color'] as Color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _proTips[_currentTipIndex]['desc'] as String,
                style: TextStyle(
                    fontSize: 12, color: textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightSidebar(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded,
                      size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested People',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_suggestedPeople.isEmpty)
                Text(
                  'No suggestions',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                )
              else
                ..._suggestedPeople.map(
                    (p) => _suggestedPersonTile(p, textPrimary, textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(
                        _weather?.city ?? "Loading...",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    _weather?.weatherIcon ?? "⏳",
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -1),
                      ),
                      Text(
                        _weather?.weatherText ?? "Waiting for GPS...",
                        style:
                            TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _weather != null
                            ? '${_weather!.temperature.round()}°C'
                            : '--°C',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: primary),
                      ),
                      Text(
                        _weather != null
                            ? '${_weather!.windSpeed.round()} km/h'
                            : '-- km/h',
                        style:
                            TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestedPersonTile(
      UserSearchResult p, Color textPrimary, Color textSecondary) {
    final isProg = p.userType == 'Programmer';
    final accent =
        isProg ? const Color(0xFF3B82F6) : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openProfile(p.userId),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent, width: 1.5),
              ),
              child: ClipOval(
                child: p.hasImage
                    ? Image.network(
                        MediaUrl.resolve(p.avatarUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          isProg ? Icons.code_rounded : Icons.person_rounded,
                          size: 18,
                          color: accent,
                        ),
                      )
                    : Icon(
                        isProg ? Icons.code_rounded : Icons.person_rounded,
                        size: 18,
                        color: accent,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: textPrimary),
                  ),
                  Text(
                    p.userType,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: accent,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFeed(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_outline_rounded,
                size: 56, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back soon for new opportunities!',
            style: TextStyle(fontSize: 13.5, color: textSecondary),
          ),
        ],
      ),
    );
  }
}