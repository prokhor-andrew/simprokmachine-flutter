import 'package:simprokmachine/simprokmachine.dart';

import 'functions.dart';

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

class InwardMachine<ParentInput, ChildInput, Output>
    extends ChildMachine<ParentInput, Output> {
  final Machine<ChildInput, Output> child;
  final Mapper<ParentInput, Ward<ChildInput>> mapper;

  RootMachine<ChildInput, Output>? _root;

  InwardMachine(
    this.child,
    this.mapper,
  );

  @override
  void process(ParentInput? input, Handler<Output> callback) {
    if (input != null) {
      for (final element in mapper(input).values) {
        _root?.send(element);
      }
    } else {
      _root = RootMachine(child);
      _root?.start(callback);
    }
  }

  @override
  void dispose() {
    _root?.stop();
    _root = null;
  }
}

extension InwardMachineExtension<ParentInput, ChildInput, Output>
    on Machine<ChildInput, Output> {
  Machine<ParentInput, Output> inward(
      Mapper<ParentInput, Ward<ChildInput>> function) {
    return InwardMachine(this, function);
  }
}

class OutwardMachine<ParentOutput, ChildOutput, Input>
    extends ChildMachine<Input, ParentOutput> {
  final Machine<Input, ChildOutput> child;
  final Mapper<ChildOutput, Ward<ParentOutput>> mapper;

  RootMachine<Input, ChildOutput>? _root;

  OutwardMachine(
    this.child,
    this.mapper,
  );

  @override
  void process(Input? input, Handler<ParentOutput> callback) {
    if (input != null) {
      _root?.send(input);
    } else {
      _root = RootMachine(child);
      _root?.start((ChildOutput childOutput) {
        for (final element in mapper(childOutput).values) {
          callback(element);
        }
      });
    }
  }

  @override
  void dispose() {
    _root?.stop();
    _root = null;
  }
}

extension OutwardMachineExtension<ChildInput, ChildOutput>
    on Machine<ChildInput, ChildOutput> {
  Machine<ChildInput, ParentOutput> outward<ParentOutput>(
    Mapper<ChildOutput, Ward<ParentOutput>> function,
  ) {
    return OutwardMachine(this, function);
  }
}
