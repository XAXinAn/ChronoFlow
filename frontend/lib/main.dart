import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'pages/auth/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/home_page.dart';
import 'pages/profile/bind_email_page.dart';
import 'pages/profile/change_nickname_page.dart';
import 'pages/profile/change_phone_page.dart';
import 'pages/profile/change_password_page.dart';
import 'pages/profile/about_page.dart';
import 'pages/profile/privacy_policy_page.dart';
import 'pages/profile/user_agreement_page.dart';
import 'pages/schedule/shared_image_handler.dart';
import 'model/auth_model.dart';
import 'service/auth_service.dart';
import 'constants/app_constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  intl.Intl.defaultLocale = 'zh_CN';
  try {
    await AuthService.loadStoredAuth();
  } catch (e) {
    // 安全存储不可用时回退到未认证状态 (H-07)
    debugPrint('加载本地认证信息失败: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时纪流',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppConstants.primaryColor,
          onPrimary: AppConstants.onPrimaryColor,
          surface: AppConstants.surfaceColor,
          onSurface: AppConstants.onSurfaceColor,
        ),
        scaffoldBackgroundColor: AppConstants.backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.appBarBackgroundColor,
          foregroundColor: AppConstants.onSurfaceColor,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: AppConstants.onPrimaryColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingXXL, vertical: AppConstants.paddingL),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusS)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppConstants.darkGray,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            borderSide: const BorderSide(color: AppConstants.primaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingL, vertical: AppConstants.paddingL),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppConstants.primaryColor,
          contentTextStyle: TextStyle(color: AppConstants.onPrimaryColor),
        ),
      ),
      navigatorKey: navigatorKey,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterPage());
          case '/home':
            final loginResponse = settings.arguments as LoginResponse?;
            if (loginResponse == null) {
              return MaterialPageRoute(builder: (_) => const LoginPage());
            }
            return MaterialPageRoute(
              builder: (_) => HomePage(loginResponse: loginResponse),
            );
          case '/bind-email':
            final initialEmail = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => BindEmailPage(initialEmail: initialEmail),
            );
          case '/change-nickname':
            final currentNickname = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => ChangeNicknamePage(currentNickname: currentNickname),
            );
          case '/about':
            return MaterialPageRoute(
              builder: (_) => const AboutPage(),
            );
          case '/change-phone':
            final phone = settings.arguments is String ? settings.arguments as String : null;
            return MaterialPageRoute(
              builder: (_) => ChangePhonePage(currentPhone: phone),
            );
          case '/change-password':
            return MaterialPageRoute(
              builder: (_) => const ChangePasswordPage(),
            );
          case '/privacy-policy':
            return MaterialPageRoute(
              builder: (_) => const PrivacyPolicyPage(),
            );
          case '/user-agreement':
            return MaterialPageRoute(
              builder: (_) => const UserAgreementPage(),
            );
          case '/shared-image':
            final imagePath = settings.arguments is String ? settings.arguments as String : null;
            return MaterialPageRoute(
              builder: (_) => SharedImageHandler(initialImagePath: imagePath),
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },
    );
  }
}
