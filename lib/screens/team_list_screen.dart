import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/hotel_models.dart';
import '../providers/hotel_provider.dart';
import 'add_staff_screen.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SfColors.darkBgBase : SfColors.lightBgBase;
    final textPrimary = isDark ? SfColors.darkTextPrimary : SfColors.lightTextPrimary;
    final textMuted = isDark ? SfColors.darkTextMuted : SfColors.lightTextMuted;

    final hotelProvider = Provider.of<HotelProvider>(context);
    final hotelId = hotelProvider.selectedHotel?.id;
    final currentUserRole = hotelProvider.currentUser?.role ?? '';

    if (hotelId == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: SfColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Mon Équipe', style: GoogleFonts.inter(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text("Hôtel introuvable", style: GoogleFonts.inter(color: textMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: SfColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mon Équipe',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('hotelId', isEqualTo: hotelId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Erreur de chargement", style: GoogleFonts.inter(color: textMuted)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: SfColors.gold));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text("Aucun membre trouvé", style: GoogleFonts.inter(color: textMuted)),
            );
          }

          final Map<String, List<DocumentSnapshot>> grouped = {
            'Directeurs': [],
            'Superviseurs': [],
            'Staff & Ouvriers': [],
          };

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'] ?? '';
            if (role.contains('Directeur')) {
              grouped['Directeurs']!.add(doc);
            } else if (role == 'Superviseur') {
              grouped['Superviseurs']!.add(doc);
            } else {
              grouped['Staff & Ouvriers']!.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              if (grouped['Directeurs']!.isNotEmpty)
                _buildSection('Directeurs', grouped['Directeurs']!, isDark, textPrimary, textMuted),
              if (grouped['Superviseurs']!.isNotEmpty)
                _buildSection('Superviseurs', grouped['Superviseurs']!, isDark, textPrimary, textMuted),
              if (grouped['Staff & Ouvriers']!.isNotEmpty)
                _buildSection('Staff & Ouvriers', grouped['Staff & Ouvriers']!, isDark, textPrimary, textMuted),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SfColors.gold,
        foregroundColor: Colors.black,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddStaffScreen(currentUserRole: currentUserRole),
            ),
          );
        },
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Widget _buildSection(String title, List<DocumentSnapshot> users, bool isDark, Color textPrimary, Color textMuted) {
    final cardBg = isDark ? SfColors.darkBgCard : SfColors.lightBgCard;
    final border = isDark ? SfColors.darkBorder : SfColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...users.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final first = data['firstName'] ?? '';
            final last = data['lastName'] ?? '';
            final name = '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : data['email'] ?? 'Inconnu';
            final role = data['role'] ?? '';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: SfColors.gold.withOpacity(0.15),
                  child: Icon(LucideIcons.user, color: SfColors.gold, size: 20),
                ),
                title: Text(
                  name,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  role,
                  style: GoogleFonts.inter(
                    color: SfColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
