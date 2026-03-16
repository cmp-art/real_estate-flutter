import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
        elevation: isDesktop ? 0 : null,
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context),
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            if (isDesktop) ...[
              Text(
                'Help Center',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobile: 24,
                    desktop: 32,
                  ),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobile: 18,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            ],
            _buildFAQItem(
              context,
              'How do I list a property?',
              'To list a property, go to the Properties tab and tap the "Add Property" button. Fill in all the required details including title, description, price, location, and upload photos.',
            ),
            _buildFAQItem(
              context,
              'How do I search for properties?',
              'Use the search icon in the Properties tab to search by keywords. You can also use filters to narrow down your search by price, location, property type, and more.',
            ),
            _buildFAQItem(
              context,
              'How do I save favorite properties?',
              'Tap the heart icon on any property card to add it to your favorites. You can view all your favorites in the Favorites tab.',
            ),
            _buildFAQItem(
              context,
              'How do I edit my profile?',
              'Go to Settings > Edit Profile to update your personal information including name, phone number, and profile picture.',
            ),
            _buildFAQItem(
              context,
              'How do I delete my account?',
              'If you wish to delete your account, please contact our support team at support@realestate.com. Note that this action is permanent and cannot be undone.',
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            Text(
              'Still need help?',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
            Card(
              elevation: ResponsiveHelper.getResponsiveElevation(context),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getResponsivePadding(context),
                  vertical: ResponsiveHelper.getResponsiveSpacing(context) / 2,
                ),
                leading: Icon(
                  Icons.email,
                  color: ThemeConfig.primaryColor,
                  size: ResponsiveHelper.getResponsiveIconSize(context),
                ),
                title: Text(
                  'Email Support',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 16,
                      desktop: 18,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'support@realestate.com',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      desktop: 16,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: ResponsiveHelper.getResponsiveIconSize(context),
                ),
                onTap: () {
                  // Open email client
                },
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Card(
              elevation: ResponsiveHelper.getResponsiveElevation(context),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getResponsivePadding(context),
                  vertical: ResponsiveHelper.getResponsiveSpacing(context) / 2,
                ),
                leading: Icon(
                  Icons.phone,
                  color: ThemeConfig.primaryColor,
                  size: ResponsiveHelper.getResponsiveIconSize(context),
                ),
                title: Text(
                  'Phone Support',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 16,
                      desktop: 18,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '+1 (555) 123-4567',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      desktop: 16,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: ResponsiveHelper.getResponsiveIconSize(context),
                ),
                onTap: () {
                  // Open phone dialer
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Card(
      elevation: ResponsiveHelper.getResponsiveElevation(context),
      margin: EdgeInsets.only(
        bottom: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.getResponsivePadding(context),
          vertical: ResponsiveHelper.getResponsiveSpacing(context) / 4,
        ),
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveHelper.getResponsiveFontSize(
              context,
              mobile: 16,
              tablet: 17,
              desktop: 18,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            child: Text(
              answer,
              style: TextStyle(
                color: ThemeConfig.textSecondaryColor,
                height: 1.5,
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}