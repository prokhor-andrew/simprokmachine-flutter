//
//  simprokmachine.dart
//  simprokmachine
//
//  Created by Andrey Prokhorenko on 16.12.2021.
//  Copyright (c) 2022 simprok. All rights reserved.

library simprokmachine;

import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'functions.dart';


// API

/// A general class that describes a type that represents a machine object.
/// Exists for implementation purposes, and must not be inherited from directly.
abstract class Machine<Input, Output> {
  _Triple<Stream<Output>, Handler<Input>, ActionFunc> _setup();
}


/// An abstract class that describes a machine with a customizable handling of input,
/// and emitting of output.
abstract class ChildMachine<Input, Output> extends Machine<Input, Output> {
  /// Triggered after the subscription to the machine and every time input is received.
  /// [input] - a received input. `null` if triggered after subscription.
  /// [callback] - a callback used for emitting output.
  void process(Input? input, Handler<Output> callback);

  void dispose();

  @override
  _Triple<Stream<Output>, Handler<Input>, ActionFunc> _setup() {
    final PublishSubject<Input?> inputSubject = PublishSubject<Input?>();
    final PublishSubject<Output> outputSubject = PublishSubject<Output>();

    final Stream<Output> inStream =
        inputSubject.startWith(null).asyncExpand((Input? input) {
      const Output? nullOutput = null;
      return Stream<Input?>.value(input)
          .doOnData(
            (_) => process(input, ((output) => outputSubject.sink.add(output))),
          )
          .mapTo(nullOutput)
          .where((event) => event != null)
          .map((event) => event as Output);
    });

    final Stream<Output> outStream = outputSubject.stream;

    final Stream<Output> merged = MergeStream([
      inStream,
      outStream,
    ]);

    return _Triple(
      merged,
      (Input input) => inputSubject.sink.add(input),
      () {
        inputSubject.close();
        outputSubject.close();
        dispose();
      },
    );
  }
}

/// An abstract class that describes an intermediate machine that passes input
/// from its parent to the child, and its output from the child to the parent.
abstract class ParentMachine<Input, Output> extends Machine<Input, Output> {
  /// A child machine that receives input that comes from the parent machine, and emits output.
  Machine<Input, Output> child();

  @override
  _Triple<Stream<Output>, Handler<Input>, ActionFunc> _setup() {
    return child()._setup();
  }
}

class RootMachine<Input, Output> {
  StreamSubscription<Output>? _subscription;
  Handler<Input>? _setter;
  ActionFunc? _close;

  final Machine<Input, Output> _child;

  RootMachine(this._child);

  void start(Handler<Output> callback) {
    final _Triple<StreamSubscription<Output>, Handler<Input>, ActionFunc>
        triple = _start(_child, callback);

    _subscription = triple.first;
    _setter = triple.second;
    _close = triple.third;
  }

  void stop() {
    final close = _close;
    if (close != null) {
      close();
    }
    _subscription?.cancel();
    _subscription = null;
    _setter = null;
    _close = null;
  }

  void send(Input input) {
    final setter = _setter;
    if (setter != null) {
      setter(input);
    }
  }
}


// internal types

class _Triple<T1, T2, T3> {
  final T1 first;
  final T2 second;
  final T3 third;

  _Triple(this.first, this.second, this.third);
}

// start method
_Triple<StreamSubscription<Output>, Handler<Input>, ActionFunc>
_start<Input, Output>(
    Machine<Input, Output> machine,
    Handler<Output> callback,
    ) {
  final setup = machine._setup();
  final stream = setup.first;
  final setter = setup.second;
  final close = setup.third;

  return _Triple(stream.listen(callback), setter, close);
}

