import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// WEB版専用のUIユーティリティクラス
class WebUIUtils {
  /// WEB版かどうかを判定
  static bool get isWeb => kIsWeb;

  /// デスクトップサイズかどうかを判定
  static bool isDesktop(BuildContext context) {
    if (!isWeb) return false;
    final size = MediaQuery.of(context).size;
    return size.width > 1200;
  }

  /// タブレットサイズかどうかを判定
  static bool isTablet(BuildContext context) {
    if (!isWeb) return false;
    final size = MediaQuery.of(context).size;
    return size.width > 768 && size.width <= 1200;
  }

  /// モバイルサイズかどうかを判定
  static bool isMobile(BuildContext context) {
    if (!isWeb) return true;
    final size = MediaQuery.of(context).size;
    return size.width <= 768;
  }

  /// 画面サイズに応じたパディングを取得
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (!isWeb) {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }

    if (isDesktop(context)) {
      return EdgeInsets.symmetric(horizontal: 20, vertical: 0);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 24, vertical: 0);
    } else {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 0);
    }
  }

  /// 画面サイズに応じた最大幅を取得
  static double getMaxWidth(BuildContext context) {
    if (!isWeb) {
      return double.infinity;
    }

    if (isDesktop(context)) {
      return 1800;
    } else if (isTablet(context)) {
      return 1200;
    } else {
      return double.infinity;
    }
  }

  /// 画面サイズに応じたグリッドの列数を取得
  static int getGridColumnCount(BuildContext context) {
    if (!isWeb) {
      return 2;
    }

    if (isDesktop(context)) {
      return 5;
    } else if (isTablet(context)) {
      return 4;
    } else {
      return 3;
    }
  }

  /// 画面サイズに応じたフォントサイズのスケールを取得
  static double getFontSizeScale(BuildContext context) {
    if (!isWeb) {
      return 1.0;
    }

    if (isDesktop(context)) {
      return 1.3;
    } else if (isTablet(context)) {
      return 1.15;
    } else {
      return 1.0;
    }
  }

  /// WEB版用のレスポンシブコンテナを作成
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
    double? maxWidth,
  }) {
    if (!isWeb) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? getMaxWidth(context)),
        child: Padding(
          padding: padding ?? getResponsivePadding(context),
          child: child,
        ),
      ),
    );
  }

  /// WEB版用のグリッドレイアウトを作成
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    double? childAspectRatio,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
  }) {
    final columnCount = getGridColumnCount(context);

    return GridView.count(
      crossAxisCount: columnCount,
      childAspectRatio: childAspectRatio ?? 1.0,
      crossAxisSpacing: crossAxisSpacing ?? 12,
      mainAxisSpacing: mainAxisSpacing ?? 12,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: children,
    );
  }

  /// WEB版用のサイドバーナビゲーションを作成
  static Widget createSidebarNavigation({
    required BuildContext context,
    required List<NavigationItem> items,
    required int selectedIndex,
    required Function(int) onItemSelected,
  }) {
    if (!isWeb || !isDesktop(context)) {
      return SizedBox.shrink();
    }

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedIndex == index;

          return ListTile(
            leading: Icon(
              item.icon,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).iconTheme.color,
            ),
            title: Text(
              item.title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onTap: () => onItemSelected(index),
          );
        },
      ),
    );
  }

  /// WEB版用のヘッダーナビゲーションを作成
  static Widget createHeaderNavigation({
    required BuildContext context,
    required List<NavigationItem> items,
    required int selectedIndex,
    required Function(int) onItemSelected,
  }) {
    if (!isWeb) {
      return SizedBox.shrink();
    }

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => onItemSelected(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 24,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Theme.of(
                                    context,
                                  ).iconTheme.color?.withValues(alpha: 0.7),
                          ),
                          SizedBox(width: 12),
                          Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).textTheme.bodyLarge?.color
                                        ?.withValues(alpha: 0.8),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ナビゲーションアイテムのモデル
class NavigationItem {
  final String title;
  final IconData icon;
  final Widget? page;

  NavigationItem({required this.title, required this.icon, this.page});
}
