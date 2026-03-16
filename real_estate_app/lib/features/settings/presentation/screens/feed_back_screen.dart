import 'package:flutter/material.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/snackbar_utils.dart';


class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      SnackbarUtils.showSuccess(context, 'Thank you for your feedback!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
        elevation: isDesktop ? 0 : null,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxFormWidth(context),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              children: [
                if (isDesktop) SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
                Text(
                  'We value your feedback',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 24,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: isDesktop ? TextAlign.center : TextAlign.start,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Text(
                  'Let us know how we can improve your experience',
                  style: TextStyle(
                    color: ThemeConfig.textSecondaryColor,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                  ),
                  textAlign: isDesktop ? TextAlign.center : TextAlign.start,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
                    DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
                    DropdownMenuItem(value: 'User Experience', child: Text('User Experience')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
                TextFormField(
                  controller: _feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Your Feedback',
                    hintText: 'Tell us what you think...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: ResponsiveHelper.isMobile(context) ? 6 : 8,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your feedback';
                    }
                    if (value.length < 10) {
                      return 'Feedback must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              desktop: 18,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}