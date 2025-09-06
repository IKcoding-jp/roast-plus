import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/web_ui_utils.dart';
import 'dart:developer' as developer;

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _displayText = '0';
  String _operand1 = '';
  String _operand2 = '';
  String _operator = '';
  bool _isNewCalculation = true;
  bool _hasDecimal = false;

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _clear();
      } else if (value == '⌫') {
        _backspace();
      } else if (['+', '-', '×', '÷'].contains(value)) {
        _setOperator(value);
      } else if (value == '=') {
        _calculate();
      } else if (value == '.') {
        _addDecimal();
      } else {
        _addNumber(value);
      }
    });
  }

  void _clear() {
    _displayText = '0';
    _operand1 = '';
    _operand2 = '';
    _operator = '';
    _isNewCalculation = true;
    _hasDecimal = false;
  }

  void _backspace() {
    if (_displayText.length > 1) {
      _displayText = _displayText.substring(0, _displayText.length - 1);
      _hasDecimal = _displayText.contains('.');
    } else {
      _displayText = '0';
      _hasDecimal = false;
    }
  }

  void _addNumber(String number) {
    if (_isNewCalculation) {
      _displayText = number;
      _isNewCalculation = false;
    } else {
      if (_displayText == '0') {
        _displayText = number;
      } else {
        _displayText += number;
      }
    }
  }

  void _addDecimal() {
    if (!_hasDecimal) {
      if (_isNewCalculation) {
        _displayText = '0.';
        _isNewCalculation = false;
      } else {
        _displayText += '.';
      }
      _hasDecimal = true;
    }
  }

  void _setOperator(String op) {
    if (_operand1.isNotEmpty && _operator.isNotEmpty && !_isNewCalculation) {
      _calculate();
    }
    _operand1 = _displayText;
    _operator = op;
    _isNewCalculation = true;
    _hasDecimal = false;
  }

  void _calculate() {
    if (_operand1.isEmpty || _operator.isEmpty) return;

    _operand2 = _displayText;
    double num1 = double.parse(_operand1);
    double num2 = double.parse(_operand2);
    double result = 0;

    switch (_operator) {
      case '+':
        result = num1 + num2;
        break;
      case '-':
        result = num1 - num2;
        break;
      case '×':
        result = num1 * num2;
        break;
      case '÷':
        if (num2 != 0) {
          result = num1 / num2;
        } else {
          _displayText = 'エラー';
          _clear();
          return;
        }
        break;
    }

    _displayText = result == result.toInt()
        ? result.toInt().toString()
        : result.toString();

    _operand1 = _displayText;
    _operator = '';
    _operand2 = '';
    _isNewCalculation = true;
    _hasDecimal = _displayText.contains('.');
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? textColor,
    double flex = 1,
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Expanded(
      flex: flex.toInt(),
      child: Container(
        margin: EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? themeSettings.buttonColor,
            foregroundColor: textColor ?? themeSettings.fontColor2,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 24 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    // デバッグ用：現在のcalculatorColorの値をログ出力
    developer.log(
      'CalculatorPage: 現在のcalculatorColor: ${themeSettings.calculatorColor}',
      name: 'CalculatorPage',
    );
    developer.log(
      'CalculatorPage: calculatorColorのARGB: ${themeSettings.calculatorColor.toARGB32()}',
      name: 'CalculatorPage',
    );
    developer.log(
      'CalculatorPage: 現在のiconColor: ${themeSettings.iconColor}',
      name: 'CalculatorPage',
    );
    developer.log(
      'CalculatorPage: iconColorのARGB: ${themeSettings.iconColor.toARGB32()}',
      name: 'CalculatorPage',
    );

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.calculate, color: themeSettings.calculatorColor),
            SizedBox(width: 8),
            Text(
              '電卓',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.calculatorColor,
        iconTheme: IconThemeData(color: themeSettings.calculatorColor),
      ),
      body: WebUIUtils.isWeb
          ? _buildWebLayout(themeSettings)
          : _buildMobileLayout(themeSettings),
    );
  }

  Widget _buildWebLayout(ThemeSettings themeSettings) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 800),
        child: Card(
          elevation: 8,
          color: themeSettings.cardBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 表示エリア
                Container(
                  width: double.infinity,
                  height: 180,
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: themeSettings.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: themeSettings.calculatorColor.withValues(
                        alpha: 0.3,
                      ),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_operator.isNotEmpty && _operand1.isNotEmpty) ...[
                        Text(
                          '$_operand1 $_operator',
                          style: TextStyle(
                            fontSize: 24 * themeSettings.fontSizeScale,
                            color: themeSettings.fontColor1.withValues(
                              alpha: 0.6,
                            ),
                            fontFamily: themeSettings.fontFamily,
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _displayText,
                            style: TextStyle(
                              fontSize: 64 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ボタンエリア
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      // 1行目: C, ⌫, ÷
                      SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            _buildButton(
                              text: 'C',
                              onPressed: () => _onButtonPressed('C'),
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.8,
                              ),
                              textColor: Colors.white,
                            ),
                            _buildButton(
                              text: '⌫',
                              onPressed: () => _onButtonPressed('⌫'),
                              backgroundColor: Colors.orange.withValues(
                                alpha: 0.8,
                              ),
                              textColor: Colors.white,
                            ),
                            _buildButton(
                              text: '÷',
                              onPressed: () => _onButtonPressed('÷'),
                              backgroundColor: themeSettings.calculatorColor
                                  .withValues(alpha: 0.8),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      // 2行目: 7, 8, 9, ×
                      SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            _buildButton(
                              text: '7',
                              onPressed: () => _onButtonPressed('7'),
                            ),
                            _buildButton(
                              text: '8',
                              onPressed: () => _onButtonPressed('8'),
                            ),
                            _buildButton(
                              text: '9',
                              onPressed: () => _onButtonPressed('9'),
                            ),
                            _buildButton(
                              text: '×',
                              onPressed: () => _onButtonPressed('×'),
                              backgroundColor: themeSettings.calculatorColor
                                  .withValues(alpha: 0.8),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      // 3行目: 4, 5, 6, -
                      SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            _buildButton(
                              text: '4',
                              onPressed: () => _onButtonPressed('4'),
                            ),
                            _buildButton(
                              text: '5',
                              onPressed: () => _onButtonPressed('5'),
                            ),
                            _buildButton(
                              text: '6',
                              onPressed: () => _onButtonPressed('6'),
                            ),
                            _buildButton(
                              text: '-',
                              onPressed: () => _onButtonPressed('-'),
                              backgroundColor: themeSettings.calculatorColor
                                  .withValues(alpha: 0.8),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      // 4行目: 1, 2, 3, +
                      SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            _buildButton(
                              text: '1',
                              onPressed: () => _onButtonPressed('1'),
                            ),
                            _buildButton(
                              text: '2',
                              onPressed: () => _onButtonPressed('2'),
                            ),
                            _buildButton(
                              text: '3',
                              onPressed: () => _onButtonPressed('3'),
                            ),
                            _buildButton(
                              text: '+',
                              onPressed: () => _onButtonPressed('+'),
                              backgroundColor: themeSettings.calculatorColor
                                  .withValues(alpha: 0.8),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      // 5行目: 0, ., =
                      SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            _buildButton(
                              text: '0',
                              onPressed: () => _onButtonPressed('0'),
                              flex: 2,
                            ),
                            _buildButton(
                              text: '.',
                              onPressed: () => _onButtonPressed('.'),
                            ),
                            _buildButton(
                              text: '=',
                              onPressed: () => _onButtonPressed('='),
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.8,
                              ),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeSettings themeSettings) {
    return SafeArea(
      child: Column(
        children: [
          // 表示エリア
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeSettings.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themeSettings.calculatorColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_operator.isNotEmpty && _operand1.isNotEmpty) ...[
                    Text(
                      '$_operand1 $_operator',
                      style: TextStyle(
                        fontSize: 18 * themeSettings.fontSizeScale,
                        color: themeSettings.fontColor1.withValues(alpha: 0.6),
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _displayText,
                      style: TextStyle(
                        fontSize: 48 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                        fontFamily: themeSettings.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ボタンエリア
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1行目: C, ⌫, ÷
                  Expanded(
                    child: Row(
                      children: [
                        _buildButton(
                          text: 'C',
                          onPressed: () => _onButtonPressed('C'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                        _buildButton(
                          text: '⌫',
                          onPressed: () => _onButtonPressed('⌫'),
                          backgroundColor: Colors.orange.withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                        _buildButton(
                          text: '÷',
                          onPressed: () => _onButtonPressed('÷'),
                          backgroundColor: themeSettings.calculatorColor
                              .withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),

                  // 2行目: 7, 8, 9, ×
                  Expanded(
                    child: Row(
                      children: [
                        _buildButton(
                          text: '7',
                          onPressed: () => _onButtonPressed('7'),
                        ),
                        _buildButton(
                          text: '8',
                          onPressed: () => _onButtonPressed('8'),
                        ),
                        _buildButton(
                          text: '9',
                          onPressed: () => _onButtonPressed('9'),
                        ),
                        _buildButton(
                          text: '×',
                          onPressed: () => _onButtonPressed('×'),
                          backgroundColor: themeSettings.calculatorColor
                              .withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),

                  // 3行目: 4, 5, 6, -
                  Expanded(
                    child: Row(
                      children: [
                        _buildButton(
                          text: '4',
                          onPressed: () => _onButtonPressed('4'),
                        ),
                        _buildButton(
                          text: '5',
                          onPressed: () => _onButtonPressed('5'),
                        ),
                        _buildButton(
                          text: '6',
                          onPressed: () => _onButtonPressed('6'),
                        ),
                        _buildButton(
                          text: '-',
                          onPressed: () => _onButtonPressed('-'),
                          backgroundColor: themeSettings.calculatorColor
                              .withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),

                  // 4行目: 1, 2, 3, +
                  Expanded(
                    child: Row(
                      children: [
                        _buildButton(
                          text: '1',
                          onPressed: () => _onButtonPressed('1'),
                        ),
                        _buildButton(
                          text: '2',
                          onPressed: () => _onButtonPressed('2'),
                        ),
                        _buildButton(
                          text: '3',
                          onPressed: () => _onButtonPressed('3'),
                        ),
                        _buildButton(
                          text: '+',
                          onPressed: () => _onButtonPressed('+'),
                          backgroundColor: themeSettings.calculatorColor
                              .withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),

                  // 5行目: 0, ., =
                  Expanded(
                    child: Row(
                      children: [
                        _buildButton(
                          text: '0',
                          onPressed: () => _onButtonPressed('0'),
                          flex: 2,
                        ),
                        _buildButton(
                          text: '.',
                          onPressed: () => _onButtonPressed('.'),
                        ),
                        _buildButton(
                          text: '=',
                          onPressed: () => _onButtonPressed('='),
                          backgroundColor: Colors.green.withValues(alpha: 0.8),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
