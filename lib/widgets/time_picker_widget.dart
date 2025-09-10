import 'package:flutter/material.dart';
import '../utils/web_ui_utils.dart';

class TimePickerWidget extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeChanged;

  const TimePickerWidget({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  State<TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebUIUtils.isWeb ? _buildWebLayout() : _buildMobileLayout();
  }

  Widget _buildWebLayout() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // 時間選択
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedHour,
              decoration: InputDecoration(
                labelText: '時',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: List.generate(24, (index) {
                return DropdownMenuItem<int>(
                  value: index,
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedHour = value;
                  });
                  widget.onTimeChanged(
                    TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                  );
                }
              },
            ),
          ),
          SizedBox(width: 16),
          // 分選択
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedMinute,
              decoration: InputDecoration(
                labelText: '分',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: List.generate(60, (index) {
                return DropdownMenuItem<int>(
                  value: index,
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMinute = value;
                  });
                  widget.onTimeChanged(
                    TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 時間選択
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '時',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 40,
                    physics: FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedHour = index;
                      });
                      widget.onTimeChanged(
                        TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                      );
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: index == _selectedHour
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                      childCount: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 区切り文字
          Container(width: 1, height: double.infinity, color: Colors.grey[300]),

          // 分選択
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '分',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 40,
                    physics: FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinute = index;
                      });
                      widget.onTimeChanged(
                        TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                      );
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: index == _selectedMinute
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                      childCount: 60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
