import 'dart:js_interop';

import 'package:web/web.dart' as web;

class LocalJsonPersistence {
  const LocalJsonPersistence(this.key);

  final String key;

  String? read() => web.window.localStorage.getItem(key);

  void write(String payload) {
    web.window.localStorage.setItem(key, payload);
  }

  void listen(void Function(String? payload) onChange) {
    web.window.addEventListener(
      'storage',
      ((web.Event event) {
        final storageEvent = event as web.StorageEvent;
        if (storageEvent.key == key) {
          onChange(storageEvent.newValue);
        }
      }).toJS,
    );
  }
}
