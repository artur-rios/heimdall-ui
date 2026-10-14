import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../features/applications/presentation/application_create_controller.dart';
import '../features/applications/presentation/application_detail_controller.dart';
import '../features/applications/presentation/application_list_controller.dart';
import '../features/audit_log/presentation/audit_log_controller.dart';
import '../features/auth/presentation/email_verification_controller.dart';
import '../features/auth/presentation/verification_banner.dart';
import '../features/erasure_requests/presentation/erasure_request_list_controller.dart';
import '../features/google_users/presentation/google_user_detail_controller.dart';
import '../features/google_users/presentation/google_user_list_controller.dart';
import '../features/health/presentation/health_controller.dart';
import '../features/home/presentation/dashboard_controller.dart';
import '../features/permissions/presentation/permission_create_controller.dart';
import '../features/permissions/presentation/permission_detail_controller.dart';
import '../features/permissions/presentation/permission_list_controller.dart';
import '../features/persons/presentation/person_create_controller.dart';
import '../features/persons/presentation/person_detail_controller.dart';
import '../features/persons/presentation/person_list_controller.dart';
import '../features/persons/presentation/scope_admin_picker_controller.dart';
import '../features/persons/presentation/scope_members.dart';
import '../features/profile/presentation/profile_controller.dart';
import '../features/profile/presentation/two_factor_controller.dart';
import '../features/scopes/presentation/pending_registration_list_controller.dart';
import '../features/scopes/presentation/scope_create_controller.dart';
import '../features/scopes/presentation/scope_detail_controller.dart';
import '../features/scopes/presentation/scope_list_controller.dart';
import '../features/scopes/presentation/scope_owners_controller.dart';

/// Every provider that remembers something about the person signed in: their
/// listings and filters, the records they opened, their own profile, the
/// prompts they dismissed.
///
/// None of it is anybody else's business, and the next session on the same
/// device may be somebody else's — so the application root forgets all of it
/// the moment a session ends. Without this, the next person to sign in would
/// first be shown the previous one's scopes.
///
/// A provider that holds per-session state belongs here.
/// `RestrictedSessionController` resets itself and is not listed.
final List<ProviderOrFamily> sessionScopedProviders = <ProviderOrFamily>[
  dashboardControllerProvider,
  profileControllerProvider,
  twoFactorControllerProvider,
  emailVerificationControllerProvider,
  verificationBannerDismissedProvider,
  healthControllerProvider,
  scopeListControllerProvider,
  scopeCreateControllerProvider,
  scopeDetailControllerProvider,
  scopeOwnersControllerProvider,
  pendingRegistrationListControllerProvider,
  scopeAdminPickerControllerProvider,
  scopeMembersProvider,
  personListControllerProvider,
  personCreateControllerProvider,
  personDetailControllerProvider,
  applicationListControllerProvider,
  applicationCreateControllerProvider,
  applicationDetailControllerProvider,
  permissionListControllerProvider,
  permissionCreateControllerProvider,
  permissionDetailControllerProvider,
  googleUserListControllerProvider,
  googleUserDetailControllerProvider,
  erasureRequestListControllerProvider,
  auditLogControllerProvider,
];
