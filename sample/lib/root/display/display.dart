import 'package:sample/root/app_event.dart';
import 'package:sample/root/display/logger/logger.dart';
import 'package:sample/root/display/storagewriter/storage_writer.dart';
import 'package:sample/root/display/widget/window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simprokmachine/simprokmachine.dart';

class Display extends ParentWidgetMachine<AppEvent, AppEvent> {
  final SharedPreferences _prefs;

  Display(this._prefs);

  @override
  WidgetMachine<AppEvent, AppEvent> child() {
    final WidgetMachine<String, AppEvent> ui = Window()
        .outward((_) => Ward<AppEvent>.single(AppEvent.willChangeState()));

    final Machine<String, AppEvent> logger =
        Logger().outward((void output) => Ward<AppEvent>.ignore());

    final Machine<AppEvent, AppEvent> writer =
        StorageWriter(_prefs).inward((AppEvent event) {
      final int? didChangeState = event.didChangeState;
      if (didChangeState != null) {
        return Ward<int>.single(didChangeState);
      } else {
        return Ward<int>.ignore();
      }
    }).outward((void output) => Ward<AppEvent>.ignore());

    final WidgetMachine<AppEvent, AppEvent> merged = mergeWidgetMachine(
      main: ui,
      secondary: {logger},
    ).inward((AppEvent event) {
      final int? didChangeState = event.didChangeState;
      if (didChangeState != null) {
        return Ward<String>.single("$didChangeState");
      } else {
        return Ward<String>.ignore();
      }
    });

    return mergeWidgetMachine(main: merged, secondary: {writer});
  }
}
