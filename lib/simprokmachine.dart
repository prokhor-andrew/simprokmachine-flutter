//
//  simprokmachine.dart
//  simprokmachine
//
//  Created by Andrey Prokhorenko on 16.12.2021.
//  Copyright (c) 2022 simprok. All rights reserved.

library simprokmachine;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';


// extensions

extension _MapCopyAdd<Key, Value> on Map<Key, Value> {
  Map<Key, Value> copyAdd(Key key, Value value) {
    final Map<Key, Value> copied = map((key, value) => MapEntry(key, value));
    copied[key] = value;
    return copied;
  }
}

// internal types
class _MachineSetup<Input, Output> {
  final Stream<Output> stream;
  final Handler<Input> setter;

  _MachineSetup(this.stream, this.setter);
}

class _EmitterInput<T> {
  final T value;

  _EmitterInput(this.value);
}

class _EmitterOutput<Input, Output> {
  final Input? _input;
  final Output? _output;

  _EmitterOutput.toConnected(Input input)
      : _input = input,
        _output = null;

  _EmitterOutput.fromConnected(Output output)
      : _input = null,
        _output = output;
}

class _EmitterMachine<Input, Output>
    extends ChildMachine<_EmitterInput<Input>, _EmitterOutput<Input, Output>> {
  Handler<_EmitterOutput<Input, Output>>? _callback;

  void send(Input input) {
    final callback = _callback;
    if (callback != null) {
      callback(_EmitterOutput.toConnected(input));
    }
  }

  @override
  void process(
      _EmitterInput<Input>? input,
      Handler<_EmitterOutput<Input, Output>> callback,
      ) {
    _callback = callback;
  }
}

class _ConnectablePair<Input, Output> {
  final StreamSubscription<Output> subscription;
  final _EmitterMachine<Input, Output> emitter;

  _ConnectablePair(this.subscription, this.emitter);
}

class _ProcessItem<Input, Output> {
  final Input? input;
  final Handler<Output> callback;

  _ProcessItem({
    required this.input,
    required this.callback,
  });
}

// machines

class _RedirectMachine<Input, Output> extends Machine<Input, Output> {
  final _MachineSetup<Input, Output> setup;

  _RedirectMachine(this.setup);

  @override
  _MachineSetup<Input, Output> _setup() {
    return setup;
  }

  static _RedirectMachine<Input, Output> create<Input, Output>(
    Machine<Input, Output> child,
    Mapper<Output, Direction<Input>> mapper,
  ) {
    final setup = child._setup();
    final setter = setup.setter;
    final Stream<Output> stream = setup.stream
        .map((Output output) {
          final Output? result;
          final mapped = mapper(output)._ward;
          if (mapped != null) {
            // back
            for (var element in mapped.values) {
              setter(element);
            }
            result = null;
          } else {
            // prop
            result = output;
          }

          return result;
        })
        .where((event) => event != null)
        .map((event) => event!);

    return _RedirectMachine<Input, Output>(
      _MachineSetup<Input, Output>(
        stream,
        setter,
      ),
    );
  }
}

class _InwardMachine<Input, Output> extends Machine<Input, Output> {
  final _MachineSetup<Input, Output> setup;

  _InwardMachine(this.setup);

  @override
  _MachineSetup<Input, Output> _setup() {
    return setup;
  }

  static _InwardMachine<ParentInput, ChildOutput>
      create<ParentInput, ChildInput, ChildOutput>(
    Machine<ChildInput, ChildOutput> child,
    Mapper<ParentInput, Ward<ChildInput>> mapper,
  ) {
    final setup = child._setup();
    final stream = setup.stream;
    final setter = setup.setter;

    return _InwardMachine<ParentInput, ChildOutput>(
        _MachineSetup(stream, (ParentInput input) {
      final List<ChildInput> mapped = mapper(input).values;
      for (var element in mapped) {
        setter(element);
      }
    }));
  }
}

class _OutwardMachine<Input, Output> extends Machine<Input, Output> {
  final _MachineSetup<Input, Output> setup;

  _OutwardMachine(this.setup);

