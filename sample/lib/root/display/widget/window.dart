import 'package:flutter/material.dart';
import 'package:sample/root/display/widget/widget.dart';
import 'package:sample/utils/void_event.dart';
import 'package:simprokmachine/simprokmachine.dart';


class Window extends ChildWidgetMachine<String, VoidEvent> {
  @override
  Widget child() {
    return const MyApp();
  }
}
