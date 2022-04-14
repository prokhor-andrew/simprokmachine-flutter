import 'package:flutter/cupertino.dart';
import 'package:sample/root/app_event.dart';
import 'package:sample/root/display/display.dart';
import 'package:sample/root/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simprokmachine/simprokmachine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runRootMachine<AppEvent, AppEvent>(
    mergeWidgetMachine(
      main: Display(prefs),
      secondary: {
        Domain(prefs),
      },
    ).redirect((AppEvent output) =>
        Direction<AppEvent>.back(Ward<AppEvent>.single(output))),
  );
}
