import 'package:sample/root/app_event.dart';
import 'package:sample/root/domain/calculator/calculator.dart';
import 'package:sample/root/domain/calculator/calculator_input.dart';
import 'package:sample/root/domain/storagereader/storage_reader.dart';
import 'package:sample/utils/void_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simprokmachine/simprokmachine.dart';

import 'domain_input.dart';
import 'domain_output.dart';

class Domain extends ParentMachine<AppEvent, AppEvent> {
  final SharedPreferences _prefs;

  Domain(this._prefs);

  @override
  Machine<AppEvent, AppEvent> child() {
    final Machine<DomainInput, DomainOutput> reader =
        StorageReader(_prefs).outward((int output) {
      return Ward<DomainOutput>.single(DomainOutput.fromReader(output));
    }).inward((DomainInput input) {
      return Ward<VoidEvent>.ignore();
    });

    final Machine<DomainInput, DomainOutput> calculator =
        Calculator().outward((int output) {
      return Ward<DomainOutput>.single(DomainOutput.fromCalculator(output));
    }).inward((DomainInput input) {
      final int? fromReader = input.fromReader;
      if (fromReader != null) {
        return Ward<CalculatorInput>.single(
          CalculatorInput.initialize(fromReader),
        );
      } else {
        return Ward<CalculatorInput>.single(CalculatorInput.increment());
      }
    });

    final Machine<DomainInput, DomainOutput> connectable = merge({
      reader,
      calculator,
    }).redirect((DomainOutput output) {
      if (output.isFromReader) {
        return Direction<DomainInput>.back(
          Ward<DomainInput>.single(
            DomainInput.fromReader(output.value),
          ),
        );
      } else {
        return Direction<DomainInput>.prop();
      }
    });

    return connectable.outward((DomainOutput output) {
      if (output.isFromReader) {
        return Ward<AppEvent>.ignore();
      } else {
        return Ward<AppEvent>.single(AppEvent.didChangeState(output.value));
      }
    }).inward((AppEvent input) {
      final int? didChangeState = input.didChangeState;
      if (didChangeState != null) {
        return Ward<DomainInput>.ignore();
      } else {
        return Ward<DomainInput>.single(DomainInput.fromParent());
      }
    });
  }
}
