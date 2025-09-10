import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async'; // Added for StreamSubscription

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  int? _selectedAmount;
  final List<int> _amountOptions = [300, 500, 1000, 3000, 5000];
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _onDonate() async {
    // in_app_purchaseによる課金処理（テスト用商品ID）
    final user = FirebaseAuth.instance.currentUser;
    const String testProductId = 'android.test.purchased';
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('エラー'),
          content: Text('課金サービスが利用できません'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }
    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails({testProductId});
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('エラー'),
          content: Text('テスト用商品が見つかりません'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }
    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );
    InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);

    // 購入完了を監視
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.status == PurchaseStatus.purchased) {
            // FirestoreへisDonorフラグを保存
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('settings')
                  .doc('donation')
                  .set({'isDonor': true}, SetOptions(merge: true));
            }
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('寄付完了'),
                content: Text('ご寄付ありがとうございました！\n寄付者特典が有効になりました'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // ダイアログを閉じる
                      Navigator.pop(context); // DonationPageも閉じる
                    },
                    child: Text('閉じる'),
                  ),
                ],
              ),
            );
            subscription.cancel();
          } else if (purchase.status == PurchaseStatus.error) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('エラー'),
                content: Text('購入処理中にエラーが発生しました'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('閉じる'),
                  ),
                ],
              ),
            );
            subscription.cancel();
          }
        }
      },
      onDone: () => subscription.cancel(),
      onError: (_) => subscription.cancel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('寄付で応援する')),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600, // Web版での最大幅を制限
            ),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 開発者メッセージ
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism,
                              color: Colors.amber,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '開発者からのメッセージ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'このアプリは、BYSNで実際に働いている従業員が作っている非公式アプリです。寄付で応援していただけるととても励みになります。\n開発に役立てて今後もより良いアプリにしていきますので、どうぞよろしくお願いします！',
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // 金額選択・寄付UI
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '寄付金額を選択してください（300円から）',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: _amountOptions
                              .map(
                                (amount) => ChoiceChip(
                                  label: Text('¥$amount'),
                                  selected: _selectedAmount == amount,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedAmount = selected
                                          ? amount
                                          : null;
                                      _customAmountController.clear();
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customAmountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'その他の金額（300円以上）',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAmount = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32),
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              Icons.volunteer_activism,
                              color: Colors.white,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              int? amount =
                                  _selectedAmount ??
                                  int.tryParse(_customAmountController.text);
                              if (amount == null || amount < 300) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('300円以上の金額を入力してください')),
                                );
                                return;
                              }
                              _onDonate();
                            },
                            label: Text(
                              '寄付する',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Card(
                          elevation: 0,
                          color: Colors.amber[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: Colors.amber,
                                      size: 28,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '寄付者特典',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.block,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '広告が永久に非表示',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.palette,
                                      color: Colors.blueAccent,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '22種類のカラーテーマが開放',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.font_download,
                                      color: Colors.green,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '5種類のフォントが開放',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
