import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/pages/business/assignment_board_controller.dart';
import 'package:roastplus/pages/business/assignment_board_view.dart';

class AssignmentBoard extends StatefulWidget {
  const AssignmentBoard({super.key});

  @override
  State<AssignmentBoard> createState() => _AssignmentBoardState();
}

class _AssignmentBoardState extends State<AssignmentBoard> {
  late final AssignmentBoardController _controller;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AssignmentBoardController();
    if (!_disposed) {
      _controller.initialize(context);
    }
  }

  Future<void> _resetTodayAssignment() async {
    // リセット処理を安全に実行
    try {
      // コントローラーが破棄されていない場合のみ実行
      if (!_disposed && !_controller.disposed) {
        await _controller.resetTodayAssignment();
      }
    } catch (e) {
      debugPrint('リセット処理エラー: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // 手動でdisposeを呼ぶが、disposedフラグで保護
    if (!_controller.disposed) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssignmentBoardController>(
      create: (_) => _controller,
      child: Consumer<AssignmentBoardController>(
        builder: (context, controller, child) {
          if (_disposed) {
            return const Center(child: Text('ページが破棄されました'));
          }
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return AssignmentBoardView(
            controller: controller,
            onReset: _resetTodayAssignment,
          );
        },
      ),
    );
  }
}
