import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Language Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.home,
      routes: AppRouter.routes,
    );
  }
}
