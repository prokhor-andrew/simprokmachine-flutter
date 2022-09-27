import 'package:simprokmachine/simprokmachine.dart';

import 'functions.dart';
import 'mapper.dart';

class _RedirectMachine<Input, Output> extends ChildMachine<Input, Output> {

  final Machine<Input, Output> _child;
  final Mapper<Output, Direction<Input>> _mapper;

  _RedirectMachine(this._child, this._mapper);

  RootMachine<Input, Output>? _root;

  @override
  void dispose() {
    _root?.stop();
    _root = null;
  }

  @override
  void process(Input? input, Handler<Output> callback) {
    if (input != null) {
      _root?.send(input);
    } else {
      _root = RootMachine(_child);
      _root?.start((Output output) {
        final Ward<Input>? result = _mapper(output)._ward;
        if (result != null) {
          for (final element in result.values) {
            _root?.send(element);
          }
        } else {
          callback(output);
        }

        _mapper(output);
      });
    }
  }
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
    return _RedirectMachine(this, mapper);
  }
}
