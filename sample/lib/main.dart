import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:simprokmachine/widgetmachine.dart';

void main() async {
  runRootMachine<int, bool>(
    root: RootWidgetMachine(),
    callback: (output) => log("tag: $output"),
  );
}

class RootWidgetMachine extends ChildWidgetMachine<int, bool> {
  @override
  Widget child() {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ControllerWidget<String, int, double, bool>(
              initial: () => "initial state",
              reducer: (state, event) => ControllerWidgetResult(
                "new state",
                [],
              ),
              child: Builder(
                builder: (context) => MaterialButton(
                  onPressed: () {
                    ControllerWidget.of<double, int>(context)?.forEach((element) {
                      print("element");
                    });
                  },
                  child: const Text("click me"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
