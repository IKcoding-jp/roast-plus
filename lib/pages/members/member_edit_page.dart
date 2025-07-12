import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/assignment_firestore_service.dart';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({super.key});

  @override
  _MemberEditPageState createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  List<String> aMembers = [];
  List<String> bMembers = [];
  List<String> leftLabels = [];
  List<String> rightLabels = [];
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      aMembers = prefs.getStringList('a班') ?? [];
      bMembers = prefs.getStringList('b班') ?? [];
      leftLabels = prefs.getStringList('leftLabels') ?? [];
      rightLabels = prefs.getStringList('rightLabels') ?? [];
    });
  }

  void _saveMembers() {
    prefs.setStringList('a班', aMembers);
    prefs.setStringList('b班', bMembers);
    // ラベルも保存
    prefs.setStringList('leftLabels', leftLabels);
    prefs.setStringList('rightLabels', rightLabels);
    // Firestoreにも保存
    AssignmentFirestoreService.saveAssignmentMembers(
      aMembers: aMembers,
      bMembers: bMembers,
      leftLabels: leftLabels,
      rightLabels: rightLabels,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('メンバー保存しました')));
  }

  void _addMember(bool isAGroup) {
    setState(() {
      if (isAGroup) {
        aMembers.add('');
      } else {
        bMembers.add('');
      }
    });

    // メンバー追加後、ラベル数も調整
    _adjustLabelsToMembers();
  }

  void _deleteMember(int i, bool isAGroup) {
    setState(() {
      if (isAGroup) {
        aMembers.removeAt(i);
      } else {
        bMembers.removeAt(i);
      }
    });

    // メンバー削除後、ラベル数も調整
    _adjustLabelsToMembers();
  }

  void _updateMember(int i, String v, bool isAGroup) {
    setState(() {
      if (isAGroup) {
        aMembers[i] = v;
      } else {
        bMembers[i] = v;
      }
    });
  }

  void _adjustLabelsToMembers() {
    // メンバー数に合わせてラベル数を調整
    final maxMembers = aMembers.length > bMembers.length
        ? aMembers.length
        : bMembers.length;
    final currentLabels = leftLabels.length;

    if (maxMembers < currentLabels) {
      // メンバー数が少ない場合、ラベルを削除
      setState(() {
        leftLabels = leftLabels.take(maxMembers).toList();
        rightLabels = rightLabels.take(maxMembers).toList();
      });
    } else if (maxMembers > currentLabels) {
      // メンバー数が多い場合、ラベルを追加
      setState(() {
        while (leftLabels.length < maxMembers) {
          leftLabels.add('');
          rightLabels.add('');
        }
      });
    }
  }

  Widget _buildList(String title, List<String> list, bool isAGroup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        ...List.generate(list.length, (i) {
          return Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: list[i],
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                  decoration: InputDecoration(
                    labelText: '名前',
                    labelStyle: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    filled: true,
                    fillColor: Provider.of<ThemeSettings>(
                      context,
                    ).inputBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => _updateMember(i, v, isAGroup),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _deleteMember(i, isAGroup),
              ),
            ],
          );
        }),
        TextButton.icon(
          icon: Icon(Icons.add),
          label: Text('追加'),
          onPressed: () => _addMember(isAGroup),
          style: TextButton.styleFrom(
            foregroundColor: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('メンバー編集'),
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveMembers)],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildMemberCard('A班', aMembers, true),
            SizedBox(height: 16),
            _buildMemberCard('B班', bMembers, false),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(String title, List<String> list, bool isAGroup) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color:
          Provider.of<ThemeSettings>(context).backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...List.generate(list.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: list[i],
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                        ),
                        decoration: InputDecoration(
                          labelText: '名前',
                          labelStyle: TextStyle(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          filled: true,
                          fillColor: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                        ),
                        onChanged: (v) => _updateMember(i, v, isAGroup),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMember(i, isAGroup),
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
                label: Text('追加'),
                onPressed: () => _addMember(isAGroup),
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
    );
  }
}
