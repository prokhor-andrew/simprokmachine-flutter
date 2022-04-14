import 'package:sample/utils/void_event.dart';
import 'package:simprokmachine/simprokmachine.dart';

class Calculator extends ChildMachine<VoidEvent, int> {
  int _counter;

  Calculator(this._counter);

  @override
  void process(VoidEvent? input, Handler<int> callback) {
    if (input != null) {
      _counter += 1;
    }
    callback(_counter);
  }
}
