import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_list_screen.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_log_repository.dart';
import 'package:heimdall_ui/features/audit_log/presentation/audit_log_screen.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/login_screen.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/erasure_request_list_screen.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_list_screen.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_list_screen.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/person_list_screen.dart';
import 'package:heimdall_ui/features/persons/presentation/system_admin_list_screen.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration_repository.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/pending_registration_list_screen.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/jwt.dart';
import '../support/pump_app.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

class _MockAuditLogRepository extends Mock implements AuditLogRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

class _MockPendingRegistrationRepository extends Mock
    implements PendingRegistrationRepository {}

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockScopePermissionRepository extends Mock
    implements ScopePermissionRepository {}

class _MockScopeRepository extends Mock implements ScopeRepository {}

/// Google's half, faked: the sign-in button is offered, nothing is reached.
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async =>
      const GoogleSignInCancelled();

  @override
  Future<void> signOut() async {}
}

envelope.Page<T> _page<T>(List<T> items) => envelope.Page<T>(
  items: items,
  pageNumber: 1,
  pageSize: 20,
  // More than one page, so the pager is on screen as well.
  totalItems: 45,
  totalPages: 3,
);

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  ownerIds: <String>['person-1', 'person-2'],
);

const _ada = Person(
  id: 'person-1',
  name: 'Ada Lovelace',
  email: 'ada.lovelace@example.com',
  role: Role.scopeAdmin,
);

/// One screen to check: what it shows, and the repositories it reads from,
/// answered with a page of rows so the rows themselves are laid out.
class _Screen {
  const _Screen(this.name, this.rowText, this.build);

  final String name;

  /// Text only a rendered row shows, so a failure or empty state cannot pass
  /// for the screen.
  final String rowText;

  /// The screen's widget, and the overrides that feed it; built per test so
  /// no mock outlives one.
  final ({Widget screen, List<Override> overrides}) Function() build;
}

