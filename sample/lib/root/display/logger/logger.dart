import 'dart:developer';

import 'package:simprokmachine/simprokmachine.dart';


class Logger extends ChildMachine<String, void> {
  @override
  void process(String? input, Handler<void> callback) {
    log(input ?? "loading");
  }
}
