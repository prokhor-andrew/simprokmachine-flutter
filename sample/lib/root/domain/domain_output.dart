class DomainOutput {
  final bool isFromReader;
  final int value;

  DomainOutput.fromReader(this.value) : isFromReader = true;

  DomainOutput.fromCalculator(this.value) : isFromReader = false;
}
