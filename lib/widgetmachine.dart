//
//  widgetmachine.dart
//  simprokmachine
//
//  Created by Andrey Prokhorenko on 16.12.2021.
//  Copyright (c) 2022 simprok. All rights reserved.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simprokmachine/simprokmachine.dart';

import 'functions.dart';

/// A general class that describes a type that represents a machine object which
/// connects to flutter widgets. Exists for implementation purposes,
/// and must not be inherited from directly.
abstract class WidgetMachine<Input, Output> {
  Machine<Input, Output> _machine();

  Widget _widget();
}

/// An abstract class that describes a machine connected to the flutter widget.
abstract class ChildWidgetMachine<Input, Output>
    extends WidgetMachine<Input, Output> {
  final PublishSubject<_ProcessItem<Input, Output>> _uiSubject =
  PublishSubject();

  /// A method that returns a Widget object that the machine connects to.
  /// All the input is passed into widget's MachineConsumer and all the output
  /// from widget are passed to the parent of this machine.
  Widget child();

  @override
  Machine<Input, Output> _machine() {
    return _BasicMachine(processor: (input, callback) {
      _uiSubject.sink.add(_ProcessItem(
        input: input,
        callback: (output) => callback(output),
      ));
    }, dispose: () {
      _uiSubject.close();
    });
  }

  @override
  Widget _widget() {
    return StreamProvider<_ProcessItem<Input, Output>?>(
      create: (_) => _uiSubject,
      initialData: null,
      child: child(),
    );
  }
}
/// An abstract class that describes an intermediate widget machine that passes
/// input from its parent to the child, and its output from the child to the parent.
abstract class ParentWidgetMachine<Input, Output>
    extends WidgetMachine<Input, Output> {
  late final WidgetMachine<Input, Output> _wm = child();

  /// Provides a child widget machine that receives input that comes from
  /// the parent machine, and sends output.
  WidgetMachine<Input, Output> child();

  @override
  Machine<Input, Output> _machine() {
    return _wm._machine();
  }

  @override
  Widget _widget() {
    return _wm._widget();
  }
}

// widgets

/// Starts the application flow.
void runRootMachine<Input, Output>({
  required WidgetMachine<Input, Output> root,
  Handler<Output>? callback,
}) {
  runApp(
    _RootWidget(
      root._widget(),
      root._machine(),
      callback,
    ),
  );
}

/// A Consumer from provider package that receives Input and may send Output
/// via Handler<Output> callback.

class MachineConsumer<S, Input, Output> extends StatefulWidget {
  final Mapper<BuildContext, ConsumerResult<S>> _initial;
  final QuaMapper<BuildContext, S, Input?, Handler<Output>, ConsumerResult<S>>
  _builder;

  /// [initial] - a widget builder that provides UI before
  /// that first input is received.
  /// [builder] - a widget builder that processes UI every time input received.
  MachineConsumer({
    Key? key,
    required Mapper<BuildContext, ConsumerResult<S>> initial,
    required QuaMapper<BuildContext, S, Input?, Handler<Output>,
        ConsumerResult<S>>
    builder,
  })  : _initial = initial,
        _builder = builder,
        super(key: key);

  @override
  State<MachineConsumer<S, Input, Output>> createState() =>
      _MachineConsumerState<S, Input, Output>();
}

class _MachineConsumerState<S, Input, Output>
    extends State<MachineConsumer<S, Input, Output>> {
  S? _state;

  @override
  Widget build(BuildContext context) {
    return Consumer<_ProcessItem<Input, Output>?>(
      builder: (context, value, _) {
        if (value != null) {
          // normal
          return _handleConsumerResult(
            widget._builder(context, _state!, value.input, value.callback),
          );
        } else {
          // initial
          return _handleConsumerResult(
            widget._initial(context),
          );
        }
      },
    );
  }

  Widget _handleConsumerResult(ConsumerResult<S> result) {
    final ActionFunc? action = result.action;
    if (action != null) {
      action();
    }
    _state = result.state;
    return result.child;
  }
}

class ConsumerResult<State> {
  final State state;
  final Widget child;
  final ActionFunc? action;

  ConsumerResult({
    required this.state,
    required this.child,
    this.action,
  });
}

// Widget

class _RootWidget<Input, Output> extends StatefulWidget {
  final Widget _widget;
  final Machine<Input, Output> _machine;
  final Handler<Output>? _callback;

  const _RootWidget(
      this._widget,
      this._machine,
      this._callback, {
        Key? key,
      }) : super(key: key);

  @override
  _RootWidgetState<Input, Output> createState() =>
      _RootWidgetState<Input, Output>();
}

class _RootWidgetState<Input, Output>
    extends State<_RootWidget<Input, Output>> {
  RootMachine<Input, Output>? _root;

  @override
  void initState() {
    _root = RootMachine(widget._machine);
    _root?.start((output) {
      final callback = widget._callback;
      if (callback != null) {
        callback(output);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _root?.stop();
    _root = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget._widget;
  }
}

extension MapWidgetMachine<Input, Output> on WidgetMachine<Input, Output> {

  WidgetMachine<RInput, ROutput> map<RInput, ROutput>(Mapper<Machine<Input, Output>, Machine<RInput, ROutput>> mapper) {
    return _BasicWidgetMachine(_widget(), mapper(_machine()));
  }
}


// widget machines

class _ProcessItem<Input, Output> {
  final Input? input;
  final Handler<Output> callback;

  _ProcessItem({
    required this.input,
    required this.callback,
  });
}


class _BasicMachine<Input, Output> extends ChildMachine<Input, Output> {
  final BiHandler<Input?, Handler<Output>> _processor;
  final ActionFunc _dispose;

  _BasicMachine({
    required BiHandler<Input?, Handler<Output>> processor,
    required ActionFunc dispose,
  })  : _processor = processor,
        _dispose = dispose;

  @override
  void process(Input? input, Handler<Output> callback) {
    _processor(input, callback);
  }

  @override
  void dispose() {
    _dispose();
  }
}

class _BasicWidgetMachine<Input, Output> extends ChildWidgetMachine<Input, Output> {

  final Machine<Input, Output> _m;
  final Widget _child;

  _BasicWidgetMachine(this._child, this._m);

  @override
  Machine<Input, Output> _machine() {
    return _m;
  }

  @override
  Widget child() {
    return _child;
  }
}
