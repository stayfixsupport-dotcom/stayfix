import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'condo_dashboard_screen.dart';
import 'director_type_screen.dart';
import 'immeuble_dashboard.dart';
import 'manager_profile_config.dart';
import 'other_property_dashboard.dart';
import 'orders/order_hub_screen.dart';
import 'terms_screen.dart';
import '../services/app_session_service.dart';
import '../models/hotel_models.dart';
import '../services/property_scope_service.dart';
import '../services/push_notification_service.dart';

Future<Widget> resolveManagerDestination() async {
  final authUser = FirebaseAuth.instance.currentUser;
  final userId = authUser?.uid ?? AppSessionService.currentUserId;
  
  if (userId == null || userId.isEmpty) {
    return const DirectorTypeScreen();
  }

  return resolveSessionDestination(userId);
}

Future<Widget> resolveSessionDestination(String userId) async {
  if (userId.trim().isEmpty) {
    return const DirectorTypeScreen();
  }

  final doc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final data = doc.data();
  if (data == null) {
    return const DirectorTypeScreen();
  }
  AppSessionService.setCurrentUser(userId: userId, data: data);
  unawaited(PushNotificationService.saveTokenForUser(userId));
  if (PropertyScopeService.isStayFixJobOnly(data) ||
      PropertyScopeService.isDisabled(data)) {
    return const AuthScreen();
  }
  final bool acceptedTerms = data['termsAccepted'] == true;
  if (!acceptedTerms) {
    return const TermsScreen();
  }
  final String? profileValue = resolveManagerProfileValue(data);

  final accountType = (data['accountType'] as String?)?.trim().toLowerCase();
  if (accountType == 'apartment_account' || accountType == 'apartment_manager') {
    return CondoDashboardScreen(
      propertyType: 'apartment_condo_owner',
      accessRole: accountType,
    );
  }
  if (accountType == 'manager' || accountType == 'concierge') {
    return ImmeubleDashboardScreen(
      propertyType: 'building_manager',
      accessRole: accountType,
    );
  }

  // Sub-directors (Directeur Gouvernante / Maintenance / Réception) and
  // supervisors are assigned to a hotel by the main Director — they never
  // go through the universe-selection onboarding. Route them to OrderHubScreen.
  final role = (data['role'] as String?)?.trim() ?? '';
  const subDirectorRoles = {
    UserRoles.housekeepingManager, // 'Directeur Gouvernante'
    UserRoles.maintenanceManager,  // 'Directeur Maintenance'
    UserRoles.receptionManager,    // 'Directeur Réception'
  };
  if (subDirectorRoles.contains(role) || role.startsWith(UserRoles.supervisor)) {
    return const OrderHubScreen();
  }

  if (profileValue == null) {
    return const DirectorTypeScreen();
  }

  // Hotel manager → DashboardScreen (bypass SelectionScreen)
  if (profileValue == 'hotel_manager') {
    return const OrderHubScreen();
  }

  if (profileValue == 'apartment_condo_owner' ||
      profileValue == 'villa_owner') {
    return CondoDashboardScreen(propertyType: profileValue);
  }

  if (profileValue == 'building_manager' || profileValue == 'rental_building') {
    return ImmeubleDashboardScreen(propertyType: profileValue);
  }

  final label = resolveManagerProfileLabel(data, profileValue);
  return OtherPropertyDashboard(propertyType: label);
}
