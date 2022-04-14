class DomainInput {
  final int? fromReader;

  DomainInput.fromReader(int value) : fromReader = value;

  DomainInput.fromParent() : fromReader = null;
}
