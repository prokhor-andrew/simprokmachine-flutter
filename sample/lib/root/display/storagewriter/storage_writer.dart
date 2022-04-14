import 'package:sample/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simprokmachine/simprokmachine.dart';


class StorageWriter extends ChildMachine<int, void> {
  final SharedPreferences _prefs;

  StorageWriter(this._prefs);

  @override
  void process(int? input, Handler<void> callback) {
    if (input != null) {
      _prefs.setInt(storageKey, input);
    }
  }
}
