import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import '../ui/pages/auth/login_page.dart';
import '../ui/pages/auth/verify_email_page.dart';
import '../ui/pages/home/home_page.dart';
import '../ui/pages/polls/poll_detail_page.dart';
import '../ui/pages/polls/polls_list_page.dart';

class MyRootApp extends StatefulWidget {
  final ApiClient? apiClient;
  final AuthService? authService;

  const MyRootApp({
    super.key,
    this.apiClient,
    this.authService,
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
        var routeName = settings.name ?? '';
        if (routeName.startsWith('/#')) {
          routeName = routeName.substring(2);
        } else if (routeName.startsWith('#')) {
          routeName = routeName.substring(1);
        }
        var uri = Uri.tryParse(routeName);
        if (uri != null) {
          if (uri.hasFragment && uri.fragment.contains('/')) {
            final fragmentPath = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
            final parsedFragment = Uri.tryParse(fragmentPath);
            if (parsedFragment != null && parsedFragment.pathSegments.isNotEmpty) {
              uri = parsedFragment;
            }
          }
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
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
          } else if (segments.isNotEmpty && segments[0] == 'verify-email') {
            final rawToken = uri.queryParameters['token'] ??
                (uri.hasFragment && uri.fragment.contains('token=')
                    ? extractVerificationToken(uri.fragment)
                    : null);
            final token = rawToken != null && rawToken.isNotEmpty ? extractVerificationToken(rawToken) : null;
            final email = uri.queryParameters['email'];
            return MaterialPageRoute(
              builder: (_) => VerifyEmailPage(
                authService: _authService,
                initialToken: token,
                initialEmail: email,
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

        return LoginPage(authService: authService);
      },
    );
  }
}
