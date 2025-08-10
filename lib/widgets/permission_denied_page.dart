import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_settings.dart';

class PermissionDeniedPage extends StatelessWidget {
  final String title;
  final String message;
  final String? additionalInfo;
  final VoidCallback? onBackPressed;
  final IconData? customIcon;

  const PermissionDeniedPage({
    super.key,
    required this.title,
    required this.message,
    this.additionalInfo,
    this.onBackPressed,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                customIcon ?? Icons.lock,
                size: 80,
                color: themeSettings.fontColor1.withValues(alpha: 0.5),
              ),
              SizedBox(height: 24),
              Text(
                '権限がありません',
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 20 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: themeSettings.fontColor1.withValues(alpha: 0.7),
                  fontSize: 14 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              if (additionalInfo != null) ...[
                SizedBox(height: 16),
                Text(
                  additionalInfo!,
                  style: TextStyle(
                    color: themeSettings.fontColor1.withValues(alpha: 0.5),
                    fontSize: 12 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: onBackPressed ?? () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: themeSettings.fontColor2,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  '戻る',
                  style: TextStyle(
                    fontSize: 16 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