  @override
  _MachineSetup<Input, Output> _setup() {
    return setup;
  }

  static _OutwardMachine<ChildInput, ParentOutput>
      create<ParentOutput, ChildInput, ChildOutput>(
    Machine<ChildInput, ChildOutput> child,
    Mapper<ChildOutput, Ward<ParentOutput>> mapper,
  ) {
    final setup = child._setup();
    final setter = setup.setter;
    final stream = setup.stream.asyncExpand((ChildOutput event) {
      return Stream.fromIterable(mapper(event).values);
    });

    return _OutwardMachine<ChildInput, ParentOutput>(
      _MachineSetup(stream, setter),
    );
  }
}

class _MergeMachine<Input, Output> extends Machine<Input, Output> {
  final Set<Machine<Input, Output>> _machines;

  _MergeMachine(Set<Machine<Input, Output>> machines)
      : _machines = Set<Machine<Input, Output>>.from(machines);

  @override
  _MachineSetup<Input, Output> _setup() {
    return _machines.fold(
      _MachineSetup(const Stream.empty(), (_) {}),
      (acc, element) {
        final setup = element._setup();
        final stream = setup.stream;
        final setter = setup.setter;

        final Stream<Output> mergedStream = acc.stream.mergeWith([stream]);
        final Handler<Input> mergedSetter = ((Input input) {
          acc.setter(input);
          setter(input);
        });
        return _MachineSetup(mergedStream, mergedSetter);
      },
    );
  }
}

// widget machines

class _RedirectWidgetMachine<Input, Output>
    extends WidgetMachine<Input, Output> {
  final Widget _childWidget;
  final Machine<Input, Output> _childMachine;

  _RedirectWidgetMachine._(
    Widget childWidget,
    Machine<Input, Output> childMachine,
  )   : _childWidget = childWidget,
        _childMachine = childMachine;

  @override
  Machine<Input, Output> _machine() {
    return _childMachine;
  }

  @override
  Widget _widget() {
    return _childWidget;
  }

  static _RedirectWidgetMachine<Input, Output> create<Input, Output>(
    WidgetMachine<Input, Output> child,
    Mapper<Output, Direction<Input>> mapper,
  ) {
    return _RedirectWidgetMachine._(
      child._widget(),
      child._machine().redirect(mapper),
    );
  }
}

class _InwardWidgetMachine<Input, Output> extends WidgetMachine<Input, Output> {
  final Widget _childWidget;
  final Machine<Input, Output> _childMachine;

  _InwardWidgetMachine._(
    Widget childWidget,
    Machine<Input, Output> childMachine,
  )   : _childWidget = childWidget,
        _childMachine = childMachine;

  static _InwardWidgetMachine<ParentInput, ChildOutput>
      create<ParentInput, ChildInput, ChildOutput>(
    WidgetMachine<ChildInput, ChildOutput> child,
    Mapper<ParentInput, Ward<ChildInput>> mapper,
  ) {
    return _InwardWidgetMachine._(
      child._widget(),
      child._machine().inward(mapper),
    );
  }

  @override
  Machine<Input, Output> _machine() {
    return _childMachine;
  }

  @override
  Widget _widget() {
    return _childWidget;
  }
}

class _OutwardWidgetMachine<Input, Output>
    extends WidgetMachine<Input, Output> {
  final Widget _childWidget;
  final Machine<Input, Output> _childMachine;

  _OutwardWidgetMachine._(
    Widget childWidget,
    Machine<Input, Output> childMachine,
  )   : _childWidget = childWidget,
        _childMachine = childMachine;

  static _OutwardWidgetMachine<ChildInput, ParentOutput>
      create<ParentOutput, ChildInput, ChildOutput>(
    WidgetMachine<ChildInput, ChildOutput> child,
    Mapper<ChildOutput, Ward<ParentOutput>> mapper,
  ) {
    return _OutwardWidgetMachine._(
      child._widget(),
      child._machine().outward(mapper),
    );
  }

  @override
  Machine<Input, Output> _machine() {
    return _childMachine;
  }

  @override
  Widget _widget() {
    return _childWidget;
  }
}

