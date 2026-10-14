// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/application_token_check_output_data_output.dart';
import '../models/issue_application_token_command.dart';
import '../models/issue_application_token_command_output_data_output.dart';

part 'application_token_client.g.dart';

@RestApi()
abstract class ApplicationTokenClient {
  factory ApplicationTokenClient(Dio dio, {String? baseUrl}) =
      _ApplicationTokenClient;

  /// Exchanges an application's secret for a token valid for ten minutes by default (UC-56).
  /// Every refusal is the same 401, so the endpoint reveals nothing about which applications,.
  /// scopes or credentials exist. Rate-limited per client address like the person sign-in.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/applications/token')
  Future<IssueApplicationTokenCommandOutputDataOutput>
  applicationTokenIssueToken({@Body() IssueApplicationTokenCommand? body});

  /// Checks an application token live (UC-57), presented as `Authorization: Bearer …`.
  /// Answers the application, its scope and the credential when the token is valid and all.
  /// three are still live; otherwise one 401. Anonymous to the middleware, which accepts only.
  /// person tokens: the handler validates the token itself.
  ///
  /// **Anonymous** — no bearer token required.
  @GET('/api/applications/self')
  Future<ApplicationTokenCheckOutputDataOutput> applicationTokenSelf();
}
