class LocalJsonPersistence {
  const LocalJsonPersistence(this.key);

  final String key;

  String? read() => null;

  void write(String payload) {}

  void listen(void Function(String? payload) onChange) {}
}
