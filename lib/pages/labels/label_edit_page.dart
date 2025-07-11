import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            ...List.generate(leftLabels.length, (i) {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: leftLabels[i],
                      decoration: InputDecoration(labelText: '左ラベル'),
                      onChanged: (v) => leftLabels[i] = v,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: rightLabels[i],
                      decoration: InputDecoration(labelText: '右ラベル'),
                      onChanged: (v) => rightLabels[i] = v,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => _deleteLabel(i),
                  ),
                ],
              );
            }),
            TextButton.icon(
              icon: Icon(Icons.add),
              label: Text('ラベルを追加'),
              onPressed: _addLabel,
            ),
          ],
        ),
      ),
    );
  }
}
