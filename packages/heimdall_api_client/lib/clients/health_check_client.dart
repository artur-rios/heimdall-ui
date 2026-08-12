// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/health_check_output_data_output.dart';
import '../models/string_data_output.dart';

part 'health_check_client.g.dart';

@RestApi()
abstract class HealthCheckClient {
  factory HealthCheckClient(Dio dio, {String? baseUrl}) = _HealthCheckClient;

  /// Basic liveness check (UC-30, FR-HC-01): confirms the API process is up and responding.
  /// Public — no authentication required.
  ///
  /// **Anonymous** — no bearer token required.
  @GET('/HealthCheck')
  Future<StringDataOutput> healthCheckHelloWorld();

  /// Detailed health check (UC-30, FR-HC-02…07): reports the status of each verified service.
  /// plus an aggregate general status. Restricted to System Admins (AF-30a → 403, AF-30b → 401).
  /// Returns `200 OK` when healthy and `503 Service Unavailable` when any verified.
  /// service is down (FR-HC-07, AF-30c).
  ///
  /// **Requires role:** System Admin.
  @GET('/HealthCheck/detailed')
  Future<HealthCheckOutputDataOutput> healthCheckDetailed();
}
