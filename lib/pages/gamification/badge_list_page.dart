import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/pages/gamification/badge_list_controller.dart';
import 'package:roastplus/pages/gamification/badge_list_view.dart';

class BadgeListPage extends StatefulWidget {
  const BadgeListPage({super.key});

  @override
  State<BadgeListPage> createState() => _BadgeListPageState();
}

class _BadgeListPageState extends State<BadgeListPage>
    with TickerProviderStateMixin {
  late final BadgeListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BadgeListController();
    _controller.initialize(this, context); // TickerProviderとBuildContextを渡す
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.didChangeDependencies(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BadgeListController>(
      create: (_) => _controller,
      child: Consumer<BadgeListController>(
        builder: (context, controller, child) {
          return BadgeListView(controller: controller);
        },
      ),
    );
  }
}
