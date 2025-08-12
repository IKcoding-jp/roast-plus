/// テキスト入力に関するユーティリティ関数
class TextInputUtils {
  /// 全角数字を半角数字に変換する
  static String convertFullWidthToHalfWidth(String text) {
    return text.replaceAllMapped(RegExp(r'[０-９]'), (match) {
      final fullWidthChar = match.group(0)!;
      final halfWidthChar = String.fromCharCode(
        fullWidthChar.codeUnitAt(0) - 0xFEE0,
      );
      return halfWidthChar;
    });
  }

  /// 全角英字を半角英字に変換する
  static String convertFullWidthToHalfWidthAlphabet(String text) {
    return text.replaceAllMapped(RegExp(r'[Ａ-Ｚａ-ｚ]'), (match) {
      final fullWidthChar = match.group(0)!;
      final halfWidthChar = String.fromCharCode(
        fullWidthChar.codeUnitAt(0) - 0xFEE0,
      );
      return halfWidthChar;
    });
  }

  /// 全角記号を半角記号に変換する
  static String convertFullWidthToHalfWidthSymbols(String text) {
    return text
        .replaceAll('：', ':')
        .replaceAll('．', '.')
        .replaceAll('，', ',')
        .replaceAll('！', '!')
        .replaceAll('？', '?')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('［', '[')
        .replaceAll('］', ']')
        .replaceAll('｛', '{')
        .replaceAll('｝', '}')
        .replaceAll('「', '"')
        .replaceAll('」', '"')
        .replaceAll('『', "'")
        .replaceAll('』', "'")
        .replaceAll('ー', '-')
        .replaceAll('～', '~');
  }

  /// 全角文字を半角文字に変換する（数字、英字、記号）
  static String convertAllFullWidthToHalfWidth(String text) {
    return convertFullWidthToHalfWidthSymbols(
      convertFullWidthToHalfWidthAlphabet(convertFullWidthToHalfWidth(text)),
    );
  }
}
