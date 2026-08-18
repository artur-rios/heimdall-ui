/// One service the API checks, and what it reported.
class ServiceHealth {
  const ServiceHealth({required this.name, required this.status});

  final String name;

  /// The API's own word for the state. It is not an enum here on purpose: the
  /// API may add a state, and a screen that renders whatever it was told stays
  /// truthful when it does.
  final String status;

  /// Whether the status reads as healthy.
  ///
  /// Only the display leans on this — the colour of a chip — so a word this
  /// does not recognise is shown as it came rather than being called a
  /// failure.
  bool get isHealthy => status.toLowerCase() == 'healthy';
}

/// The API's detailed health report.
class Health {
  const Health({required this.status, this.services = const <ServiceHealth>[]});

  /// The aggregate the API computed across its services.
  final String status;

  final List<ServiceHealth> services;

  bool get isHealthy => status.toLowerCase() == 'healthy';

  /// The services the API reported as anything other than healthy, which is
  /// what an operator is looking for first.
  List<ServiceHealth> get unhealthy =>
      services.where((service) => !service.isHealthy).toList(growable: false);
}
