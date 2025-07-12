import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class LabelEditPage extends StatefulWidget {
  const LabelEditPage({super.key});

  @override
  _LabelEditPageState createState() => _LabelEditPageState();
}

class _LabelEditPageState extends State<LabelEditPage> {
  List<String> leftLabels = [];
  List<String> rightLabels = [];
  List<String> aMembers = [];
  List<String> bMembers = [];
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      leftLabels = prefs.getStringList('leftLabels') ?? [];
      rightLabels = prefs.getStringList('rightLabels') ?? [];
      aMembers = prefs.getStringList('a班') ?? [];
      bMembers = prefs.getStringList('b班') ?? [];
    });
  }

  void _saveLabels() {
    prefs.setStringList('leftLabels', leftLabels);
    prefs.setStringList('rightLabels', rightLabels);
    // メンバーも保存
    prefs.setStringList('a班', aMembers);
    prefs.setStringList('b班', bMembers);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ラベル保存しました')));
  }

  void _addLabel() {
    setState(() {
      leftLabels.add('');
      rightLabels.add('');

      // ラベル追加時、メンバーも追加
      if (aMembers.length < leftLabels.length) {
        aMembers.add('');
      }
      if (bMembers.length < leftLabels.length) {
        bMembers.add('');
      }
    });
  }

  void _deleteLabel(int i) {
    setState(() {
      leftLabels.removeAt(i);
      rightLabels.removeAt(i);

      // ラベル削除時、メンバーも削除
      if (aMembers.length > leftLabels.length) {
        aMembers.removeAt(i);
      }
      if (bMembers.length > leftLabels.length) {
        bMembers.removeAt(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('担当ラベル編集'),
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveLabels)],
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.label,
                          color: Provider.of<ThemeSettings>(context).iconColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '担当ラベル一覧',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ...List.generate(leftLabels.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: leftLabels[i],
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                                decoration: InputDecoration(
                                  labelText: '左ラベル',
                                  labelStyle: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.label_outline,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  filled: true,
                                  fillColor: Provider.of<ThemeSettings>(
                                    context,
                                  ).inputBackgroundColor,
                                ),
                                onChanged: (v) => leftLabels[i] = v,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: rightLabels[i],
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                ),
                                decoration: InputDecoration(
                                  labelText: '右ラベル',
                                  labelStyle: TextStyle(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.label_outline,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                  ),
                                  filled: true,
                                  fillColor: Provider.of<ThemeSettings>(
                                    context,
                                  ).inputBackgroundColor,
                                ),
                                onChanged: (v) => rightLabels[i] = v,
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteLabel(i),
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('ラベルを追加'),
                        onPressed: _addLabel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context)
                                  .elevatedButtonTheme
                                  .style
                                  ?.backgroundColor
                                  ?.resolve({}) ??
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context)
                                  .elevatedButtonTheme
                                  .style
                                  ?.foregroundColor
                                  ?.resolve({}) ??
                              Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
