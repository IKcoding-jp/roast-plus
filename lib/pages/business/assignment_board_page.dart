import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/pages/business/assignment_board_controller.dart';
import 'package:roastplus/pages/business/assignment_board_view.dart';
import 'package:roastplus/utils/app_performance_config.dart'; // isDonorUser() のため

class AssignmentBoard extends StatefulWidget {
  const AssignmentBoard({super.key});

  @override
  State<AssignmentBoard> createState() => _AssignmentBoardState();
}

class _AssignmentBoardState extends State<AssignmentBoard> {
  late final AssignmentBoardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AssignmentBoardController();
    _controller.initialize(context);
  }

  Future<void> _resetTodayAssignment() async {
    await _controller.resetTodayAssignment();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssignmentBoardController>(
      create: (_) => _controller,
      child: Consumer<AssignmentBoardController>(
        builder: (context, controller, child) {
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
