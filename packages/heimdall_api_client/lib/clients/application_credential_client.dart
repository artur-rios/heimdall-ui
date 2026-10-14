// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/application_credential_list_output_data_output.dart';
import '../models/issue_application_credential_command.dart';
import '../models/issue_application_credential_command_output_data_output.dart';
import '../models/revoke_application_credential_command_output_data_output.dart';

part 'application_credential_client.g.dart';

@RestApi()
abstract class ApplicationCredentialClient {
  factory ApplicationCredentialClient(Dio dio, {String? baseUrl}) =
      _ApplicationCredentialClient;

  /// Issues a credential (UC-53). The body is optional and carries only `expiresAt`. The.
  /// answer is the only place the secret ever appears; Heimdall keeps its hash alone.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @POST('/api/scopes/{scopeId}/applications/{id}/credentials')
  Future<IssueApplicationCredentialCommandOutputDataOutput>
  applicationCredentialIssue({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Body() IssueApplicationCredentialCommand? body,
  });

  /// Lists the application's credentials, newest first, with whether each is live (UC-54).
  /// Never a secret or a hash.
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @GET('/api/scopes/{scopeId}/applications/{id}/credentials')
  Future<ApplicationCredentialListOutputDataOutput> applicationCredentialList({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
  });

  /// Revokes one credential (UC-55). Its secret stops being exchanged at once, and every token.
  /// already issued from it fails the next live re-check (UC-57).
  ///
  /// **Requires role:** System Admin or Scope Admin.
  @DELETE('/api/scopes/{scopeId}/applications/{id}/credentials/{credentialId}')
  Future<RevokeApplicationCredentialCommandOutputDataOutput>
  applicationCredentialRevoke({
    @Path('scopeId') required String scopeId,
    @Path('id') required String id,
    @Path('credentialId') required String credentialId,
  });
}
