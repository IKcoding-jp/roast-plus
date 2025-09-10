import 'package:google_fonts/google_fonts.dart';

/// フォント読み込み最適化クラス
class FontOptimizer {
  static final Map<String, String> _fontCache = {};
  static bool _isInitialized = false;

  /// フォントファミリーを動的に設定する関数（キャッシュ付き）
  static String getFontFamilyWithFallback(String fontFamily) {
    if (!_isInitialized) {
      _initializeFontCache();
    }

    return _fontCache[fontFamily] ??
        _fontCache['Noto Sans JP'] ??
        'Noto Sans JP';
  }

  /// フォントキャッシュを初期化
  static void _initializeFontCache() {
    try {
      _fontCache['Noto Sans JP'] =
          GoogleFonts.notoSans().fontFamily ?? 'Noto Sans JP';
      _fontCache['ZenMaruGothic'] = 'ZenMaruGothic';
      _fontCache['utsukushiFONT'] = 'utsukushiFONT';
      _fontCache['KiwiMaru'] = 'KiwiMaru';
      _fontCache['HannariMincho'] = 'HannariMincho';
      _fontCache['Harenosora'] = 'Harenosora';
      _isInitialized = true;
    } catch (e) {
      // エラーが発生した場合はデフォルトフォントを設定
      _fontCache['Noto Sans JP'] = 'Noto Sans JP';
      _isInitialized = true;
    }
  }

  /// フォントキャッシュをクリア
  static void clearCache() {
    _fontCache.clear();
    _isInitialized = false;
  }
}