class _MergeWidgetMachine<Input, Output> extends WidgetMachine<Input, Output> {
  final WidgetMachine<Input, Output> _main;
  final Set<Machine<Input, Output>> _secondary;

  _MergeWidgetMachine({
    required WidgetMachine<Input, Output> main,
    required Set<Machine<Input, Output>> secondary,
  })  : _main = main,
        _secondary = Set<Machine<Input, Output>>.from(secondary);

  @override
  Machine<Input, Output> _machine() {
    _secondary.add(_main._machine());
    return _MergeMachine(_secondary);
  }

  @override
  Widget _widget() {
    return _main._widget();
  }
}

// start method

StreamSubscription<Output> _start<Input, Output>(
    Machine<Input, Output> machine) {
  final setup = machine._setup();
  final stream = setup.stream;

  return stream.listen((Output event) {});
}

// Widget

class _RootWidget<Input, Output> extends StatefulWidget {
  final Widget _widget;
  final Machine<Input, Output> _machine;

  const _RootWidget(
    this._widget,
    this._machine, {
    Key? key,
  }) : super(key: key);

  @override
  _RootWidgetState<Input, Output> createState() =>
      _RootWidgetState<Input, Output>();
}

class _RootWidgetState<Input, Output>
    extends State<_RootWidget<Input, Output>> {
  StreamSubscription<Output>? subscription;

  @override
  void initState() {
    subscription = _start<Input, Output>(widget._machine);

    super.initState();
  }

  @override
  void dispose() {
    subscription?.cancel();
    subscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget._widget;
  }
}

// API

// functions
typedef Handler<T> = void Function(T);
typedef BiHandler<T1, T2> = void Function(T1, T2);
typedef TriHandler<T1, T2, T3> = void Function(T1, T2, T3);

typedef Mapper<I, O> = O Function(I);
typedef BiMapper<T1, T2, R> = R Function(T1, T2);
typedef TriMapper<T1, T2, T3, R> = R Function(T1, T2, T3);

typedef Supplier<T> = T Function();

// machines

/// A general class that describes a type that represents a machine object.
/// Exists for implementation purposes, and must not be inherited from directly.
abstract class Machine<Input, Output> {
  _MachineSetup<Input, Output> _setup();
}

/// An abstract class that describes a machine with a customizable handling of input,
/// and emitting of output.
abstract class ChildMachine<Input, Output> extends Machine<Input, Output> {

  /// Triggered after the subscription to the machine and every time input is received.
  /// [input] - a received input. `null` if triggered after subscription.
  /// [callback] - a callback used for emitting output.
  void process(Input? input, Handler<Output> callback);

  @override
  _MachineSetup<Input, Output> _setup() {
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

    return _MachineSetup(
      merged,
      (Input input) => inputSubject.sink.add(input),
    );
  }
}

/// An abstract class that describes an intermediate machine that passes input
/// from its parent to the child, and its output from the child to the parent.
abstract class ParentMachine<Input, Output> extends Machine<Input, Output> {

  /// A child machine that receives input that comes from the parent machine, and emits output.
  Machine<Input, Output> child();

  @override
  _MachineSetup<Input, Output> _setup() {
    return child()._setup();
  }
}

/// A class that describes a machine with an injectable processing behavior.
class BasicMachine<Input, Output> extends ChildMachine<Input, Output> {
  final BiHandler<Input?, Handler<Output>> _processor;

  /// parameter [processor] - triggered when `process()` method is triggered.
  BasicMachine({
    required BiHandler<Input?, Handler<Output>> processor,
  }) : _processor = processor;

  /// `ChildMachine` abstract method
  @override
  void process(Input? input, Handler<Output> callback) {
    _processor(input, callback);
  }
}

/// A class that describes a machine with an injectable processing behavior over
/// the injected object. Exists for convenience.
class ProcessMachine<Input, Output> extends ChildMachine<Input, Output> {
  final BiHandler<Input?, Handler<Output>> processor;

  ProcessMachine._(this.processor);

