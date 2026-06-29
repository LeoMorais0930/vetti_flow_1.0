import 'dart:js_interop';

import 'package:web/web.dart' as web;

class ProductionFlowPersistence {
  static const _key = 'vetti_flow.production_flow.v1';

  String? read() => web.window.localStorage.getItem(_key);

  void write(String payload) {
    web.window.localStorage.setItem(_key, payload);
  }

  void listen(void Function(String? payload) onChange) {
    web.window.addEventListener(
      'storage',
      ((web.Event event) {
        final storageEvent = event as web.StorageEvent;
        if (storageEvent.key == _key) {
          onChange(storageEvent.newValue);
        }
      }).toJS,
    );
  }
}
