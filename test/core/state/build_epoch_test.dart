import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/state/build_epoch.dart';

class _Counter extends Notifier<int> with BuildEpoch<int> {
  @override
  int build() {
    startEpoch();

    return 0;
  }
}

final NotifierProvider<_Counter, int> _counterProvider =
    NotifierProvider<_Counter, int>(_Counter.new);

void main() {
  late ProviderContainer container;

  _Counter counter() => container.read(_counterProvider.notifier);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('GivenAFirstBuild_WhenItsEpochIsRead_ThenItIsCurrent', () {
    // Given
    final notifier = counter();

    // When
    final epoch = notifier.epoch;

    // Then
    expect(notifier.isCurrent(epoch), isTrue);
  });

  test('GivenAnEpochReadBeforeARebuild_WhenChecked_ThenItIsNotCurrent', () {
    // Given
    final notifier = counter();
    final epoch = notifier.epoch;

    // When
    container.invalidate(_counterProvider);
    container.read(_counterProvider);

    // Then
    expect(identical(counter(), notifier), isTrue);
    expect(notifier.isCurrent(epoch), isFalse);
    expect(notifier.isCurrent(notifier.epoch), isTrue);
  });

  test('GivenAnEpoch_WhenAdvancedWithoutARebuild_ThenItIsNotCurrent', () {
    // Given
    final notifier = counter();
    final epoch = notifier.epoch;

    // When
    notifier.advanceEpoch();

    // Then
    expect(notifier.isCurrent(epoch), isFalse);
    expect(notifier.epoch, epoch + 1);
  });

  test('GivenTwoRebuilds_WhenTheEpochIsRead_ThenItMovedOnOncePerBuild', () {
    // Given
    final notifier = counter();
    final first = notifier.epoch;

    // When
    container.invalidate(_counterProvider);
    container.read(_counterProvider);
    container.invalidate(_counterProvider);
    container.read(_counterProvider);

    // Then
    expect(notifier.epoch, first + 2);
  });
}
