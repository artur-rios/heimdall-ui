import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/session_scoped_state.dart';
import 'package:heimdall_ui/features/applications/presentation/application_create_controller.dart';
import 'package:heimdall_ui/features/applications/presentation/application_detail_controller.dart';
import 'package:heimdall_ui/features/applications/presentation/application_list_controller.dart';
import 'package:heimdall_ui/features/applications/presentation/pending_secret.dart';
import 'package:heimdall_ui/features/audit_log/presentation/audit_log_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/email_verification_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/verification_banner.dart';
import 'package:heimdall_ui/features/data_rights/presentation/restricted_session_controller.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/erasure_request_list_controller.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_detail_controller.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_list_controller.dart';
import 'package:heimdall_ui/features/health/presentation/health_controller.dart';
import 'package:heimdall_ui/features/home/presentation/dashboard_controller.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_create_controller.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_detail_controller.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_list_controller.dart';
import 'package:heimdall_ui/features/persons/presentation/person_create_controller.dart';
import 'package:heimdall_ui/features/persons/presentation/person_detail_controller.dart';
import 'package:heimdall_ui/features/persons/presentation/person_list_controller.dart';
import 'package:heimdall_ui/features/persons/presentation/scope_admin_picker_controller.dart';
import 'package:heimdall_ui/features/persons/presentation/scope_members.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/two_factor_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/pending_registration_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_create_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_detail_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_owners_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_sign_in_settings_controller.dart';

/// Every stateful provider the application declares that holds something of
/// the person signed in, by the name it is declared under.
final Map<String, ProviderOrFamily> _userScoped = <String, ProviderOrFamily>{
  'dashboardControllerProvider': dashboardControllerProvider,
  'profileControllerProvider': profileControllerProvider,
  'twoFactorControllerProvider': twoFactorControllerProvider,
  'emailVerificationControllerProvider': emailVerificationControllerProvider,
  'verificationBannerDismissedProvider': verificationBannerDismissedProvider,
  'healthControllerProvider': healthControllerProvider,
  'scopeListControllerProvider': scopeListControllerProvider,
  'scopeCreateControllerProvider': scopeCreateControllerProvider,
  'scopeDetailControllerProvider': scopeDetailControllerProvider,
  'scopeOwnersControllerProvider': scopeOwnersControllerProvider,
  'scopeSignInSettingsControllerProvider':
      scopeSignInSettingsControllerProvider,
  'pendingRegistrationListControllerProvider':
      pendingRegistrationListControllerProvider,
  'scopeAdminPickerControllerProvider': scopeAdminPickerControllerProvider,
  'scopeMembersProvider': scopeMembersProvider,
  'personListControllerProvider': personListControllerProvider,
  'personCreateControllerProvider': personCreateControllerProvider,
  'personDetailControllerProvider': personDetailControllerProvider,
  'applicationListControllerProvider': applicationListControllerProvider,
  'applicationCreateControllerProvider': applicationCreateControllerProvider,
  'applicationDetailControllerProvider': applicationDetailControllerProvider,
  'permissionListControllerProvider': permissionListControllerProvider,
  'permissionCreateControllerProvider': permissionCreateControllerProvider,
  'permissionDetailControllerProvider': permissionDetailControllerProvider,
  'googleUserListControllerProvider': googleUserListControllerProvider,
  'googleUserDetailControllerProvider': googleUserDetailControllerProvider,
  'erasureRequestListControllerProvider': erasureRequestListControllerProvider,
  'auditLogControllerProvider': auditLogControllerProvider,
  'restrictedSessionControllerProvider': restrictedSessionControllerProvider,
  'pendingSecretProvider': pendingSecretProvider,
};

/// The stateful providers that are not reset at sign-out, and why.
const Map<String, String> _exempt = <String, String>{
  'sessionControllerProvider': 'the session itself',
  'themeModeControllerProvider': "the device's preference, not the person's",
  'passwordRecoveryControllerProvider': 'used signed out, about no session',
  'passwordResetControllerProvider': 'used signed out, about no session',
  'entryLinkProvider':
      "the tab's entry link, not the person's; a reset would restore it",
  'accountEmailsControllerProvider': 'autoDispose: goes with its screen',
  'applicationCredentialsControllerProvider':
      'autoDispose: goes with its screen',
  'reconciliationControllerProvider': 'autoDispose: goes with its screen',
  'restrictProcessingControllerProvider': 'autoDispose: goes with its screen',
  'systemAdminListControllerProvider': 'autoDispose: goes with its screen',
};

/// The name of every top-level provider under `lib` that holds state — every
/// kind but a plain `Provider`, which here only wires a dependency in.
Set<String> _declaredStatefulProviders() {
  final declaration = RegExp(
    r'^final\b[^;=]*?\b(\w+Provider)\s*=\s*(\w+)\b',
    multiLine: true,
  );

  return <String>{
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File && file.path.endsWith('.dart'))
        for (final match in declaration.allMatches(file.readAsStringSync()))
          if (match.group(2) != 'Provider') match.group(1)!,
  };
}

void main() {
  // Every provider is a decision: reset at sign-out, or exempt for a reason.
  test('GivenTheDeclaredProviders_WhenClassified_ThenNoneIsLeftOut', () {
    // Given
    final declared = _declaredStatefulProviders();

    // When
    final classified = <String>{..._userScoped.keys, ..._exempt.keys};

    // Then
    expect(declared.difference(classified), isEmpty);
    expect(classified.difference(declared), isEmpty);
    expect(
      _userScoped.keys.toSet().intersection(_exempt.keys.toSet()),
      isEmpty,
    );
  });

  // A session that ends takes every one of the person's providers with it.
  test('GivenTheUserScopedProviders_WhenTheResetListIsRead_ThenAllAreIn', () {
    // Given
    final userScoped = _userScoped.entries;

    // When
    final missing = <String>[
      for (final entry in userScoped)
        if (!sessionScopedProviders.contains(entry.value)) entry.key,
    ];

    // Then
    expect(missing, isEmpty);
    expect(sessionScopedProviders, hasLength(_userScoped.length));
  });
}
