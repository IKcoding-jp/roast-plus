import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../services/user_settings_firestore_service.dart';

class DripPackRecordListPage extends StatefulWidget {
  const DripPackRecordListPage({super.key});

  @override
  State<DripPackRecordListPage> createState() => _DripPackRecordListPageState();
}

class _DripPackRecordListPageState extends State<DripPackRecordListPage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _currentGroupId;

  // 削除処理を追加
  Future<void> _deleteRecord(int index) async {
    setState(() {
      _records.removeAt(index);
    });
    await UserSettingsFirestoreService.saveSetting('dripPackRecords', _records);
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkGroupChange();
  }

  /// グループ変更をチェックして、必要に応じてデータをクリア
  void _checkGroupChange() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroupId = groupProvider.hasGroup
        ? groupProvider.currentGroup!.id
        : null;

    // グループが変更された場合、データをクリア
    if (_currentGroupId != null && _currentGroupId != currentGroupId) {
      setState(() {
        _records = [];
        _isLoading = false;
      });
      _clearLocalRecords();
    }

    _currentGroupId = currentGroupId;
  }

  /// ローカル記録をクリア
  Future<void> _clearLocalRecords() async {
    await UserSettingsFirestoreService.deleteSetting('dripPackRecords');
  }

  Future<void> _loadRecords() async {
    final saved = await UserSettingsFirestoreService.getSetting(
      'dripPackRecords',
    );
    if (saved != null) {
      setState(() {
        _records = List<Map<String, dynamic>>.from(saved);
        _isLoading = false;
      });
    } else {
      setState(() {
        _records = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('ドリップパック記録一覧'),
            const SizedBox(width: 8),
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  return Container(
                    margin: EdgeInsets.only(left: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade400),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee, size: 64, color: themeSettings.iconColor),
                  SizedBox(height: 16),
                  Text(
                    '記録がありません',
                    style: TextStyle(
                      fontSize: 18 * themeSettings.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '新しい記録を追加してください',
                    style: TextStyle(
                      color: themeSettings.fontColor1.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                final date =
                    DateTime.tryParse(record['timestamp'] ?? '') ??
                    DateTime.now();
                final formattedDate = DateFormat(
                  'yyyy/MM/dd HH:mm',
                ).format(date);
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: themeSettings.backgroundColor2,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeSettings.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.coffee,
                        color: themeSettings.iconColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      '${record['bean'] ?? ''}・${record['roast'] ?? ''}・${record['count'] ?? 0}袋',
                      style: TextStyle(
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          12.0,
                          24.0,
                        ),
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record['memo'] != null &&
                            record['memo'].toString().isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            record['memo'].toString(),
                            style: TextStyle(
                              fontSize: 14 * themeSettings.fontSizeScale,
                              color: themeSettings.fontColor1.withOpacity(0.8),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: 8),
                        Text(
                          '記録日時: $formattedDate',
                          style: TextStyle(
                            fontSize: 12 * themeSettings.fontSizeScale,
                            color: themeSettings.fontColor1.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      tooltip: '削除',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('削除の確認'),
                            content: Text('この記録を削除しますか？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  '削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _deleteRecord(index);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