  /// parameter [object] - object that is passed into
  /// the injected `processor()` function.
  /// parameter [processor] - triggered when `process()` method is triggered
  /// with an injected `object` passed in as the first parameter.
  static ProcessMachine<Input, Output> create<O, Input, Output>({
    required O object,
    required TriHandler<O, Input?, Handler<Output>> processor,
  }) {
    return ProcessMachine._(
      (input, callback) => processor(object, input, callback),
    );
  }

  /// `ChildMachine` abstract method
  @override
  void process(Input? input, Handler<Output> callback) {
    processor(input, callback);
  }
}

/// An object that represents state in `ConnectableMachine`'s reducer
abstract class Connection<Input, Output> {
  /// Machines that are connected in `ConnectableMachine`.
  Set<Machine<Input, Output>> machines();
}

/// Basic implementation of `Connection` class
class BasicConnection<Input, Output> extends Connection<Input, Output> {
  /// `Connection` class property
  final Set<Machine<Input, Output>> set;

  BasicConnection(this.set);

  /// `Connection` class method
  @override
  Set<Machine<Input, Output>> machines() {
    return set;
  }
}

/// A type that represents a behavior of `ConnectableMachine`
class ConnectionType<Input, Output, C extends Connection<Input, Output>> {
  final C? _connection;

  /// Returning this value from `ConnectableMachine`'s `reducer` method
  /// ensures that `machines` specified in the object of `C extends Connection`
  /// type will be connected and all of them will receive subscription event.
  ConnectionType.reduce(C connection) : _connection = connection;

  /// Returning this value from `ConnectableMachine`'s `reducer` method ensures
  /// that `machines` currently being connected will receive an input
  /// object of `(C extends Connection).Input` type.
  ConnectionType.inward() : _connection = null;
}

/// The machine for dynamic creation and connection of other machines
class ConnectableMachine<Input, Output, C extends Connection<Input, Output>>
    extends ChildMachine<Input, Output> {
  Map<int, _ConnectablePair<Input, Output>> _map = {};
  C _state;
  final BiMapper<C, Input, ConnectionType<Input, Output, C>> _reducer;

  ConnectableMachine._(this._state, this._reducer);

  /// `ChildMachine` class method
  @override
  void process(Input? input, Handler<Output> callback) {
    if (input != null) {
      final connection = _reducer(_state, input)._connection;
      if (connection != null) {
        // reduce
        _state = connection;
        _connect(callback);
      } else {
        // inward
        _send(input);
      }
    } else {
      _connect(callback);
    }
  }

  void _connect(Handler<Output> callback) {
    _map = _state.machines().fold({}, (cur, machine) {
      final int id = machine.hashCode;
      if (cur[id] != null) {
        return cur;
      } else {
        final item = _map[id];
        if (item != null) {
          return cur.copyAdd(id, item);
        } else {
          final _EmitterMachine<Input, Output> emitter = _EmitterMachine();

          final Machine<Input, _EmitterOutput<Input, Output>> m0 =
              machine.outward((Output output) {
            return Ward.single(
              _EmitterOutput<Input, Output>.fromConnected(output),
            );
          });

          final Machine<_EmitterInput<Input>, _EmitterOutput<Input, Output>>
              m1 = m0.inward((_EmitterInput<Input> input) {
            return Ward.single(input.value);
          });

          final Machine<_EmitterInput<Input>, _EmitterOutput<Input, Output>>
              merged = merge({emitter, m1});

          final Machine<_EmitterInput<Input>, _EmitterOutput<Input, Output>>
              merged1 = merged.redirect((_EmitterOutput<Input, Output> output) {
            final input = output._input;
            if (input != null) {
              return Direction<_EmitterInput<Input>>.back(
                Ward<_EmitterInput<Input>>.single(
                  _EmitterInput<Input>(input),
                ),
              );
            } else {
              return Direction<_EmitterInput<Input>>.prop();
            }
          });

          final Machine<_EmitterInput<Input>, Output> merged2 =
              merged1.outward((_EmitterOutput<Input, Output> item) {
            final output = item._output;
            if (output != null) {
              return Ward<Output>.single(output);
            } else {
              return Ward<Output>.ignore();
            }
          });

          final StreamSubscription<Output> subscription =
              merged2._setup().stream.listen(callback);

          return cur.copyAdd(id, _ConnectablePair(subscription, emitter));
        }
      }
    });
  }

  void _send(Input input) {
    _map.forEach((_, value) {
      value.emitter.send(input);
    });
  }

  /// parameter [initial] - initial state. After subscription to the
  /// `ConnectableMachine` all the `machines` in `initial` object will be
  /// connected and subscribed to.
  /// parameter [reducer] - reducer method that is triggered every time input
  /// is received by `ConnectableMachine`.
  /// Accepts current state, incoming input and returns an object of
  /// `ConnectionType<C>` type.
  /// Either new `machines` are connected to the `ConnectableMachine` or
  /// current `machines` receive input, depending on the returned value.
  static ConnectableMachine<Input, Output, C>
      create<Input, Output, C extends Connection<Input, Output>>(
    C initial,
    BiMapper<C, Input, ConnectionType<Input, Output, C>> reducer,
  ) {
    return ConnectableMachine._(initial, reducer);
  }
}