final List<_Screen> _screens = <_Screen>[
  _Screen('scope list', 'Acme', () {
    final scopes = _MockScopeRepository();
    when(
      () => scopes.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success<envelope.Page<Scope>>(_page([_acme])));

    return (
      screen: const ScopeListScreen(),
      overrides: <Override>[scopeRepositoryProvider.overrideWithValue(scopes)],
    );
  }),
  _Screen('person list', 'Ada Lovelace', () {
    final persons = _MockPersonRepository();
    when(
      () => persons.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success<envelope.Page<Person>>(_page([_ada])));

    return (
      screen: const PersonListScreen(scopeId: 'scope-1'),
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(persons),
      ],
    );
  }),
  _Screen('system admin list', 'Ada Lovelace', () {
    final persons = _MockPersonRepository();
    when(
      () => persons.listSystemAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<PersonSummary>>(
        _page(const <PersonSummary>[
          PersonSummary(
            id: 'admin-1',
            name: 'Ada Lovelace',
            email: 'ada.lovelace@example.com',
          ),
        ]),
      ),
    );

    return (
      screen: const SystemAdminListScreen(),
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(persons),
      ],
    );
  }),
  _Screen('permission list', 'read:invoices', () {
    final permissions = _MockScopePermissionRepository();
    when(
      () => permissions.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<ScopePermission>>(
        _page(const <ScopePermission>[
          ScopePermission(
            id: 'permission-1',
            name: 'read:invoices',
            description: 'May read invoices',
            includeAsJwtClaim: true,
          ),
        ]),
      ),
    );

    return (
      screen: const PermissionListScreen(scopeId: 'scope-1'),
      overrides: <Override>[
        scopePermissionRepositoryProvider.overrideWithValue(permissions),
      ],
    );
  }),
  _Screen('application list', 'Billing', () {
    final applications = _MockApplicationRepository();
    final persons = _MockPersonRepository();
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<Application>>(
        _page(const <Application>[
          Application(id: 'app-1', name: 'Billing', ownerId: 'person-1'),
        ]),
      ),
    );
    when(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => const Success<Person>(_ada));

    return (
      screen: const ApplicationListScreen(scopeId: 'scope-1'),
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(applications),
        personRepositoryProvider.overrideWithValue(persons),
      ],
    );
  }),
  _Screen('google user list', 'Ada Lovelace', () {
    final googleUsers = _MockGoogleUserRepository();
    final scopes = _MockScopeRepository();
    when(
      () => googleUsers.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<GoogleUser>>(
        _page(const <GoogleUser>[
          GoogleUser(
            id: 'google-1',
            name: 'Ada Lovelace',
            email: 'ada.lovelace@example.com',
          ),
        ]),
      ),
    );
    when(
      () => scopes.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => const Success<Scope>(_acme));

    return (
      screen: const GoogleUserListScreen(scopeId: 'scope-1'),
      overrides: <Override>[
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        scopeRepositoryProvider.overrideWithValue(scopes),
      ],
    );
  }),
  _Screen('pending registration list', 'Ada Lovelace', () {
    final pending = _MockPendingRegistrationRepository();
    final scopes = _MockScopeRepository();
    when(
      () => pending.list(
        any(),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<PendingRegistration>>(
        _page(<PendingRegistration>[
          PendingRegistration(
            id: 'r1',
            name: 'Ada Lovelace',
            email: 'ada.lovelace@example.com',
            createdAt: DateTime.utc(2026, 10, 1, 9),
            expiresAt: DateTime.utc(2026, 10, 2, 9),
            attemptsLeft: 7,
            expired: false,
          ),
        ]),
      ),
    );
    when(
      () => scopes.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => const Success<Scope>(_acme));

    return (
      screen: const PendingRegistrationListScreen(scopeId: 'scope-1'),
      overrides: <Override>[
        pendingRegistrationRepositoryProvider.overrideWithValue(pending),
        scopeRepositoryProvider.overrideWithValue(scopes),
      ],
    );
  }),
  _Screen('erasure request list', 'subject-1', () {
    final erasures = _MockErasureRequestRepository();
    when(
      () => erasures.list(
        overdueOnly: any(named: 'overdueOnly'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<OutstandingErasure>>(
        _page(<OutstandingErasure>[
          OutstandingErasure(
            subjectId: 'subject-1',
            isGoogleUser: false,
            requestedAt: DateTime.utc(2026, 9, 1),
            dueAt: DateTime.utc(2026, 10, 1),
            overdue: true,
            blockedReason: 'The subject is the last owner of a scope.',
          ),
        ]),
      ),
    );

    return (
      screen: const ErasureRequestListScreen(),
      overrides: <Override>[
        erasureRequestRepositoryProvider.overrideWithValue(erasures),
      ],
    );
  }),
  _Screen('audit log', 'CreateScopeCommand', () {
    final audit = _MockAuditLogRepository();
    when(
      () => audit.list(
        filter: any(named: 'filter'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<AuditEntry>>(
        _page(<AuditEntry>[
          AuditEntry(
            id: 'a1',
            recordedAt: DateTime.utc(2026, 10, 14, 12),
            actorId: 'actor-1',
            actorRole: Role.scopeAdmin,
            action: 'CreateScopeCommand',
            succeeded: false,
            failureReason: 'You are not an owner of the target scope.',
          ),
        ]),
      ),
    );

    return (
      screen: const AuditLogScreen(),
      overrides: <Override>[
        auditLogRepositoryProvider.overrideWithValue(audit),
      ],
    );
  }),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const AuditLogFilter());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // A phone, where large text has the least room; a tablet, whose rail shows
  // its labels under the icons; and a desktop window, where the rows become a
  // table whose cells must still grow with the text.
  final windows = <String, Size>{
    'compact': compactWindow,
    'medium': mediumWindow,
    'expanded': expandedWindow,
  };
  final themes = <String, ThemeData Function()>{
    'light': buildLightTheme,
    'dark': buildDarkTheme,
  };

  /// The three guidelines, on what is on screen now.
  Future<void> meetsTheGuidelines(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  }

  for (final screen in _screens) {
    for (final window in windows.entries) {
      for (final theme in themes.entries) {
        testWidgets(
          'Given${screen.name}_WhenTextIsDoubledIn${theme.key}${window.key}_'
          'ThenNothingOverflowsAndTheGuidelinesHold',
          (tester) async {
            final built = screen.build();
            await pumpApp(
              tester,
              size: window.value,
              theme: theme.value(),
              textScale: 2.0,
              token: testToken(testJwt()),
              overrides: built.overrides,
              home: built.screen,
            );

            expect(tester.takeException(), isNull);
            expect(find.textContaining(screen.rowText), findsWidgets);
            await meetsTheGuidelines(tester);
          },
        );
      }
    }
  }

  for (final window in windows.entries) {
    for (final theme in themes.entries) {
      testWidgets(
        'GivenTheLoginScreen_WhenTextIsDoubledIn${theme.key}${window.key}_'
        'ThenNothingOverflowsAndTheGuidelinesHold',
        (tester) async {
          await pumpApp(
            tester,
            size: window.value,
            theme: theme.value(),
            textScale: 2.0,
            overrides: <Override>[
              appConfigProvider.overrideWithValue(
                const AppConfig(
                  apiBaseUrl: 'http://localhost:8080',
                  googleClientId: 'client-id.apps.googleusercontent.com',
                ),
              ),
              authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
              scopeSourceProvider.overrideWithValue(
                const FixedScopeSource(null),
              ),
              googleSignInGatewayProvider.overrideWithValue(
                _FakeGoogleSignInGateway(),
              ),
            ],
            home: const LoginScreen(),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(TextFormField), findsWidgets);
          await meetsTheGuidelines(tester);
        },
      );
    }
  }
}
