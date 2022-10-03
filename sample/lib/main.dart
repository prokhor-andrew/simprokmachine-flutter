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
            Builder(
              builder: (context) => Center(child: MachineConsumer<String, int, bool>(
                initial: (context2) => ConsumerResult(state: "true", child: const Text("true"), action: () {
                  ScaffoldMessenger.of(context2).showSnackBar(const SnackBar(content: Text("WOW")));
                }),
                builder: (context, state, input, callback) {
                  if (state == "true") {
                    return ConsumerResult(state: "true", child: const Text("true"));
                  } else {
                    return ConsumerResult(state: "false", child: const Text("false"));
                  }
                },
              )),
            ),
            MaterialButton(
              onPressed: () {},
              child: const Text("click me"),
            )
          ],
        ),
      ),
    );
  }
}


