import 'web_connectivity_hint_stub.dart'
    if (dart.library.html) 'web_connectivity_hint_web.dart' as impl;

bool? browserOnlineHint() => impl.browserOnlineHint();

