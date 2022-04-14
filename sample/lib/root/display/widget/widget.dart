import 'package:flutter/material.dart';
import 'package:sample/utils/void_event.dart';
import 'package:simprokmachine/simprokmachine.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Counter app'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            MachineConsumer<String, VoidEvent>(
              initial: (BuildContext context) => Text(
                "initial",
                style: Theme.of(context).textTheme.headline4,
              ),
              builder: (BuildContext context, String? msg,
                  Handler<VoidEvent> callback) {
                return Text(
                  msg ?? "loading",
                  style: Theme.of(context).textTheme.headline4,
                );
              },
            )
          ],
        ),
      ),
      floatingActionButton: MachineConsumer<String, VoidEvent>(
        initial: (_) => const Text(""),
        builder:
            (BuildContext context, String? msg, Handler<VoidEvent> callback) =>
                FloatingActionButton(
          onPressed: () => callback(VoidEvent()),
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
