import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/hotel_models.dart';
import '../providers/hotel_provider.dart';
import 'supervisor_dashboard.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  String _searchQuery = "";
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HotelProvider>(context);
    final user = provider.currentUser;
    final rooms = provider.rooms;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (user != null && user.role.contains('Superviseur')) {
      return const SupervisorDashboard();
    }

    List<Room> filteredRooms = rooms.where((room) {
      if (_searchQuery.isNotEmpty && !room.number.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("GESTION DES CHAMBRES",
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
        actions: [
          if (provider.isDirector && rooms.isEmpty)
            IconButton(
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.amber))
                  : const Icon(LucideIcons.plusCircle, color: Colors.amber),
              tooltip: "Définir les chambres",
              onPressed: () => _showCreateRoomsDialog(context, provider),
            ),
          if (provider.isDirector && rooms.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.plus, color: Colors.amber),
              tooltip: "Ajouter une chambre",
              onPressed: () => _showModernAddRoomBottomSheet(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Rechercher (ex: 205)",
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon:
                      const Icon(LucideIcons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),
          rooms.isEmpty && !_isGenerating
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                              color: Color(0xFF18181B), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.bedDouble,
                              size: 50, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Text("Aucune chambre disponible.",
                            style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 16),
                        if (provider.isDirector)
                          ElevatedButton.icon(
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text("Définir le nombre de chambres"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                _showCreateRoomsDialog(context, provider),
                          ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : 16, vertical: 10),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
                      children: filteredRooms
                          .map((room) => _buildRoomCard(context, provider,
                              room, user!, isDesktop))
                          .toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _showCreateRoomsDialog(BuildContext context, HotelProvider provider) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141417),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Nombre de chambres",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Combien de chambres possède votre hôtel ?",
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ex: 50",
                hintStyle: TextStyle(
                  color: Colors.white38,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Annuler",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              int? count = int.tryParse(controller.text.trim());
              if (count != null && count > 0) {
                Navigator.pop(ctx);
                setState(() => _isGenerating = true);
                await provider.generateDefaultRooms(count: count);
                if (mounted) {
                  setState(() => _isGenerating = false);
                }
              }
            },
            child: const Text("Valider", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Removed FloorExpandableSection logic
  Widget _buildRoomCard(BuildContext context, HotelProvider provider, Room room,
      HotelUser user, bool isDesktop) {
    bool isDirector = user.role == UserRoles.director;
    bool isReception = user.role.contains('Réception') ||
        user.role == UserRoles.receptionManager;

    String statusText;
    Color statusColor;

    switch (room.status) {
      case 'Vendu':
        statusText = "VENDU";
        statusColor = const Color(0xFFEF4444);
        break;
      case 'Checkout':
        statusText = "CHECKOUT";
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Service Full':
        statusText = "SRV FULL";
        statusColor = const Color(0xFF3730A3);
        break;
      case 'Service Normal':
        statusText = "SRV NORM";
        statusColor = const Color(0xFF0EA5E9);
        break;
      case 'Libre':
      default:
        statusText = "LIBRE";
        statusColor = const Color(0xFF10B981);
        break;
    }

    double cardWidth = isDesktop ? 160 : 155;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                room.number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Eurostile'),
              ),
              InkWell(
                onTap: isDirector
                    ? () => provider.updateRoomType(
                        room.id, room.type == 'King' ? 'Queen' : 'King')
                    : null,
                child: Row(
                  children: [
                    Icon(LucideIcons.crown, size: 12, color: Colors.amber[500]),
                    const SizedBox(width: 4),
                    Text(room.type,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ),

          if (isReception) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusLetterBtn(
                    letter: 'L',
                    color: const Color(0xFF10B981),
                    onTap: () => provider.updateRoomStatus(room.id, 'Libre')),
                _statusLetterBtn(
                    letter: 'V',
                    color: const Color(0xFFEF4444),
                    onTap: () => provider.updateRoomStatus(room.id, 'Vendu')),
                _statusLetterBtn(
                    letter: 'C',
                    color: const Color(0xFFF59E0B),
                    onTap: () =>
                        provider.updateRoomStatus(room.id, 'Checkout')),
                _statusLetterBtn(
                    letter: 'F',
                    color: const Color(0xFF3730A3),
                    onTap: () =>
                        provider.updateRoomStatus(room.id, 'Service Full')),
                _statusLetterBtn(
                    letter: 'N',
                    color: const Color(0xFF0EA5E9),
                    onTap: () =>
                        provider.updateRoomStatus(room.id, 'Service Normal')),
              ],
            )
          ],

          if (isDirector)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF141417),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text("Supprimer la chambre ?",
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                            "Êtes-vous sûr de vouloir supprimer la chambre ${room.number} ?",
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Annuler",
                                style: TextStyle(color: Colors.white60)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              provider.deleteRoom(room.id);
                            },
                            child: const Text("Supprimer",
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(LucideIcons.trash2,
                      size: 16, color: Color(0xFFEF4444)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusLetterBtn(
      {required String letter,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showModernAddRoomBottomSheet(
      BuildContext context, HotelProvider provider) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B).withValues(alpha: 0.95),
                border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: const Icon(LucideIcons.plus,
                              color: Colors.amber, size: 24)),
                      const SizedBox(width: 16),
                      const Text("AJOUTER UNE CHAMBRE",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05))),
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "Numéro (ex: 205)",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon:
                            const Icon(LucideIcons.hash, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          provider.addRoom(controller.text, 'Général');
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text("CRÉER LA CHAMBRE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Rename floor dialog removed since floors are no longer displayed
}
