import 'package:sample/constants.dart';
import 'package:sample/utils/void_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simprokmachine/simprokmachine.dart';

class StorageReader extends ChildMachine<VoidEvent, int> {
  final SharedPreferences _prefs;

  StorageReader(this._prefs);

  @override
  void process(VoidEvent? input, Handler<int> callback) {
    callback(_prefs.getInt(storageKey) ?? 0);
  }
}
