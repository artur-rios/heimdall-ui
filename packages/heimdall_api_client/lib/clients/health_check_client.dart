// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/string_data_output.dart';

part 'health_check_client.g.dart';

@RestApi()
abstract class HealthCheckClient {
  factory HealthCheckClient(Dio dio, {String? baseUrl}) = _HealthCheckClient;

  /// Basic liveness check (UC-30, FR-HC-01): confirms the API process is up and responding.
  /// Public — no authentication required.
  ///
  /// **Anonymous** — no bearer token required.
  @GET('/api/healthcheck')
  Future<StringDataOutput> healthCheckHelloWorld();
}
