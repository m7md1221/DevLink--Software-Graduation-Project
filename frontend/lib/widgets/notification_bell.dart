import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  final int userId;
  final bool isDark;

  const NotificationBell({
    super.key,
    required this.userId,
    required this.isDark,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final MenuController _menuController = MenuController();
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    
    // ✅ فحص الإشعارات كل 30 ثانية عشان تظهر النقطة الحمراء أول ما يجي إشعار جديد
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationService.getNotifications(widget.userId);
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _unreadCount = list.where((n) => !n.isRead).length;
    });
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.comment_rounded;
      case 'accepted': return Icons.check_circle_rounded;
      case 'approved': return Icons.verified_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'like': return const Color(0xFFEF4444);
      case 'comment': return const Color(0xFF3B82F6);
      case 'accepted': return const Color(0xFF10B981);
      case 'approved': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF8B5CF6);
    }
  }

  // ✅ دالة لتعليم كل الإشعارات كمقروءة أول ما تفتح القائمة
  Future<void> _markAllAsRead() async {
    for (var notif in _notifications) {
      if (!notif.isRead) {
        await NotificationService.markAsRead(notif.id);
      }
    }
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white60 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-290, 10),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(bgColor),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
        ),
        elevation: const WidgetStatePropertyAll(15),
      ),
      menuChildren: [
        Container(
          width: 340,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
              if (_unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('$_unreadCount new', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                ),
            ],
          ),
        ),
        if (_notifications.isEmpty)
          Container(
            width: 340,
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Icon(Icons.notifications_off_rounded, size: 40, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 10),
                Text('No notifications yet', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          )
        else
          Container(
            width: 340,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _notifications.map((notif) {
                  return InkWell(
                    onTap: () async {
                      if (!notif.isRead) {
                        await NotificationService.markAsRead(notif.id);
                        _loadNotifications();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: dividerColor)),
                        color: notif.isRead ? Colors.transparent : _getIconColor(notif.type).withOpacity(0.05),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: _getIconColor(notif.type).withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(_getIcon(notif.type), color: _getIconColor(notif.type), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notif.title, style: TextStyle(fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w900, color: textColor, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(notif.message, style: TextStyle(color: subTextColor, fontSize: 12, height: 1.4)),
                              ],
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              margin: const EdgeInsets.only(top: 4, left: 8),
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        return Stack(
          children: [
            IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  _loadNotifications();
                  _markAllAsRead(); // ✅ أول ما تفتح القائمة، بتتعلم كل الإشعارات كمقروءة
                  controller.open();
                }
              },
              icon: Icon(
                Icons.notifications_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }
}