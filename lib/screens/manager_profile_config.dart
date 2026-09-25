import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ---------------------------------------------------------------------------
// Individual role option
// ---------------------------------------------------------------------------
class ManagerProfileOption {
  const ManagerProfileOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.opensHotelSelection,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool opensHotelSelection;
}

// ---------------------------------------------------------------------------
// Domain (universe) – Step 1 of the onboarding flow
// ---------------------------------------------------------------------------
class UniverseDomain {
  const UniverseDomain({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.roles,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ManagerProfileOption> roles;
}

// ---------------------------------------------------------------------------
// All profile options (flat list, used by legacy flows & navigation)
// ---------------------------------------------------------------------------
const List<ManagerProfileOption> kManagerProfileOptions = [
  ManagerProfileOption(
    value: 'hotel_manager',
    label: "Directeur d'Hôtel",
    subtitle: 'Gestion hôtelière & équipes de service',
    icon: LucideIcons.hotel,
    opensHotelSelection: true,
  ),
  ManagerProfileOption(
    value: 'building_manager',
    label: "Directeur de Résidence",
    subtitle: "Résidences hôtelières & appart-hôtels",
    icon: LucideIcons.building2,
    opensHotelSelection: false,
  ),
  ManagerProfileOption(
    value: 'rental_building',
    label: 'Gestionnaire d\'immeuble',
    subtitle: 'Syndic, copropriétés & maintenance générale',
    icon: LucideIcons.keyRound,
    opensHotelSelection: false,
  ),
  ManagerProfileOption(
    value: 'villa_owner',
    label: 'Propriétaire de Villa',
    subtitle: 'Villas individuelles, condos & hébergements de prestige',
    icon: LucideIcons.home,
    opensHotelSelection: false,
  ),
  ManagerProfileOption(
    value: 'apartment_condo_owner',
    label: 'Appartement & Condo',
    subtitle: 'Appartements, copropriétés & gestion privée',
    icon: LucideIcons.building,
    opensHotelSelection: false,
  ),
];

// ---------------------------------------------------------------------------
// Domain catalogue – Step 1 of the universe-selection onboarding
// ---------------------------------------------------------------------------
const List<UniverseDomain> kUniverseDomains = [
  UniverseDomain(
    id: 'hospitality',
    title: 'Hôtellerie & Hébergement',
    subtitle: 'Hôtels, résidences & complexes touristiques',
    icon: LucideIcons.hotel,
    roles: [
      ManagerProfileOption(
        value: 'hotel_manager',
        label: "Directeur d'Hôtel",
        subtitle: 'Gestion hôtelière & équipes de service',
        icon: LucideIcons.hotel,
        opensHotelSelection: true,
      ),
      ManagerProfileOption(
        value: 'building_manager',
        label: 'Directeur de Résidence',
        subtitle: "Résidences hôtelières & appart-hôtels",
        icon: LucideIcons.building2,
        opensHotelSelection: false,
      ),
    ],
  ),
  UniverseDomain(
    id: 'real_estate',
    title: 'Immobilier & Copropriété',
    subtitle: 'Immeubles résidentiels, locatifs & bureaux',
    icon: LucideIcons.building2,
    roles: [
      ManagerProfileOption(
        value: 'rental_building',
        label: "Gestionnaire d'immeuble",
        subtitle: 'Syndic, copropriétés & maintenance générale',
        icon: LucideIcons.keyRound,
        opensHotelSelection: false,
      ),
      ManagerProfileOption(
        value: 'rental_building_locatif',
        label: 'Immeuble Locatif',
        subtitle: 'Gestion locative & multi-logements',
        icon: LucideIcons.home,
        opensHotelSelection: false,
      ),
    ],
  ),
  UniverseDomain(
    id: 'villas',
    title: 'Villas & Résidences Privées',
    subtitle: 'Villas individuelles, condos & hébergements de prestige',
    icon: LucideIcons.home,
    roles: [
      ManagerProfileOption(
        value: 'villa_owner',
        label: 'Propriétaire de Villa',
        subtitle: 'Villas individuelles, condos & hébergements de prestige',
        icon: LucideIcons.home,
        opensHotelSelection: false,
      ),
      ManagerProfileOption(
        value: 'apartment_condo_owner',
        label: 'Appartement & Condo',
        subtitle: 'Appartements, copropriétés & gestion privée',
        icon: LucideIcons.building,
        opensHotelSelection: false,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
ManagerProfileOption? managerProfileOptionByValue(String? value) {
  if (value == null) return null;
  // Normalise alias
  final v = value == 'rental_building_locatif' ? 'rental_building' : value;
  for (final option in kManagerProfileOptions) {
    if (option.value == v) return option;
  }
  return null;
}

String? legacyDirectorTypeToValue(String? legacyType) {
  switch (legacyType) {
    case 'Directeur d\'Hôtel':
      return 'hotel_manager';
    case 'Directeur de Résidence':
      return 'building_manager';
    case 'Propriétaire de Villa':
      return 'villa_owner';
    case 'Propriétaire d\'Appartement':
      return 'apartment_condo_owner';
    default:
      return null;
  }
}

String? resolveManagerProfileValue(Map<String, dynamic>? data) {
  if (data == null) return null;
  final String? profileType = data['propertyProfileType'] as String?;
  if (profileType != null && profileType.isNotEmpty) {
    return profileType;
  }
  final String? legacyType = data['directorType'] as String?;
  return legacyDirectorTypeToValue(legacyType);
}

String resolveManagerProfileLabel(
  Map<String, dynamic>? data,
  String profileValue,
) {
  final String? label = data?['propertyProfileLabel'] as String?;
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return managerProfileOptionByValue(profileValue)?.label ?? profileValue;
}
