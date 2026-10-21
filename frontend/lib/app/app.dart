import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import '../ui/pages/auth/login_page.dart';
import '../ui/pages/home/home_page.dart';

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
    );
  }
}

class _AppAuthGate extends StatelessWidget {
  final AuthService authService;
  final ApiClient apiClient;

  const _AppAuthGate({
    required this.authService,
    required this.apiClient,
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
