//
//  widgetmachine.dart
//  simprokmachine
//
//  Created by Andrey Prokhorenko on 16.12.2021.
//  Copyright (c) 2022 simprok. All rights reserved.

library simprokmachine;

import 'package:flutter/material.dart';
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
  final PublishSubject<ProcessItem<Input, Output>> _uiSubject =
  PublishSubject();

  /// A method that returns a Widget object that the machine connects to.
  /// All the input is passed into widget's MachineConsumer and all the output
  /// from widget are passed to the parent of this machine.
  Widget child();

  @override
  Machine<Input, Output> _machine() => _SubjectProduceMachine(_uiSubject);

  @override
  Widget _widget() =>
      _SubjectConsumerWidget(
        child: child(),
        stream: _uiSubject,
      );
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

/// An operator that allows to transform an internal machine in any way
extension MapWidgetMachine<Input, Output> on WidgetMachine<Input, Output> {
  WidgetMachine<RInput, ROutput> map<RInput, ROutput>(
      Mapper<Machine<Input, Output>, Machine<RInput, ROutput>> mapper) {
    return _BasicWidgetMachine(_widget(), mapper(_machine()));
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

// Implementation
class _RootWidget<Input, Output> extends StatefulWidget {
  final Widget _widget;
  final Machine<Input, Output> _machine;
  final Handler<Output>? _callback;

  const _RootWidget(this._widget,
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

class ProcessItem<Input, Output> {
  final Input? input;
  final Handler<Output> callback;

  ProcessItem({
    required this.input,
    required this.callback,
  });
}

class _SubjectConsumerWidget<Input, Output> extends InheritedWidget {
  final Stream<ProcessItem<Input, Output>>? stream;

  _SubjectConsumerWidget({
    required Widget child,
    required this.stream,
  }) : super(child: child);

  static Stream<ProcessItem<Input, Output>>? of<Input, Output>(
      BuildContext context,) {
    return context
        .dependOnInheritedWidgetOfExactType<
        _SubjectConsumerWidget<Input, Output>>()
        ?.stream;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class _SubjectProduceMachine<Input, Output>
    extends ChildMachine<Input, Output> {
  final PublishSubject<ProcessItem<Input, Output>> pipe;

  _SubjectProduceMachine(this.pipe);

  @override
  void process(Input? input, Handler<Output> callback) {
    pipe.sink.add(ProcessItem(input: input, callback: callback));
  }

  @override
  void dispose() {
    pipe.close();
  }
}

class _BasicWidgetMachine<Input, Output>
    extends ChildWidgetMachine<Input, Output> {
  final Machine<Input, Output> _m;
  final Widget _c;

  _BasicWidgetMachine(this._c, this._m);

  @override
  Machine<Input, Output> _machine() {
    return _m;
  }

  @override
  Widget child() {
    return _c;
  }
}

class ControllerOutput<Internal, External> {
  final Internal? int;
  final External? ext;

  ControllerOutput.internal(Internal data)
      : int = data,
        ext = null;

  ControllerOutput.external(External data)
      : ext = data,
        int = null;
}

class ControllerWidgetResult<State, Internal, External> {
  final State state;
  final List<ControllerOutput<Internal, External>> outputs;

  ControllerWidgetResult(this.state, this.outputs);
}

class ControllerWidget<S, Event, Internal, External> extends StatefulWidget {
  final Widget child;
  final Supplier<S> initial;
  final BiMapper<S, Event, ControllerWidgetResult<S, Internal, External>>
  reducer;

  const ControllerWidget({
    Key? key,
    required this.initial,
    required this.reducer,
    required this.child,
  }) : super(key: key);

  @override
  State<ControllerWidget<S, Event, Internal, External>> createState() =>
      _ControllerWidgetState<S, Event, Internal, External>();


  static Stream<ProcessItem<Input, Output>>? of<Input, Output>(
      BuildContext context) {
    return _SubjectConsumerWidget.of<Input, Output>(context);
  }
}

extension ControllerWidgetStream<Input, Output> on BuildContext {

  Stream<ProcessItem<Input, Output>>? machine() =>
      ControllerWidget.of<Input, Output>(this);
}

class _ControllerWidgetState<S, Event, Internal, External>
    extends State<ControllerWidget<S, Event, Internal, External>> {
  final PublishSubject<ProcessItem<Event, External>> _internalSubject =
  PublishSubject();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _internalSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _externalSubject = _SubjectConsumerWidget.of<Event, External>(
      context,
    );

    final Stream<ProcessItem<Internal, Event>>? stream;

    if (_externalSubject == null) {
      stream = null;
    } else {
      stream = MergeStream([
        _externalSubject,
        _internalSubject,
      ])
          .scan<
          _Triple<S,
              Handler<External>,
              List<ControllerOutput<Internal, External>>?>?>(
            (acc, event, _) {
          if (event.input == null) {
            return _Triple(widget.initial(), event.callback, null);
          } else {
            final result = widget.reducer(acc!.first, event.input!);
            final newState = result.state;
            final outputs = result.outputs;

            return _Triple(newState, acc.second, outputs);
          }
        },
        null,
      )
          .map((event) => event!)
          .doOnData((event) {
        final callback = event.second;
        final outputs = event.third;

        if (outputs != null) {
          for (final element in outputs) {
            final ext = element.ext;
            if (ext != null) {
              callback(ext);
            }
          }
        }
      })
          .asyncExpand(
            (event) {
          void callback(Event event) {
            _internalSubject.sink.add(
              ProcessItem(
                input: event,
                callback: (_) {},
              ),
            );
          }

          if (event.third == null) {
            return Stream.value(
              ProcessItem<Internal, Event>(
                input: null,
                callback: callback,
              ),
            );
          } else {
            return Stream.fromIterable(
              event.third!.where((element) => element.int != null).map(
                    (e) =>
                    ProcessItem<Internal, Event>(
                      input: e.int,
                      callback: callback,
                    ),
              ),
            );
          }
        },
      );
    }

    return _SubjectConsumerWidget<Event, External>(
      stream: null,
      child: _SubjectConsumerWidget<Internal, Event>(
        stream: stream,
        child: widget.child,
      ),
    );
  }
}

class _Triple<T1, T2, T3> {
  final T1 first;
  final T2 second;
  final T3 third;

  _Triple(this.first, this.second, this.third);
}
