import 'package:flutter/material.dart';

class RoastScheduleBean {
  String name;
  int weight;
  int? bags;
  String? roastLevel;
  RoastScheduleBean({
    required this.name,
    required this.weight,
    this.bags,
    this.roastLevel,
  });

  factory RoastScheduleBean.fromJson(Map<String, dynamic> json) {
    return RoastScheduleBean(
      name: json['name'] ?? '',
      weight: json['weight'] ?? 0,
      bags: json['bags'],
      roastLevel: json['roastLevel'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'weight': weight,
    'bags': bags,
    'roastLevel': roastLevel,
  };
}

class RoastScheduleFormProvider extends ChangeNotifier {
  List<RoastScheduleBean> _beans = [];

  List<RoastScheduleBean> get beans => _beans;
  set beans(List<RoastScheduleBean> value) {
    _beans = value;
    notifyListeners();
  }

  void setBeans(List<RoastScheduleBean> beans) {
    _beans = beans;
    notifyListeners();
  }

  void addBean(RoastScheduleBean bean) {
    _beans.add(bean);
    notifyListeners();
  }

  void updateBean(int index, RoastScheduleBean bean) {
    if (index >= 0 && index < _beans.length) {
      _beans[index] = bean;
      notifyListeners();
    }
  }

  void removeBean(int index) {
    if (index >= 0 && index < _beans.length) {
      _beans.removeAt(index);
      notifyListeners();
    }
  }

  void clearBeans() {
    _beans.clear();
    notifyListeners();
  }
}
