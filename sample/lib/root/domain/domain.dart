import 'package:sample/root/app_event.dart';
import 'package:sample/root/domain/calculator/calculator.dart';
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
    Machine<DomainInput, DomainOutput> getCalculator(int value) {
      return Calculator(value).outward((int output) {
        return Ward<DomainOutput>.single(DomainOutput.fromCalculator(output));
      }).inward((DomainInput input) {
        final int? fromReader = input.fromReader;
        if (fromReader != null) {
          return Ward<VoidEvent>.ignore();
        } else {
          return Ward<VoidEvent>.single(VoidEvent());
        }
      });
    }

    final Machine<DomainInput, DomainOutput> reader =
        StorageReader(_prefs).outward((int output) {
      return Ward<DomainOutput>.single(DomainOutput.fromReader(output));
    }).inward((DomainInput input) {
      return Ward<VoidEvent>.ignore();
    });

    final Machine<DomainInput, DomainOutput> connectable =
        ConnectableMachine.create<DomainInput, DomainOutput,
            BasicConnection<DomainInput, DomainOutput>>(
      BasicConnection<DomainInput, DomainOutput>({reader}),
      (BasicConnection<DomainInput, DomainOutput> state, DomainInput input) {
        final int? fromReader = input.fromReader;
        if (fromReader != null) {
          return ConnectionType<DomainInput, DomainOutput,
                  BasicConnection<DomainInput, DomainOutput>>.reduce(
              BasicConnection<DomainInput, DomainOutput>(
                  {getCalculator(fromReader)}));
        } else {
          return ConnectionType<DomainInput, DomainOutput,
              BasicConnection<DomainInput, DomainOutput>>.inward();
        }
      },
    ).redirect((DomainOutput output) {
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
