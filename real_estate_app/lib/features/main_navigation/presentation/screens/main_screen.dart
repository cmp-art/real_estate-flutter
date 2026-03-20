// features/main_navigation/presentation/screens/main_screen.dart
// FULLY RESPONSIVE VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/guest_prompt_dialog.dart';
import '../../../properties/presentation/screens/property_list_screen.dart';
import '../../../chat/presentation/screens/conversations_screen.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../authentication/presentation/screens/profile_screen.dart';
import '../../../settings/presentation/screens/app_translations.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../settings/presentation/screens/notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Lightweight provider: unread notification count from Supabase
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value(0);
  return Supabase.instance.client
      .from('user_notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) => rows.where((r) => r['is_read'] == false).length);
});

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PropertyListScreen(),
    ConversationsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  // Tabs 1, 2, 3 require authentication
  void _onTabSelected(int index) {
    final isGuest = ref.read(isGuestModeProvider);
    if (isGuest && index != 0) {
      final labels = ['', 'Messages', 'Notifications', 'Profile'];
      GuestPromptDialog.show(
        context,
        title: 'Sign In Required',
        message:
            'Sign in or create a free account to access ${labels[index]}.',
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadMessagesCountProvider);
    final unreadNotifCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final currentLanguage = ref.watch(languageProvider).languageCode;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    // Desktop layout with side navigation
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Side navigation rail
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).cardColor,
              indicatorColor: ThemeConfig.primaryColor.withOpacity(0.2),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text(t('home')),
                ),
                NavigationRailDestination(
                  icon: _buildMessageIcon(unreadCount, false),
                  selectedIcon: _buildMessageIcon(unreadCount, true),
                  label: Text(t('messages')),
                ),
                NavigationRailDestination(
                  icon: _buildNotifIcon(unreadNotifCount, false),
                  selectedIcon: _buildNotifIcon(unreadNotifCount, true),
                  label: Text(t('notifications')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: Text(t('profile')),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content area
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // Tablet layout with extended navigation rail
    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              labelType: NavigationRailLabelType.all,
              minWidth: 80,
              backgroundColor: Theme.of(context).cardColor,
              indicatorColor: ThemeConfig.primaryColor.withOpacity(0.2),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text(t('home')),
                ),
                NavigationRailDestination(
                  icon: _buildMessageIcon(unreadCount, false),
                  selectedIcon: _buildMessageIcon(unreadCount, true),
                  label: Text(t('messages')),
                ),
                NavigationRailDestination(
                  icon: _buildNotifIcon(unreadNotifCount, false),
                  selectedIcon: _buildNotifIcon(unreadNotifCount, true),
                  label: Text(t('notifications')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: Text(t('profile')),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout with bottom navigation
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: t('home'),
          ),
          BottomNavigationBarItem(
            icon: _buildMessageIcon(unreadCount, false),
            activeIcon: _buildMessageIcon(unreadCount, true),
            label: t('messages'),
          ),
          BottomNavigationBarItem(
            icon: _buildNotifIcon(unreadNotifCount, false),
            activeIcon: _buildNotifIcon(unreadNotifCount, true),
            label: t('notifications'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: t('profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifIcon(int count, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.notifications : Icons.notifications_outlined),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: ThemeConfig.errorColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageIcon(int unreadCount, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: ThemeConfig.errorColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}