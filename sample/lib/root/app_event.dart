class AppEvent {
  final int? didChangeState;

  AppEvent.willChangeState() : didChangeState = null;

  AppEvent.didChangeState(int number) : didChangeState = number;

  @override
  String toString() {
    return didChangeState != null
        ? "did change state: $didChangeState"
        : "will change state";
  }
}