// widget machines

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
    return BasicMachine(processor: (input, callback) {
      _uiSubject.sink.add(_ProcessItem(
        input: input,
        callback: (output) => callback(output),
      ));
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

/// A class that describes a widget machine with an injectable child widget.
class BasicWidgetMachine<Input, Output>
    extends ChildWidgetMachine<Input, Output> {
  final Widget _child;

  /// A [widget] that is returned from `Widget.child()`.
  BasicWidgetMachine({required Widget child}) : _child = child;

  /// Returns injected child widget.
  @override
  Widget child() {
    return _child;
  }
}

// extensions

extension InwardMachineExtension<ChildInput, ChildOutput>
    on Machine<ChildInput, ChildOutput> {

  /// Creates a `Machine` instance with a specific behavior applied.
  /// Every input of the resulting machine is mapped into an array of new
  /// inputs and passed to the child.
  /// parameter [mapper] - a mapper that receives triggering input and returns
  /// `Ward` object with new array of inputs as `values`.
  Machine<ParentInput, ChildOutput> inward<ParentInput>(
    Mapper<ParentInput, Ward<ChildInput>> mapper,
  ) {
    return _InwardMachine.create(this, mapper);
  }
}

extension OutwardMachineExtension<ChildInput, ChildOutput>
    on Machine<ChildInput, ChildOutput> {

  /// Creates a `Machine` instance with a specific behavior applied.
  /// Every output of the child machine is mapped into an array of new outputs
  /// and passed to the root.
  /// parameter [mapper] - a mapper that receives triggering output and returns
  /// `Ward` object with new array of outputs as `values`.
  Machine<ChildInput, ParentOutput> outward<ParentOutput>(
    Mapper<ChildOutput, Ward<ParentOutput>> mapper,
  ) {
    return _OutwardMachine.create(this, mapper);
  }
}

extension RedirectMachineExtension<ChildInput, ChildOutput>
    on Machine<ChildInput, ChildOutput> {

  /// Creates a `Machine` instance with a specific behavior applied.
  /// Every output of the child machine is either passed further to the root or
  /// mapped into an array of new inputs and passed back to the child depending
  /// on the `Direction` value returned from `mapper`
  /// parameter [mapper] - a mapper that receives triggering output and
  /// returns `Direction` object.
  /// If `Direction.prop` returned - output is pushed further to the root.
  /// If `Direction.back([Input])` returned - an array of new inputs is passed back to the child.
  Machine<ChildInput, ChildOutput> redirect(
    Mapper<ChildOutput, Direction<ChildInput>> mapper,
  ) {
    return _RedirectMachine.create(this, mapper);
  }
}

/// Creates a `Machine` instance with a specific behavior applied.
/// Every input of the resulting machine is passed into every child from the
/// `machines` array as well as every output of every child is passed into the resulting machine.
/// parameter [machines] - array of machines that are merged.
Machine<Input, Output> merge<Input, Output>(
  Set<Machine<Input, Output>> machines,
) {
  return _MergeMachine(machines);
}

extension InwardWidgetMachineExtension<ChildInput, ChildOutput>
    on WidgetMachine<ChildInput, ChildOutput> {
  /// The same behavior as in Machine.inward()
  WidgetMachine<ParentInput, ChildOutput> inward<ParentInput>(
    Mapper<ParentInput, Ward<ChildInput>> mapper,
  ) {
    return _InwardWidgetMachine.create(this, mapper);
  }
}

extension OutwardWidgetMachineExtension<ChildInput, ChildOutput>
    on WidgetMachine<ChildInput, ChildOutput> {
  /// The same behavior as in Machine.outward()
  WidgetMachine<ChildInput, ParentOutput> outward<ParentOutput>(
    Mapper<ChildOutput, Ward<ParentOutput>> mapper,
  ) {
    return _OutwardWidgetMachine.create(this, mapper);
  }
}

extension RedirectWidgetMachineExtension<ChildInput, ChildOutput>
    on WidgetMachine<ChildInput, ChildOutput> {
  /// The same behavior as Machine.redirect()
  WidgetMachine<ChildInput, ChildOutput> redirect(
    Mapper<ChildOutput, Direction<ChildInput>> mapper,
  ) {
    return _RedirectWidgetMachine.create(this, mapper);
  }
}

extension MergeWithWidgetMachine<Input, Output>
    on WidgetMachine<Input, Output> {

  /// The same behavior as Machine.merge() where first argument is `WidgetMachine`
  WidgetMachine<Input, Output> mergeWith(Set<Machine<Input, Output>> machines) {
    return mergeWidgetMachine(main: this, secondary: machines);
  }
}

/// The same behavior as Machine.merge() where first argument is `WidgetMachine`
WidgetMachine<Input, Output> mergeWidgetMachine<Input, Output>({
  required WidgetMachine<Input, Output> main,
  required Set<Machine<Input, Output>> secondary,
}) {
  return _MergeWidgetMachine(main: main, secondary: secondary);
}

// types

/// A type that represents a behavior of Machine.inward() and
/// Machine.outward operators.
class Ward<T> {
  /// [values] - values that are passed after inward() or outward() executed
  final List<T> values;

  /// [values] - values that are passed after inward() or outward() executed
  Ward.values(this.values);

  /// [value] - value that is passed after inward() or outward() executed
  Ward.single(T value) : values = [value];

  /// no values are passed after inward() or outward() executed
  Ward.ignore() : values = [];
}

/// A type that represents a behavior of Machine.redirect() operator.
class Direction<Input> {
  final Ward<Input>? _ward;

  /// Returning this value from `Machine.redirect()` method ensures
  /// that `[Input]` will be sent back to the child.
  Direction.back(Ward<Input> ward) : _ward = ward;

  /// Returning this value from `Machine.redirect()` method ensures
  /// that the output will be pushed further to the root.
  Direction.prop() : _ward = null;
}

// widgets

/// Starts the application flow.
void runRootMachine<Input, Output>(
  WidgetMachine<Input, Output> root,
) {
  runApp(
    _RootWidget(
      root._widget(),
      root._machine(),
    ),
  );
}

/// A Consumer from provider package that receives Input and may send Output
/// via Handler<Output> callback.
class MachineConsumer<Input, Output> extends StatelessWidget {
  final Mapper<BuildContext, Widget> _initial;
  final TriMapper<BuildContext, Input?, Handler<Output>, Widget> _builder;

  /// [initial] - a widget builder that provides UI before
  /// that first input is received.
  /// [builder] - a widget builder that processes UI every time input received.
  const MachineConsumer({
    Key? key,
    required Mapper<BuildContext, Widget> initial,
    required TriMapper<BuildContext, Input?, Handler<Output>, Widget> builder,
  })  : _initial = initial,
        _builder = builder,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<_ProcessItem<Input, Output>?>(
      builder: (context, value, _) {
        if (value != null) {
          // normal
          return _builder(context, value.input, value.callback);
        } else {
          // initial
          return _initial(context);
        }
      },
    );
  }
}
