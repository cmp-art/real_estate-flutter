// features/users/presentation/screens/user_search_screen.dart
// UPDATED VERSION with clear icon inside search bar
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/user_providers.dart';
import 'dart:async';
import 'user_profileview_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  late final isDark = Theme.of(context).brightness == Brightness.dark;
    late final theme = Theme.of(context);
    
    // Get themed colors using ThemeConfig helpers
    late final appBarForegroundColor = ThemeConfig.getColor(
      context,
      lightColor: ThemeConfig.lightAppBarForeground,
      darkColor: ThemeConfig.darkAppBarForeground,
    );
    
    late final inputFillColor = ThemeConfig.getColor(
      context,
      lightColor: ThemeConfig.lightInputFill,
      darkColor: ThemeConfig.darkInputFill,
    );
    
    late final textPrimaryColor = ThemeConfig.getTextPrimaryColor(context);
    late final textSecondaryColor = ThemeConfig.getTextSecondaryColor(context);
  @override
  void initState() {
    super.initState();
    // Auto-focus when screen opens
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
    
    // Listen to text changes to update UI
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(() {});
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start new timer for debouncing
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isNotEmpty) {
        ref.read(userSearchQueryProvider.notifier).state = query.trim();
      } else {
        ref.read(userSearchQueryProvider.notifier).state = '';
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(userSearchQueryProvider.notifier).state = '';
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(userSearchQueryProvider);
    final searchResults = ref.watch(userSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                        ),
          decoration: InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
            hintStyle: TextStyle(
                            color: textSecondaryColor,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                          ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: textSecondaryColor,
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                    tooltip: 'Clear search',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
      /*  actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],*/
      ),
      body: searchQuery.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                  Text(
                    'Search for users',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
                    child: Text(
                      'Type to start searching for users',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : searchResults.when(
              data: (users) {
                if (users.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search,
                    title: 'No Users Found',
                    message: 'No users match "$searchQuery"',
                    actionText: 'Clear Search',
                    onActionPressed: _clearSearch,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                      child: Text(
                        '${users.length} ${users.length == 1 ? 'user' : 'users'} found',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: ThemeConfig.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          
                          // Highlight matching text
                          final nameMatch = user.fullName.toLowerCase().contains(searchQuery.toLowerCase());
                          final emailMatch = user.email.toLowerCase().contains(searchQuery.toLowerCase());

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            leading: Hero(
                              tag: 'user_avatar_${user.id}',
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: user.avatarUrl != null
                                    ? CachedNetworkImageProvider(user.avatarUrl!)
                                    : null,
                                child: user.avatarUrl == null
                                    ? Text(
                                        user.fullName[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                                          fontWeight: FontWeight.bold,
                                          color: ThemeConfig.primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            title: RichText(
                              text: TextSpan(
                                children: _highlightText(
                                  user.fullName,
                                  searchQuery,
                                  nameMatch,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    children: _highlightText(
                                      user.email,
                                      searchQuery,
                                      emailMatch,
                                    ),
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                                      color: ThemeConfig.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeConfig.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user.userType.displayName,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                                          color: ThemeConfig.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileViewScreen(
                                    userId: user.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingIndicator(message: 'Searching users...'),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.red),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    const Text('Error searching users'),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(userSearchResultsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<TextSpan> _highlightText(String text, String query, bool shouldHighlight) {
    if (!shouldHighlight || query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
  }
}