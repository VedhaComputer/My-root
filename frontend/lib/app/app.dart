import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import '../ui/pages/auth/login_page.dart';
import '../ui/pages/home/home_page.dart';
import '../ui/pages/polls/poll_detail_page.dart';
import '../ui/pages/polls/polls_list_page.dart';

class MyRootApp extends StatefulWidget {
  final ApiClient? apiClient;
  final AuthService? authService;
  final String? initialRoute;

  const MyRootApp({
    super.key,
    this.apiClient,
    this.authService,
    this.initialRoute,
  });

  @override
  State<MyRootApp> createState() => _MyRootAppState();
}

class _MyRootAppState extends State<MyRootApp> {
  late final ApiClient _apiClient;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _authService = widget.authService ??
        AuthService(repository: AuthRepositoryImpl(client: _apiClient));

    if (!_authService.isInitialized) {
      _authService.restoreSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: widget.initialRoute,
      title: 'My Root',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4F12), // Earth brown - roots
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4F12),
          brightness: Brightness.dark,
        ),
      ),
      home: _AppAuthGate(
        authService: _authService,
        apiClient: _apiClient,
      ),
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final uri = Uri.tryParse(rawName);
        if (uri != null) {
          var segments = uri.pathSegments;
          if (segments.isEmpty && uri.fragment.isNotEmpty) {
            final fragmentUri = Uri.tryParse(
              uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}',
            );
            if (fragmentUri != null) {
              segments = fragmentUri.pathSegments;
            }
          }

          if (segments.length == 2 && segments[0] == 'polls') {
            final pollId = segments[1];
            return MaterialPageRoute(
              builder: (_) => _AppAuthGate(
                authService: _authService,
                apiClient: _apiClient,
                targetPollId: pollId,
              ),
              settings: settings,
            );
          } else if (segments.length == 1 && segments[0] == 'polls') {
            return MaterialPageRoute(
              builder: (_) => _AppAuthGate(
                authService: _authService,
                apiClient: _apiClient,
                openPollsList: true,
              ),
              settings: settings,
            );
          }
        }
        return null;
      },
    );
  }
}

class _AppAuthGate extends StatelessWidget {
  final AuthService authService;
  final ApiClient apiClient;
  final String? targetPollId;
  final bool openPollsList;

  const _AppAuthGate({
    required this.authService,
    required this.apiClient,
    this.targetPollId,
    this.openPollsList = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        if (!authService.isInitialized) {
          final theme = Theme.of(context);
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.nature_people, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'My Root',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preserving Local Knowledge',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // Access Policy: Login required for all application routes and data access.
        // Deep-link destination (targetPollId or openPollsList) is preserved in state
        // and activates automatically immediately upon authentication.
        if (authService.isAuthenticated) {
          if (targetPollId != null && targetPollId!.isNotEmpty) {
            return PollDetailPage(
              pollId: targetPollId!,
              authService: authService,
            );
          }
          if (openPollsList) {
            return PollsListPage(
              authService: authService,
            );
          }
          return HomePage(
            authService: authService,
            apiClient: apiClient,
          );
        }

        // Unauthenticated visitor is directed to login; deep link is not lost.
        return LoginPage(authService: authService);
      },
    );
  }
}
