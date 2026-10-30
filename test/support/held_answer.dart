import 'dart:async';

/// An answer for a repository call that is repeated: the first call waits for
/// [first], and every later one is answered at once with [later].
///
/// The shape of "a request is in flight while the user changes something": the
/// changes made before [first] completes are the ones that must survive into
/// the request that follows it.
Future<ResultT> Function(Invocation invocation) heldFirstAnswer<ResultT>(
  Completer<ResultT> first,
  ResultT Function() later,
) {
  var calls = 0;

  return (_) {
    calls++;

    return calls == 1 ? first.future : Future<ResultT>.value(later());
  };
}
