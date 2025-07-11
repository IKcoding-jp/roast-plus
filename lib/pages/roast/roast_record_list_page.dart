import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class RoastRecordListPage extends StatefulWidget {
  const RoastRecordListPage({super.key});

  @override
  State<RoastRecordListPage> createState() => _RoastRecordListPageState();
}

class _RoastRecordListPageState extends State<RoastRecordListPage> {
  List<Map<String, dynamic>> _records = [];
  final Set<int> _selectedIndexes = {};
  bool _selectionMode = false;

  // 検索・フィルター用の状態
  String _searchKeyword = '';
  String? _selectedBean;
  String? _selectedRoast;
  DateTime? _startDate;
  DateTime? _endDate;

  // 豆リスト仮（本来はデータから動的取得）
  final List<String> _beanList = ['全て', 'ブラジル', 'コロンビア', 'エチオピア', 'ペルー'];

  // 煎り度リスト仮
  final List<String> _roastList = ['全て', '浅煎り', '中煎り', '中深煎り', '深煎り'];

  // フィルター適用済みリストを返す
  List<Map<String, dynamic>> _getFilteredRecords() {
    if (_records.isEmpty) return [];

    return _records.where((record) {
      try {
        // 検索キーワード
        if (_searchKeyword.isNotEmpty) {
          final keyword = _searchKeyword.toLowerCase();
          final bean = (record['bean'] ?? '').toString().toLowerCase();
          final weight = (record['weight'] ?? '').toString().toLowerCase();
          final time = (record['time'] ?? '').toString().toLowerCase();
          final roast = (record['roast'] ?? '').toString().toLowerCase();
          if (!bean.contains(keyword) &&
              !weight.contains(keyword) &&
              !time.contains(keyword) &&
              !roast.contains(keyword)) {
            return false;
          }
        }
        // 豆フィルター
        if (_selectedBean != null &&
            _selectedBean != '全て' &&
            record['bean'] != _selectedBean) {
          return false;
        }
        // 煎り度フィルター
        if (_selectedRoast != null &&
            _selectedRoast != '全て' &&
            record['roast'] != _selectedRoast) {
          return false;
        }
        // 日付範囲フィルター
        if (_startDate != null || _endDate != null) {
          final timestamp = record['timestamp'] ?? '';
          if (timestamp.isEmpty) return false;
          final date = DateTime.tryParse(timestamp);
          if (date == null) return false;
          if (_startDate != null && date.isBefore(_startDate!)) return false;
          if (_endDate != null && date.isAfter(_endDate!)) return false;
        }
        return true;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('roastRecords');
    if (saved != null) {
      final List<dynamic> jsonList = json.decode(saved);
      setState(() {
        _records = jsonList.map((e) => Map<String, dynamic>.from(e)).toList()
          ..sort(
            (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
          );
      });
    } else {
      setState(() {
        _records = [];
      });
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('roastRecords', json.encode(_records));
  }

  Future<void> _moveToTrash(List<int> indexes) async {
    final prefs = await SharedPreferences.getInstance();
    final trashed = prefs.getStringList('trashedRecords') ?? [];
    final toRemove = indexes.map((i) => _records[i]).toList();
    trashed.addAll(toRemove.map((e) => json.encode(e)));
    prefs.setStringList('trashedRecords', trashed);

    setState(() {
      indexes.toList()
        ..sort((a, b) => b.compareTo(a))
        ..forEach((i) => _records.removeAt(i));
      _selectedIndexes.clear();
      _selectionMode = false;
    });
    _saveRecords();
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);
    if (dateTime == null) return '';
    return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _getFilteredRecords();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.list, color: Color(0xFF795548)),
            SizedBox(width: 8),
            Text('焙煎記録一覧'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.select_all),
            onPressed: _toggleSelectionMode,
          ),
          if (_selectionMode && _selectedIndexes.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _moveToTrash(_selectedIndexes.toList()),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
          ),
        ),
        child: Column(
          children: [
            // 検索・フィルターカード
            Card(
              margin: EdgeInsets.all(16),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Color(0xFFFFF8E1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル部分
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF795548),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '検索・フィルター',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C1D17),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // 検索バー
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF795548).withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'キーワード検索',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF795548),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchKeyword = v),
                      ),
                    ),
                    SizedBox(height: 16),

                    // フィルター行
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedBean ?? '全て',
                            items: _beanList,
                            label: '豆の種類',
                            onChanged: (v) => setState(() => _selectedBean = v),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _selectedRoast ?? '全て',
                            items: _roastList,
                            label: '煎り度',
                            onChanged: (v) =>
                                setState(() => _selectedRoast = v),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // 日付フィルター
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: '開始日',
                            date: _startDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '~',
                          style: TextStyle(
                            color: Color(0xFF795548),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDatePicker(
                            label: '終了日',
                            date: _endDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // リセットボタン
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('リセット'),
                        onPressed: () {
                          setState(() {
                            _searchKeyword = '';
                            _selectedBean = null;
                            _selectedRoast = null;
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF795548),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 記録リスト
            Expanded(
              child: _records.isEmpty
                  ? Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Color(0xFFFFF8E1),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.list,
                                size: 64,
                                color: Color(0xFF795548),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '記録がありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C1D17),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '焙煎記録を入力してからご利用ください',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : filteredRecords.isEmpty
                  ? Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Color(0xFF795548),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '条件に合う記録がありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C1D17),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '検索条件を変更してください',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final selected = _selectedIndexes.contains(index);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: selected
                                ? Color(0xFF795548).withOpacity(0.1)
                                : Color(0xFFFFF8E1),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF795548).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.coffee,
                                  color: Color(0xFF795548),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                '${record['bean']}（${record['weight']}g）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C1D17),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 16,
                                        color: Color(0xFF795548),
                                      ),
                                      SizedBox(width: 4),
                                      Text('焙煎時間: ${record['time']}'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        size: 16,
                                        color: Color(0xFF795548),
                                      ),
                                      SizedBox(width: 4),
                                      Text('煎り度: ${record['roast']}'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Color(0xFF795548),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '記録日時: ${_formatTimestamp(record['timestamp'] ?? '')}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: !_selectionMode
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Color(0xFF795548),
                                      ),
                                      onPressed: () => _moveToTrash([index]),
                                    )
                                  : Checkbox(
                                      value: selected,
                                      onChanged: (val) =>
                                          _toggleSelection(index),
                                      activeColor: Color(0xFF795548),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          labelStyle: TextStyle(color: Color(0xFF795548)),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF795548),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              date != null ? DateFormat('yyyy/MM/dd').format(date) : '',
              style: TextStyle(
                fontSize: 14,
                color: date != null ? Color(0xFF2C1D17) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
