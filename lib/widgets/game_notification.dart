import 'package:flutter/material.dart';

/// Widget for displaying game notifications (check, checkmate, etc.)
class GameNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;
  final VoidCallback? onDismiss;

  const GameNotification({
    super.key,
    required this.message,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<GameNotification> createState() => _GameNotificationState();
}

class _GameNotificationState extends State<GameNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Start animation
    _animationController.forward();
    
    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIcon(),
                    color: widget.textColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close,
                      color: widget.textColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon() {
    if (widget.message.toLowerCase().contains('checkmate')) {
      return Icons.sports_esports;
    } else if (widget.message.toLowerCase().contains('check')) {
      return Icons.warning;
    } else if (widget.message.toLowerCase().contains('win')) {
      return Icons.emoji_events;
    } else if (widget.message.toLowerCase().contains('draw')) {
      return Icons.handshake;
    }
    return Icons.info;
  }
}

/// Overlay widget for displaying game notifications
class GameNotificationOverlay extends StatefulWidget {
  final Widget child;
  final List<GameNotification> notifications;

  const GameNotificationOverlay({
    super.key,
    required this.child,
    this.notifications = const [],
  });

  @override
  State<GameNotificationOverlay> createState() => _GameNotificationOverlayState();
}

class _GameNotificationOverlayState extends State<GameNotificationOverlay> {
  final List<GameNotification> _notifications = [];

  void addNotification(GameNotification notification) {
    setState(() {
      _notifications.add(notification);
    });
  }

  void removeNotification(GameNotification notification) {
    setState(() {
      _notifications.remove(notification);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._notifications.map((notification) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GameNotification(
            message: notification.message,
            backgroundColor: notification.backgroundColor,
            textColor: notification.textColor,
            duration: notification.duration,
            onDismiss: () => removeNotification(notification),
          ),
        )),
      ],
    );
  }
}
