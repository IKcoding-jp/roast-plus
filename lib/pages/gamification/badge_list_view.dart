import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/group_gamification_models.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/pages/gamification/badge_list_controller.dart';
import 'package:roastplus/pages/gamification/widgets/badge_card.dart';

class BadgeListView extends StatelessWidget {
  final BadgeListController controller;

  const BadgeListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeSettings>(context);
    final isGroupAdmin = controller.hasGroup; // Simplified access to hasGroup

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'バッジ一覧',
          style: TextStyle(
            color: theme.appBarTextColor,
            fontFamily: 'ZenMaruGothic',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarColor,
        iconTheme: IconThemeData(color: theme.appBarTextColor),
      ),
      backgroundColor: theme.backgroundColor,
      body: FadeTransition(
        opacity: controller.fadeAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isGroupAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      'グループに所属していないため、バッジ機能は利用できません。グループに参加するか、作成してください。',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (isGroupAdmin && controller.cachedProfile == null)
                  Center(
                    child: CircularProgressIndicator(color: theme.iconColor),
                  )
                else if (isGroupAdmin)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'フィルター',
                        style: TextStyle(
                          color: theme.fontColor1,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: controller.categories.entries.map((entry) {
                          final categoryKey = entry.key;
                          final categoryName = entry.value;
                          return FilterChip(
                            label: Text(categoryName),
                            selected:
                                controller.selectedCategory == categoryKey,
                            onSelected: (bool selected) {
                              if (selected) {
                                controller.setSelectedCategory(categoryKey);
                              }
                            },
                            selectedColor: theme.iconColor.withOpacity(0.5),
                            checkmarkColor: theme.fontColor2,
                            labelStyle: TextStyle(
                              color: controller.selectedCategory == categoryKey
                                  ? theme.fontColor2
                                  : theme.fontColor1.withOpacity(0.7),
                            ),
                            backgroundColor: theme.cardBackgroundColor,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: controller.getFilteredBadges().length,
                        itemBuilder: (context, index) {
                          final badge = controller.getFilteredBadges()[index];
                          final isEarned =
                              controller.getEarnedBadgeIds().contains(
                                badge.badgeId,
                              ) ||
                              (badge.category == BadgeCategory.level &&
                                  controller.checkLevelBadgeCondition(badge));
                          final earnedBadge = isEarned
                              ? controller.getEarnedBadge(badge.badgeId)
                              : null;

                          return BadgeCard(
                            condition: badge,
                            isEarned: isEarned,
                            earnedBadge: earnedBadge,
                            progress: controller.calculateBadgeProgress(badge),
                            progressText: controller.getBadgeProgressText(
                              badge,
                            ),
                            description: controller.getBadgeDescription(badge),
                            themeSettings: theme,
                            animationDelay: index * 50, // 各カードに50msの遅延を設定
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
