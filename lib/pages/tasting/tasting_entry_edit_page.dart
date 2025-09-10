import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/tasting_models.dart';
import '../../models/theme_settings.dart';
// import '../../models/group_provider.dart';
import '../../services/tasting_firestore_service.dart';

/// 任意: 単体のエントリ編集用（詳細ページ内フォームを使う想定のため最小）
class TastingEntryEditPage extends StatefulWidget {
  final String groupId;
  final String sessionId;
  final TastingEntry? initial;

  const TastingEntryEditPage({
    super.key,
    required this.groupId,
    required this.sessionId,
    this.initial,
  });

  @override
  State<TastingEntryEditPage> createState() => _TastingEntryEditPageState();
}

class _TastingEntryEditPageState extends State<TastingEntryEditPage> {
  final TextEditingController _commentCtrl = TextEditingController();
  double _bitterness = 3,
      _acidity = 3,
      _body = 3,
      _sweetness = 3,
      _aroma = 3,
      _overall = 3;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    if (e != null) {
      _bitterness = e.bitterness;
      _acidity = e.acidity;
      _body = e.body;
      _sweetness = e.sweetness;
      _aroma = e.aroma;
      _overall = e.overall;
      _commentCtrl.text = e.comment;
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final entry = TastingEntry(
      id: uid,
      userId: uid,
      bitterness: _bitterness,
      acidity: _acidity,
      body: _body,
      sweetness: _sweetness,
      aroma: _aroma,
      overall: _overall,
      comment: _commentCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await TastingFirestoreService.upsertEntry(
      widget.groupId,
      widget.sessionId,
      entry,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('エントリ編集'),
        backgroundColor: theme.appBarColor,
        foregroundColor: theme.appBarTextColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _slider('苦味', _bitterness, (v) => setState(() => _bitterness = v)),
            _slider('酸味', _acidity, (v) => setState(() => _acidity = v)),
            _slider('ボディ', _body, (v) => setState(() => _body = v)),
            _slider('甘み', _sweetness, (v) => setState(() => _sweetness = v)),
            _slider('香り', _aroma, (v) => setState(() => _aroma = v)),
            _slider('総合', _overall, (v) => setState(() => _overall = v)),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'コメント',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: Text('保存')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    final theme = Provider.of<ThemeSettings>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.fontColor1,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.fontColor1,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 5.0,
          divisions: 8,
          activeColor: theme.buttonColor,
          inactiveColor: theme.fontColor1.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
