import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/family_members/views/home_screen.dart';
import '../features/family_members/views/add_edit_member_screen.dart';
import '../features/family_members/views/member_details_screen.dart';
import '../features/folders/views/folder_details_screen.dart';
import '../features/settings/views/settings_screen.dart';
import '../features/search/views/search_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    // ============================================================
    // HOME
    // ============================================================

    GoRoute(
      path: '/',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        return const HomeScreen();
      },
    ),

    // ============================================================
    // SEARCH
    // ============================================================

    GoRoute(
      path: '/search',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        return const SearchScreen();
      },
    ),

    // ============================================================
    // SETTINGS
    // ============================================================

    GoRoute(
      path: '/settings',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        return const SettingsScreen();
      },
    ),

    // ============================================================
    // ADD FAMILY MEMBER
    // ============================================================

    GoRoute(
      path: '/add-member',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        return const AddEditMemberScreen();
      },
    ),

    // ============================================================
    // MEMBER DETAILS
    // ============================================================

    GoRoute(
      path: '/member/:id',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        final id = state.pathParameters['id']!;

        return MemberDetailsScreen(
          memberId: id,
        );
      },
    ),

    // ============================================================
    // EDIT MEMBER
    // ============================================================

    GoRoute(
      path: '/member/:id/edit',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        final id = state.pathParameters['id']!;

        return AddEditMemberScreen(
          memberId: id,
        );
      },
    ),

    // ============================================================
    // FOLDER DETAILS
    // ============================================================

    GoRoute(
      path: '/member/:memberId/folder/:folderId',
      builder: (
        BuildContext context,
        GoRouterState state,
      ) {
        final memberId = state.pathParameters['memberId']!;

        final folderId = state.pathParameters['folderId']!;

        return FolderDetailsScreen(
          memberId: memberId,
          folderId: folderId,
        );
      },
    ),
  ],
);
