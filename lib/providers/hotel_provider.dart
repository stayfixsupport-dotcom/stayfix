import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/firebase_options.dart';
import '../core/manager_session_guard.dart';
import '../models/hotel_models.dart';
import '../services/app_session_service.dart';
import '../services/property_scope_service.dart';
import '../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AccountDeletionResult {
  const AccountDeletionResult._({
    required this.success,
    required this.message,
    this.requiresPassword = false,
  });

  const AccountDeletionResult.success(String message)
      : this._(success: true, message: message);

  const AccountDeletionResult.failure(
    String message, {
    bool requiresPassword = false,
  }) : this._(
          success: false,
          message: message,
          requiresPassword: requiresPassword,
        );

  final bool success;
  final String message;
  final bool requiresPassword;
}

class HotelProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HotelUser? _currentUser;
  Hotel? _selectedHotel;

  StreamSubscription<QuerySnapshot>? _roomsSubscription;
  StreamSubscription<QuerySnapshot>? _hotelsSubscription;

  List<Hotel> _myHotels = [];
  List<HotelUser> _hotelStaff = [];
  List<Room> _rooms = [];

  bool _isLoading = false;
  bool _isCreatingHotel = false; // Guard to prevent duplicate hotel creation
  String? _lastAuthErrorMessage;
  bool _lastAuthCreatedAccount = false;

  HotelUser? get currentUser => _currentUser;
  Hotel? get selectedHotel => _selectedHotel;
  List<Hotel> get myHotels => _myHotels;
  List<HotelUser> get hotelStaff => _hotelStaff;
  bool get isLoading => _isLoading;
  String? get lastAuthErrorMessage => _lastAuthErrorMessage;
  bool get lastAuthCreatedAccount => _lastAuthCreatedAccount;

  List<Room> get rooms {
    final uniqueRoomsMap = {for (var room in _rooms) room.number: room};
    List<Room> sortedRooms = uniqueRoomsMap.values.toList();
    sortedRooms.sort((a, b) => a.numberAsInt.compareTo(b.numberAsInt));
    return sortedRooms;
  }

  bool get isDirector {
    if (_currentUser == null) return false;
    final r = _currentUser!.role.toLowerCase();
    if (r == UserRoles.director.toLowerCase() ||
        r == UserRoles.maintenanceManager.toLowerCase() ||
        r == UserRoles.housekeepingManager.toLowerCase() ||
        r == UserRoles.receptionManager.toLowerCase() ||
        r == 'director' || r == 'directeur' || r == 'admin') {
      return true;
    }
    return false;
  }

  /// Returns the best-available hotel name for the currently logged-in user.
  /// Works for both hotel directors (selectedHotel is set) and sub-managers
  /// (selectedHotel is null but the hotel is loaded via myHotels / hotelId).
  String get currentHotelName {
    if (_selectedHotel != null) return _selectedHotel!.name;
    if (_myHotels.isNotEmpty) return _myHotels.first.name;
    return 'Hôtel';
  }

  Set<String> get currentAuthProviders =>
      _auth.currentUser?.providerData
          .map((provider) => provider.providerId)
          .where((provider) => provider.trim().isNotEmpty)
          .toSet() ??
      <String>{};

  HotelProvider() {
    // tryAutoLogin() is called explicitly by SplashPage._resolveNextScreen()
    // to avoid duplicate Firestore reads on startup.
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setAuthError(String? message) {
    _lastAuthErrorMessage = message;
  }

  void _setLastAuthCreatedAccount(bool value) {
    _lastAuthCreatedAccount = value;
  }

  // --- Session Management ---
  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedUserId = prefs.getString('userId');
      final bool savedIsDirector = prefs.getBool('isDirector') ?? false;
      final authUser = _auth.currentUser;

      if (savedUserId != null && savedUserId.isNotEmpty) {
        // Director accounts use Firebase Auth — verify the session is intact.
        if (savedIsDirector) {
          if (authUser == null || authUser.uid.trim() != savedUserId.trim()) {
            await logout();
            return;
          }
        }
        // For Firebase-Auth accounts that are NOT the Director Général
        // (e.g. sub-directors and supervisors created via addStaffMember),
        // the Firebase Auth session may still be alive. Validate that the
        // live Firebase Auth UID matches the saved userId. If there is a
        // Firebase Auth session for a DIFFERENT account, sign it out so we
        // don't accidentally expose cross-account data.
        if (!savedIsDirector && authUser != null &&
            authUser.uid.trim() != savedUserId.trim()) {
          // Mismatch: a different account is signed in to Firebase Auth.
          // Sign it out so subsequent logins start clean.
          try { await _auth.signOut(); } catch (_) {}
        } else if (!savedIsDirector && authUser != null &&
            authUser.uid.trim() == savedUserId.trim()) {
          // Firebase Auth session is intact for a non-director Firebase account.
          // Update prefs so the next cold-start also validates correctly.
          await _saveSession(savedUserId, isDirector: false);
        }

        // If there is a live Firebase Auth session, resolve the best-ranked
        // document by email BEFORE loading anything.  This prevents loading
        // a stale Staff doc (with appAccess='stayfix_job') and immediately
        // logging out due to the scope check below.
        String resolvedId = savedUserId;
        final liveAuthUser = _auth.currentUser;
        if (liveAuthUser != null) {
          try {
            final email = liveAuthUser.email ?? '';
            if (email.isNotEmpty) {
              final emailQuery = await _firestore
                  .collection('users')
                  .where('email', isEqualTo: email.trim())
                  .get();
              if (emailQuery.docs.isNotEmpty) {
                resolvedId = _pickBestUserDoc(emailQuery.docs).id;
              }
            }
          } catch (_) {
            // Email query failed — keep savedUserId as fallback.
          }
        }

        await _fetchUserData(resolvedId);

        // If the resolved doc is different from what was saved, update the
        // persisted session so the next cold-start uses the correct ID.
        if (resolvedId != savedUserId && _currentUser != null) {
          await _saveSession(resolvedId,
              isDirector: _currentUser?.role == UserRoles.director);
        }

        if (_currentUser != null) {
          // For the Director Général, listenToMyHotels() auto-selects their hotel
          // via the ownerId index.  For every other role (sub-director, supervisor,
          // staff) the hotel is referenced directly via hotelId.
          if (_currentUser!.role == UserRoles.director) {
            listenToMyHotels();
          } else if (_currentUser!.hotelId != null &&
              _currentUser!.hotelId!.isNotEmpty) {
            await _fetchHotelById(_currentUser!.hotelId!);
            listenToHotelData();
          } else {
            // Fall back: also try listenToMyHotels in case this account
            // somehow owns a hotel.
            listenToMyHotels();
          }
        } else {
          await logout();
        }
      }
    } catch (e) {
      debugPrint("AutoLogin Error: $e");
    }
  }

  Future<bool> login(String input, String password) async {
    try {
      _setAuthError(null);
      _setLastAuthCreatedAccount(false);
      _currentUser = null;
      _selectedHotel = null;

      if (input.contains('@')) {
        try {
          // Sign out any stale Firebase Auth session before signing in.
          // This prevents a previous account's cached data from leaking into
          // the new session when the provider is re-used across logins.
          try { await _auth.signOut(); } catch (_) {}

          UserCredential cred = await _auth.signInWithEmailAndPassword(
              email: input, password: password);
          // Firebase Auth succeeded — this is a Director or a Firebase-Auth
          // sub-director / supervisor account.
          // IMPORTANT: Always resolve the highest-ranked document by email
          // BEFORE loading any user data.  Loading by UID first risks picking
          // up an old "Staff" document (created before the account was promoted)
          // that has appAccess='stayfix_job', which triggers an immediate logout.
          //
          // Strategy:
          //   1. Query all docs with this email, pick the best-ranked one.
          //   2. If the query succeeds, load that doc.
          //   3. Only fall back to UID-based loading if the query fails entirely.
          String resolvedDocId = cred.user!.uid;
          try {
            final emailQuery = await _firestore
                .collection('users')
                .where('email', isEqualTo: input.trim())
                .get();
            if (emailQuery.docs.isNotEmpty) {
              resolvedDocId = _pickBestUserDoc(emailQuery.docs).id;
            }
          } catch (_) {
            // Email query failed — fall back to UID doc.
          }
          await _fetchUserData(resolvedDocId);

          if (PropertyScopeService.isStayFixJobOnly(
                  AppSessionService.currentUserData) ||
              PropertyScopeService.isDisabled(
                  AppSessionService.currentUserData)) {
            await logout();
            return false;
          }

          // If still no user doc found, auth succeeded but there is no profile.
          if (_currentUser == null) {
            await _auth.signOut();
            return false;
          }

          final isDir = _currentUser?.role == UserRoles.director;
          // Always save using the Firebase Auth UID so tryAutoLogin can
          // cross-validate the Firebase Auth session on next cold start.
          await _saveSession(cred.user!.uid, isDirector: isDir);

          if (isDir) {
            // Director Général: hotels are indexed by ownerId.
            listenToMyHotels();
          } else {
            // Sub-directors (Dir. Maintenance / Gouvernante / Réception) and
            // supervisors created via addStaffMember have a hotelId field that
            // points directly to the hotel they belong to.
            final hotelId = _currentUser?.hotelId;
            if (hotelId != null && hotelId.isNotEmpty) {
              await _fetchHotelById(hotelId);
              listenToHotelData();
            } else {
              // Fallback: try the ownerId index in case this account also owns
              // a hotel (e.g. legacy setups).
              listenToMyHotels();
            }
          }
          return true;
        } on FirebaseAuthException catch (_) {
          // Firebase Auth failed (wrong password, user not found) — try staff login.
          return await _loginAsStaff(
              field: 'email', value: input, password: password);
        } catch (e) {
          // Data loading error after successful auth — don't fall through to staff.
          debugPrint("Post-auth data error: $e");
          return false;
        }
      } else {
        return await _loginAsStaff(
            field: 'username', value: input, password: password);
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

  Future<bool> _loginAsStaff(
      {required String field,
      required String value,
      required String password}) async {
    try {
      // Fetch ALL docs matching this credential pair (email or username +
      // password) and pick the one with the most privileged role. This prevents
      // loading an old plain-Staff doc when the user has been promoted and a
      // newer Director/sub-director doc with the same email also exists.
      final snapshot = await _firestore
          .collection('users')
          .where(field, isEqualTo: value)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = _pickBestUserDoc(snapshot.docs);
        await _fetchUserData(doc.id);
        if (PropertyScopeService.isStayFixJobOnly(
                AppSessionService.currentUserData) ||
            PropertyScopeService.isDisabled(
                AppSessionService.currentUserData)) {
          await logout();
          return false;
        }
        await _saveSession(doc.id);

        if (_currentUser!.hotelId != null) {
          await _fetchHotelById(_currentUser!.hotelId!);
          listenToHotelData();
        }
        return true;
      }
    } catch (e) {
      debugPrint("Staff Login Error: $e");
    }
    return false;
  }

  /// Picks the Firestore document with the most privileged role from a list.
  /// Prevents loading an old plain-Staff doc when a Director or sub-director
  /// doc with the same email/username also exists in Firestore.
  QueryDocumentSnapshot<Map<String, dynamic>> _pickBestUserDoc(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    const roleRank = {
      UserRoles.director: 6,
      UserRoles.maintenanceManager: 5,
      UserRoles.housekeepingManager: 5,
      UserRoles.receptionManager: 5,
      UserRoles.supervisor: 4,
      UserRoles.houseman: 3,
      UserRoles.housekeeping: 2,
      UserRoles.staff: 1,
    };

    return docs.reduce((best, doc) {
      final bestRole = (best.data()['role'] as String?) ?? '';
      final docRole = (doc.data()['role'] as String?) ?? '';
      final bestRank = roleRank[bestRole] ?? 0;
      final docRank = roleRank[docRole] ?? 0;
      return docRank > bestRank ? doc : best;
    });
  }

  Future<void> _saveSession(String userId, {bool isDirector = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setBool('isDirector', isDirector);
  }

  Future<void> logout() async {
    _lastAuthErrorMessage = null;
    _setLastAuthCreatedAccount(false);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
    } catch (e) {
      debugPrint('Logout prefs error: $e');
    }

    ManagerSessionGuard.reset();
    _roomsSubscription?.cancel();
    _hotelsSubscription?.cancel();
    AppSessionService.clear();
    _currentUser = null;
    _selectedHotel = null;
    _rooms = [];
    _myHotels = [];
    _hotelStaff = [];
    _isCreatingHotel = false;

    notifyListeners();

    try {
      await PushNotificationService.removeTokenForCurrentUser();
    } catch (_) {}

    try {
      final googleSignIn = _buildGoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google SignOut error: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Logout signOut error: $e');
    }
  }

  void setHotel(Hotel? hotel) {
    _selectedHotel = hotel;
    _rooms = [];
    _roomsSubscription?.cancel();
    if (hotel != null) {
      // listenToHotelData() calls fetchHotelStaff() internally — no need to call it here too
      listenToHotelData();
    }
    notifyListeners();
  }

  void listenToHotelData() {
    if (_selectedHotel == null) return;
    _roomsSubscription?.cancel();
    _roomsSubscription = _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .snapshots()
        .listen((snapshot) {
      _rooms =
          snapshot.docs.map((doc) => Room.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
    fetchHotelStaff();
  }

  void listenToMyHotels() {
    if (_currentUser == null) return;
    _hotelsSubscription?.cancel();
    _hotelsSubscription = _firestore
        .collection('hotels')
        .where('ownerId', isEqualTo: _currentUser!.id)
        .snapshots()
        .listen((snapshot) {
      _myHotels = snapshot.docs.map((doc) {
        final data = doc.data();
        return Hotel(
          id: doc.id,
          groupId: data['groupId'] ?? '',
          name: data['name'] ?? '',
          location: data['location'] ?? '',
          ownerId: data['ownerId'] ?? '',
        );
      }).toList();
      
      // Auto-select the first hotel to bypass the SelectionScreen
      if (_selectedHotel == null && _myHotels.isNotEmpty) {
        _selectedHotel = _myHotels.first;
        // listenToHotelData() calls fetchHotelStaff() internally — no extra call needed
        listenToHotelData();
      } else if (_myHotels.isEmpty && _currentUser?.role == UserRoles.director) {
        // Guard prevents duplicate hotel creation on slow-network multi-fire events
        if (!_isCreatingHotel) {
          _isCreatingHotel = true;
          createHotel('Mon Hôtel', 'N/A', skipRooms: true).then((_) => _isCreatingHotel = false);
        }
      }
      
      notifyListeners();
    });
  }

  Future<void> fetchMyHotels() async {
    listenToMyHotels();
  }

  Future<void> updateRoomStatus(String roomId, String newStatus) async {
    if (_selectedHotel == null) return;
    await _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .doc(roomId)
        .update({'status': newStatus});
  }

  Future<void> updateRoomType(String roomId, String newType) async {
    if (_selectedHotel == null) return;
    await _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .doc(roomId)
        .update({'type': newType});
  }

  Future<void> deleteRoom(String roomId) async {
    if (_selectedHotel == null) return;
    await _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .doc(roomId)
        .delete();
  }

  Future<void> addRoom(String number, String floor) async {
    if (_selectedHotel == null) return;
    await _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .add({
      'number': number,
      'status': 'Libre',
      'type': 'King',
      'floor': floor,
    });
  }

  Future<void> renameFloor(String oldFloorName, String newFloorName) async {
    if (_selectedHotel == null) return;
    var snapshot = await _firestore
        .collection('hotels')
        .doc(_selectedHotel!.id)
        .collection('rooms')
        .where('floor', isEqualTo: oldFloorName)
        .get();
    WriteBatch batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'floor': newFloorName});
    }
    await batch.commit();
  }

  Future<void> createHotel(String name, String location, {bool skipRooms = true}) async {
    if (_currentUser == null) return;
    setLoading(true);
    try {
      DocumentReference docRef = await _firestore.collection('hotels').add({
        'name': name,
        'location': location,
        'ownerId': _currentUser!.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Write the hotel ID back to the director's user document so that
      // hotel-scoped features (messaging filters, staff visibility, etc.)
      // can find the director's hotel via the hotelId field.
      await _firestore.collection('users').doc(_currentUser!.id).set(
        {'hotelId': docRef.id},
        SetOptions(merge: true),
      );
      // Also update the in-memory user so it's immediately available.
      _currentUser = HotelUser(
        id: _currentUser!.id,
        email: _currentUser!.email,
        firstName: _currentUser!.firstName,
        lastName: _currentUser!.lastName,
        username: _currentUser!.username,
        role: _currentUser!.role,
        phone: _currentUser!.phone,
        hotelId: docRef.id,
      );
      // By default skip room creation so hotels start with 0 rooms.
      // Rooms can be generated on-demand when the user clicks the room button.
      if (!skipRooms) {
        await _generateDefaultRoomsForId(docRef.id);
      }
    } catch (e) {
      debugPrint("Error creating hotel: $e");
    } finally {
      setLoading(false);
    }
  }


  Future<void> _generateDefaultRoomsForId(String hotelId) async {
    WriteBatch batch = _firestore.batch();
    void add(int number) {
      DocumentReference ref = _firestore
          .collection('hotels')
          .doc(hotelId)
          .collection('rooms')
          .doc();
      int floorNum = (number / 100).floor();
      String floorName = "Etage $floorNum";
      batch.set(ref, {
        'number': number.toString(),
        'status': 'Libre',
        'type': 'King',
        'floor': floorName,
      });
    }

    for (int i = 200; i <= 556; i++) {
      add(i);
    }
    List<int> startPoints = [700, 800, 900, 1000, 1100, 1200, 1300, 1400];
    for (int start in startPoints) {
      for (int i = start; i <= start + 13; i++) {
        add(i);
      }
    }
    await batch.commit();
  }

  Future<void> _generateCustomRoomsForId(String hotelId, int count) async {
    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    for (int i = 1; i <= count; i++) {
      DocumentReference ref = _firestore
          .collection('hotels')
          .doc(hotelId)
          .collection('rooms')
          .doc();
          
      batch.set(ref, {
        'number': i.toString(),
        'status': 'Libre',
        'type': 'King',
        'floor': 'Général',
      });
      
      opCount++;

      // Commit and reset batch every 400 operations to stay below Firestore's 500 limit
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<void> generateDefaultRooms({int? count}) async {
    if (_selectedHotel != null) {
      setLoading(true);
      if (count != null && count > 0) {
        await _generateCustomRoomsForId(_selectedHotel!.id, count);
      } else {
        await _generateDefaultRoomsForId(_selectedHotel!.id);
      }
      setLoading(false);
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        AppSessionService.setCurrentUser(userId: doc.id, data: data);
        _currentUser = HotelUser(
          id: doc.id,
          email: data['email'] ?? '',
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          username: data['username'] ?? '',
          role: data['role'] ?? 'Staff',
          phone: data['phone'] ?? '',
          hotelId: data['hotelId'],
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _fetchHotelById(String hotelId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('hotels').doc(hotelId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _selectedHotel = Hotel(
          id: doc.id,
          groupId: data['groupId'] ?? '',
          name: data['name'] ?? '',
          location: data['location'] ?? '',
          ownerId: data['ownerId'] ?? '',
        );
      }
    } catch (e) {
      debugPrint("Error fetching hotel: $e");
    }
  }

  Future<void> fetchHotelStaff() async {
    final String? hotelId = _selectedHotel?.id ?? _currentUser?.hotelId;
    if (hotelId == null || hotelId.isEmpty) return;
    try {
      var snapshot = await _firestore
          .collection('users')
          .where('hotelId', isEqualTo: hotelId)
          .get();
      _hotelStaff = snapshot.docs.map((doc) {
        final data = doc.data();
        return HotelUser(
          id: doc.id,
          email: data['email'] ?? '',
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          username: data['username'] ?? '',
          role: data['role'] ?? 'Staff',
          phone: data['phone'] ?? '',
          hotelId: data['hotelId'],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching staff: $e");
    }
  }

  Future<void> deleteHotel(String id) async {
    await _firestore.collection('hotels').doc(id).delete();
  }

  Future<bool> loginWithGoogle() async {
    try {
      _setAuthError(null);
      _setLastAuthCreatedAccount(false);
      final GoogleSignIn googleSignIn = _buildGoogleSignIn();
      // Sign out first so the account picker is always shown,
      // even when a previous session is still cached.
      await googleSignIn.disconnect().catchError((_) => null);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) return false;

      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      final bool uidProfileExists = doc.exists;
      bool createdAccount =
          userCredential.additionalUserInfo?.isNewUser == true ||
              !uidProfileExists;

      if (!uidProfileExists) {
        // The Google Auth UID has no Firestore profile yet.
        // Check if a profile was pre-created for this email (e.g. via
        // addStaffMember which used the email/password UID).
        final emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          // Existing sub-director / supervisor linking Google for the first time.
          // Migrate the profile to the new Google Auth UID.
          final existingDoc = emailQuery.docs.first;
          final existingData = existingDoc.data();
          final migBatch = _firestore.batch();
          migBatch.set(
            _firestore.collection('users').doc(user.uid),
            {
              ...existingData,
              'uid': user.uid,
              'email': user.email ?? existingData['email'],
              'googleLinkedAt': FieldValue.serverTimestamp(),
            },
          );
          if (existingDoc.id != user.uid) {
            migBatch.delete(
                _firestore.collection('users').doc(existingDoc.id));
          }
          await migBatch.commit();
          createdAccount = false; // Existing profile, not a brand-new account.
        } else {
          // Truly new account — create Director profile as usual.
          final String displayName = user.displayName ?? '';
          final List<String> names = displayName.split(' ');
          final String fName = names.isNotEmpty ? names.first : '';
          final String lName = names.length > 1 ? names.last : '';
          await _firestore.collection('users').doc(user.uid).set({
            'firstName': fName,
            'lastName': lName,
            'username': user.email?.split('@')[0] ?? '',
            'email': user.email ?? '',
            'role': UserRoles.director,
            'phone': '',
            'termsAccepted': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      _setLastAuthCreatedAccount(createdAccount);
      await _fetchUserData(user.uid);
      final isDir = _currentUser?.role == UserRoles.director;
      await _saveSession(user.uid, isDirector: isDir);

      if (createdAccount) {
        // skipRooms=true: avoid the 469-document batch write at sign-up time.
        await createHotel('Mon Hôtel', 'N/A', skipRooms: true);
      }

      // Director Général: hotels are indexed by ownerId.
      // Sub-directors / supervisors: hotel is referenced directly via hotelId.
      if (isDir || createdAccount) {
        listenToMyHotels();
      } else {
        final subHotelId = _currentUser?.hotelId;
        if (subHotelId != null && subHotelId.isNotEmpty) {
          await _fetchHotelById(subHotelId);
          listenToHotelData();
        } else {
          listenToMyHotels();
        }
      }
      return true;
    } on PlatformException catch (e) {
      _setAuthError(_googlePlatformErrorMessage(e));
      debugPrint('Google Login Error: $e');
      return false;
    } catch (e) {
      _setAuthError('Connexion Google impossible pour le moment.');
      debugPrint('Google Login Error: $e');
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      _setAuthError(null);
      _setLastAuthCreatedAccount(false);
      final UserCredential userCredential =
          await _signInToFirebaseWithAppleCredential();
      final User? user = userCredential.user;
      if (user == null) return false;
      final appleSignIn = _lastAppleOAuthPayload;
      if (appleSignIn == null) {
        throw FirebaseAuthException(
          code: 'missing-apple-token',
          message: 'Apple identity token missing.',
        );
      }

      final bool createdAccount = await _syncAppleUserProfile(
        user: user,
        userCredential: userCredential,
        appleSignIn: appleSignIn,
      );

      _setLastAuthCreatedAccount(createdAccount);
      await _fetchUserData(user.uid);
      final isDir = _currentUser?.role == UserRoles.director;
      await _saveSession(user.uid, isDirector: isDir);
      
      if (createdAccount) {
        // skipRooms=true: avoid the 469-document batch write at sign-up time.
        await createHotel('Mon Hôtel', 'N/A', skipRooms: true);
      }

      // Director Général: hotels are indexed by ownerId.
      // Sub-directors / supervisors: hotel is referenced directly via hotelId.
      if (isDir || createdAccount) {
        listenToMyHotels();
      } else {
        final subHotelId = _currentUser?.hotelId;
        if (subHotelId != null && subHotelId.isNotEmpty) {
          await _fetchHotelById(subHotelId);
          listenToHotelData();
        } else {
          listenToMyHotels();
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _setAuthError(_appleFirebaseErrorMessage(e));
      debugPrint('Apple Login Firebase Error: ${e.code} ${e.message}');
      return false;
    } on SignInWithAppleAuthorizationException catch (e) {
      _setAuthError(
        e.code == AuthorizationErrorCode.canceled
            ? 'Connexion Apple annulee.'
            : 'Connexion Apple impossible pour le moment.',
      );
      debugPrint('Apple Login Error: $e');
      return false;
    } catch (e) {
      _setAuthError('Connexion Apple impossible pour le moment.');
      debugPrint('Apple Login Error: $e');
      return false;
    }
  }

  Future<bool> registerDirector(
      {required String email,
      required String password,
      required String fullName,
      required String phone}) async {
    _lastAuthErrorMessage = null;
    try {
      UserCredential cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _lastAuthErrorMessage =
              'Cette adresse email est déjà utilisée. Veuillez vous connecter.';
          notifyListeners();
          return false;
        } else if (e.code == 'weak-password') {
          _lastAuthErrorMessage =
              'Le mot de passe doit contenir au moins 6 caractères.';
          notifyListeners();
          return false;
        } else if (e.code == 'invalid-email') {
          _lastAuthErrorMessage = 'Adresse email invalide.';
          notifyListeners();
          return false;
        } else {
          _lastAuthErrorMessage =
              e.message ?? "Erreur lors de l'inscription";
          notifyListeners();
          return false;
        }
      }

      if (cred.user == null) {
        _lastAuthErrorMessage = "Erreur lors de la création de l'utilisateur.";
        notifyListeners();
        return false;
      }

      try {
        await cred.user!.updateDisplayName(fullName.trim());
      } catch (_) {}

      final List<String> names = fullName.trim().split(RegExp(r'\s+'));
      final String fName = names.isNotEmpty ? names.first : fullName.trim();
      final String lName = names.length > 1 ? names.sublist(1).join(" ") : "";
      final String username =
          fullName.trim().isNotEmpty ? fullName.trim() : email.trim().split('@')[0];

      final newDirector = HotelUser(
        id: cred.user!.uid,
        email: email.trim(),
        firstName: fName,
        lastName: lName,
        username: username,
        role: UserRoles.director,
        phone: phone.trim(),
      );

      final Map<String, dynamic> userData = {
        'firstName': newDirector.firstName,
        'lastName': newDirector.lastName,
        'username': newDirector.username,
        'email': newDirector.email,
        'role': newDirector.role,
        'phone': newDirector.phone,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(userData, SetOptions(merge: true));

      _currentUser = newDirector;
      _setLastAuthCreatedAccount(true);
      AppSessionService.setCurrentUser(userId: cred.user!.uid, data: userData);
      // Save session as director so tryAutoLogin verifies Firebase Auth on next
      // launch and correctly loads the hotel (which populates _currentUser.hotelId).
      await _saveSession(cred.user!.uid, isDirector: true);

      // Automatically create a hotel for the new director.
      // skipRooms=true avoids writing 469 Firestore documents during sign-up,
      // which was the main cause of the long registration time.
      await createHotel('Mon Hôtel', 'N/A', skipRooms: true);

      // Re-fetch user data so _currentUser.hotelId is populated (createHotel
      // writes hotelId to Firestore) before we notify listeners. Without this
      // the OrderHubScreen sees hotel==null and never starts the order streams.
      await _fetchUserData(cred.user!.uid);

      listenToMyHotels();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("registerDirector Error: $e");
      _lastAuthErrorMessage = "Erreur lors de l'inscription";
      notifyListeners();
      return false;
    }
  }

  Future<void> addStaffMember(
      {required String firstName,
      required String lastName,
      required String email,
      required String phone,
      required String username,
      required String password,
      required String role,
      String? appAccess}) async {
    final String? hotelId = _selectedHotel?.id ?? _currentUser?.hotelId;
    if (hotelId == null || hotelId.isEmpty) {
      debugPrint('addStaffMember: cannot determine hotelId — aborting');
      return;
    }

    final userData = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password, // Stored for Firestore-password staff-login fallback
      'role': role,
      'hotelId': hotelId,
      'addedBy': _currentUser?.id,
      if (appAccess != null) 'appAccess': appAccess,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Use a secondary Firebase app to create the Firebase Auth account
    // without signing out the currently logged-in manager.
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'StaffAccount_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential userCred = await secondaryAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final String uid = userCred.user!.uid;

      // Write the Firestore user document keyed to the Firebase Auth UID so
      // the account can be fetched by uid on login.
      await _firestore.collection('users').doc(uid).set(userData);

      // Sign out the secondary auth session so it doesn't linger.
      await secondaryAuth.signOut();
    } catch (e) {
      debugPrint('addStaffMember: error creating Firebase Auth account — $e');
      // Re-throw so the caller (AddStaffScreen) can inform the user that the
      // account could not be created, instead of silently storing a broken
      // Firestore-only document that can never log in.
      rethrow;
    } finally {
      // Always clean up the secondary Firebase app instance.
      await secondaryApp?.delete();
    }

    fetchHotelStaff();
  }

  Future<bool> updateUserProfile(
      {String? email, String? username, String? password}) async {
    if (_currentUser == null) return false;
    try {
      Map<String, dynamic> updates = {};
      if (email != null && email.isNotEmpty) {
        updates['email'] = email;
      }
      if (username != null && username.isNotEmpty) {
        updates['username'] = username;
      }
      if (password != null && password.isNotEmpty) {
        updates['password'] = password;
      }

      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update(updates);
      _currentUser = HotelUser(
        id: _currentUser!.id,
        email: email ?? _currentUser!.email,
        firstName: _currentUser!.firstName,
        lastName: _currentUser!.lastName,
        username: username ?? _currentUser!.username,
        role: _currentUser!.role,
        phone: _currentUser!.phone,
        hotelId: _currentUser!.hotelId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<AccountDeletionResult> deleteCurrentAccount({
    String? currentPassword,
  }) async {
    final authUser = _auth.currentUser;
    final currentUser = _currentUser;
    if (authUser == null || currentUser == null) {
      return const AccountDeletionResult.failure(
        'Aucun compte connecte.',
      );
    }

    try {
      await _reauthenticateForSensitiveAction(
        user: authUser,
        currentPassword: currentPassword,
      );

      await _deleteCurrentUserFirestoreData(
        authUid: authUser.uid,
        currentUserId: currentUser.id,
      );

      await authUser.delete();
      await logout();
      return const AccountDeletionResult.success(
        'Votre compte a ete supprime.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password') {
        return const AccountDeletionResult.failure(
          'Le mot de passe saisi est incorrect.',
          requiresPassword: true,
        );
      }
      if (error.code == 'requires-recent-login') {
        return const AccountDeletionResult.failure(
          'Reconnectez-vous puis relancez la suppression du compte.',
        );
      }
      return AccountDeletionResult.failure(
        'Suppression impossible: ${error.message ?? error.code}',
        requiresPassword: currentAuthProviders.contains('password'),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      return AccountDeletionResult.failure(
        'Validation Apple annulee: ${error.message}.',
      );
    } on StateError catch (error) {
      final requiresPassword = error.toString().contains('password-required');
      return AccountDeletionResult.failure(
        requiresPassword
            ? 'Saisissez votre mot de passe pour confirmer.'
            : 'Suppression impossible pour le moment.',
        requiresPassword: requiresPassword,
      );
    } catch (error) {
      return const AccountDeletionResult.failure(
        'Suppression impossible pour le moment.',
      );
    }
  }

  Future<void> _deleteCurrentUserFirestoreData({
    required String authUid,
    required String currentUserId,
  }) async {
    final idsToDelete = <String>{authUid, currentUserId}
      ..removeWhere((value) => value.trim().isEmpty);

    final batch = _firestore.batch();
    for (final uid in idsToDelete) {
      batch.delete(_firestore.collection('users').doc(uid));
      batch.delete(_firestore.collection('profiles').doc(uid));
    }
    await batch.commit();
  }

  Future<void> _reauthenticateForSensitiveAction({
    required User user,
    String? currentPassword,
  }) async {
    final providers = currentAuthProviders;
    if (providers.contains('password')) {
      final email = user.email!.trim();
      final password = currentPassword?.trim() ?? '';
      if (email.isEmpty || password.isEmpty) {
        throw StateError('password-required');
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providers.contains('google.com')) {
      final googleSignIn = _buildGoogleSignIn();
      await googleSignIn.disconnect().catchError((_) => null);
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw StateError('reauth-cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providers.contains('apple.com')) {
      final credential = await _buildAppleOAuthCredential();
      await user.reauthenticateWithCredential(credential);
    }
  }

  Future<OAuthCredential> _buildAppleOAuthCredential() async {
    return (await _buildAppleOAuthPayload()).credential;
  }

  _AppleOAuthPayload? _lastAppleOAuthPayload;

  Future<UserCredential> _signInToFirebaseWithAppleCredential() async {
    final appleSignIn = await _buildAppleOAuthPayload();
    _lastAppleOAuthPayload = appleSignIn;

    try {
      return await _auth.signInWithCredential(appleSignIn.credential);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'invalid-credential') rethrow;

      // Apple credentials are short-lived. Request one fresh credential before
      // surfacing a hard failure so review devices do not get stuck on a stale token.
      final retryPayload = await _buildAppleOAuthPayload();
      _lastAppleOAuthPayload = retryPayload;
      return _auth.signInWithCredential(retryPayload.credential);
    }
  }

  Future<_AppleOAuthPayload> _buildAppleOAuthPayload() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-apple-token',
        message: 'Apple identity token missing.',
      );
    }
    return _AppleOAuthPayload(
      credential: OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      ),
      email: (appleCredential.email ?? '').trim(),
      firstName: (appleCredential.givenName ?? '').trim(),
      lastName: (appleCredential.familyName ?? '').trim(),
    );
  }

  Future<bool> _syncAppleUserProfile({
    required User user,
    required UserCredential userCredential,
    required _AppleOAuthPayload appleSignIn,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();
    final bool uidProfileExists = doc.exists;
    final fullName = (userCredential.user?.displayName ?? '').trim();
    final firstName = appleSignIn.firstName.isNotEmpty
        ? appleSignIn.firstName
        : _extractFirstName(fullName);
    final lastName = appleSignIn.lastName.isNotEmpty
        ? appleSignIn.lastName
        : _extractLastName(fullName);
    final resolvedEmail = (user.email ?? appleSignIn.email).trim();

    if (!uidProfileExists) {
      // No profile at this Apple Auth UID yet.
      // Check if a profile already exists for this email (pre-created via
      // addStaffMember using the email/password UID).
      final emailToQuery = resolvedEmail.isNotEmpty
          ? resolvedEmail
          : appleSignIn.email;
      QuerySnapshot? emailQuery;
      if (emailToQuery.isNotEmpty) {
        emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: emailToQuery)
            .limit(1)
            .get();
      }

      if (emailQuery != null && emailQuery.docs.isNotEmpty) {
        // Existing sub-director / supervisor linking Apple for the first time.
        // Migrate the profile to the new Apple Auth UID.
        final existingDoc = emailQuery.docs.first;
        final existingData =
            existingDoc.data() as Map<String, dynamic>;
        final migBatch = _firestore.batch();
        migBatch.set(
          userRef,
          {
            ...existingData,
            'uid': user.uid,
            'email': resolvedEmail.isNotEmpty
                ? resolvedEmail
                : existingData['email'],
            'appleLinkedAt': FieldValue.serverTimestamp(),
          },
        );
        if (existingDoc.id != user.uid) {
          migBatch.delete(
              _firestore.collection('users').doc(existingDoc.id));
        }
        await migBatch.commit();
        return false; // Existing profile, not a brand-new account.
      } else {
        // Truly new account — create Director profile.
        await userRef.set({
          'firstName': firstName,
          'lastName': lastName,
          'username': resolvedEmail.isNotEmpty
              ? resolvedEmail.split('@')[0]
              : 'stayfix_user',
          'email': resolvedEmail,
          'role': UserRoles.director,
          'phone': '',
          'termsAccepted': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }
    }

    // Profile already exists at this UID — update any missing fields.
    final existingData = doc.data() ?? const <String, dynamic>{};
    final updates = <String, dynamic>{};
    if ((existingData['firstName'] as String? ?? '').trim().isEmpty &&
        firstName.isNotEmpty) {
      updates['firstName'] = firstName;
    }
    if ((existingData['lastName'] as String? ?? '').trim().isEmpty &&
        lastName.isNotEmpty) {
      updates['lastName'] = lastName;
    }
    if ((existingData['email'] as String? ?? '').trim().isEmpty &&
        resolvedEmail.isNotEmpty) {
      updates['email'] = resolvedEmail;
    }
    if ((existingData['username'] as String? ?? '').trim().isEmpty &&
        resolvedEmail.isNotEmpty) {
      updates['username'] = resolvedEmail.split('@')[0];
    }
    if (updates.isNotEmpty) {
      await userRef.set(updates, SetOptions(merge: true));
    }
    return false;
  }

  GoogleSignIn _buildGoogleSignIn() {
    final applePlatforms = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return GoogleSignIn(
      scopes: const ['email'],
      clientId:
          applePlatforms ? DefaultFirebaseOptions.googleIosClientId : null,
      serverClientId: DefaultFirebaseOptions.googleServerClientId,
    );
  }

  String _googlePlatformErrorMessage(PlatformException error) {
    final details = '${error.code} ${error.message ?? ''}'.toLowerCase();
    if (details.contains('apiexception: 10') ||
        details.contains('developer_error')) {
      return 'Google Sign-In est mal configure pour cette application. Verifiez le client OAuth Android et la cle SHA dans Firebase.';
    }
    if (details.contains('network')) {
      return 'Connexion Google impossible sans internet.';
    }
    return 'Connexion Google impossible pour le moment.';
  }

  String _appleFirebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
        return 'Connexion Apple refusee par le service d authentification. Verifiez la configuration Apple dans Firebase et App Store Connect.';
      case 'missing-or-invalid-nonce':
      case 'invalid-oauth-response':
        return 'Connexion Apple impossible a valider. Reessayez dans un instant.';
      case 'operation-not-allowed':
        return 'Connexion Apple non active pour cette application.';
      case 'network-request-failed':
        return 'Connexion Apple impossible sans internet.';
      case 'account-exists-with-different-credential':
        return 'Un compte existe deja avec cet email via une autre methode de connexion.';
      case 'too-many-requests':
        return 'Trop de tentatives Apple. Reessayez plus tard.';
      case 'missing-apple-token':
        return 'Le jeton Apple est manquant. Reessayez.';
      default:
        return 'Connexion Apple impossible pour le moment.';
    }
  }

  String _extractFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _extractLastName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length <= 1) return '';
    return parts.sublist(1).join(' ');
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class _AppleOAuthPayload {
  const _AppleOAuthPayload({
    required this.credential,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final OAuthCredential credential;
  final String email;
  final String firstName;
  final String lastName;
}
