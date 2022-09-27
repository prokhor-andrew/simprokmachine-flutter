import 'package:simprokmachine/functions.dart';
import 'package:simprokmachine/simprokmachine.dart';

class _MergeMachine<Input, Output> extends ChildMachine<Input, Output> {
  final Set<Machine<Input, Output>> _machines;
  final List<RootMachine<Input, Output>> _roots = [];

  _MergeMachine(this._machines);

  @override
  void dispose() {
    for (final element in _roots) {
      element.stop();
    }
    _roots.clear();
  }

  @override
  void process(Input? input, Handler<Output> callback) {
    if (input != null) {
      for (final root in _roots) {
        root.send(input);
      }
    } else {
      _roots.addAll(_machines.map((machine) {
        final root = RootMachine(machine);
        root.start(callback);
        return root;
      }));
    }
  }
}

/// Creates a `Machine` instance with a specific behavior applied.
/// Every input of the resulting machine is passed into every child from the
/// `machines` array as well as every output of every child is passed into the resulting machine.
/// parameter [machines] - set of machines that are merged.
Machine<Input, Output> merge<Input, Output>(
  Set<Machine<Input, Output>> machines,
) {
  return _MergeMachine(machines);
}
