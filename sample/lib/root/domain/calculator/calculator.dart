import 'package:simprokmachine/simprokmachine.dart';

import 'calculator_input.dart';

class Calculator extends ChildMachine<CalculatorInput, int> {
  int? _counter;

  @override
  void process(CalculatorInput? input, Handler<int> callback) {
    if (input != null) {
      final int? value = input.value;
      if (value != null) {
        // initialize
        _counter = value;
      } else {
        // increment
        final int? unwrapped = _counter;
        if (unwrapped != null) {
          _counter = unwrapped + 1;
        }
      }
      final int? unwrapped = _counter;
      if (unwrapped != null) {
        callback(unwrapped);
      }
    }
  }
}
