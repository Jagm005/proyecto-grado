import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:postgres/postgres.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(InventoryApp(state: state));
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Inventario Institucional',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00804E),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.libreFranklinTextTheme(
              ThemeData.light().textTheme,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 2,
            ),
          ),
          home: state.currentUser == null
              ? LoginPage(state: state)
              : HomePage(state: state),
        );
      },
    );
  }
}

enum UserRole {
  auxiliarInventario,
  administrador,
  responsableArea,
  direccionAdminFin,
  auditor,
  soporteTI,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.auxiliarInventario:
        return 'Auxiliar de Inventario';
      case UserRole.administrador:
        return 'Administrador';
      case UserRole.responsableArea:
        return 'Responsable de Area';
      case UserRole.direccionAdminFin:
        return 'Direccion Administrativa y Financiera';
      case UserRole.auditor:
        return 'Auditor';
      case UserRole.soporteTI:
        return 'Soporte TI';
    }
  }
}

enum AuthMode { institutional, localFallback }

extension AuthModeX on AuthMode {
  String get label {
    switch (this) {
      case AuthMode.institutional:
        return 'Autenticacion institucional';
      case AuthMode.localFallback:
        return 'Modo local (solo demo)';
    }
  }
}

enum AssetState {
  activo,
  reubicado,
  noEncontrado,
  obsoleto,
  enReparacion,
  paraBaja,
}

extension AssetStateX on AssetState {
  String get label {
    switch (this) {
      case AssetState.activo:
        return 'Activo';
      case AssetState.reubicado:
        return 'Reubicado';
      case AssetState.noEncontrado:
        return 'No Encontrado';
      case AssetState.obsoleto:
        return 'Obsoleto';
      case AssetState.enReparacion:
        return 'En Reparacion';
      case AssetState.paraBaja:
        return 'Para Baja';
    }
  }
}

enum VerificationResult {
  encontrado,
  reubicado,
  noEncontrado,
  paraBaja,
  obsoleto,
  enReparacion,
}

extension VerificationResultX on VerificationResult {
  String get label {
    switch (this) {
      case VerificationResult.encontrado:
        return 'Encontrado';
      case VerificationResult.reubicado:
        return 'Reubicado';
      case VerificationResult.noEncontrado:
        return 'No Encontrado';
      case VerificationResult.paraBaja:
        return 'Para Baja';
      case VerificationResult.obsoleto:
        return 'Obsoleto';
      case VerificationResult.enReparacion:
        return 'En Reparacion';
    }
  }
}

enum MaintenanceType { preventivo, correctivo }

enum ReportPeriod { mensual, semestral, anual }

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.password,
    required this.roles,
    this.area = '',
    this.isActive = true,
    this.lastSession,
    this.failedAttempts = 0,
    this.lockUntil,
  });

  final String id;
  String username;
  String fullName;
  String email;
  String password;
  String area;
  List<UserRole> roles;
  bool isActive;
  DateTime? lastSession;
  int failedAttempts;
  DateTime? lockUntil;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'password': password,
    'area': area,
    'roles': roles.map((r) => r.name).toList(),
    'isActive': isActive,
    'lastSession': lastSession?.toIso8601String(),
    'failedAttempts': failedAttempts,
    'lockUntil': lockUntil?.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    username: j['username'] as String,
    fullName: j['fullName'] as String,
    email: j['email'] as String,
    password: j['password'] as String,
    area: (j['area'] as String?) ?? '',
    roles: (j['roles'] as List)
        .map((r) => UserRole.values.byName(r as String))
        .toList(),
    isActive: j['isActive'] as bool,
    lastSession: j['lastSession'] != null
        ? DateTime.parse(j['lastSession'] as String)
        : null,
    failedAttempts: j['failedAttempts'] as int,
    lockUntil: j['lockUntil'] != null
        ? DateTime.parse(j['lockUntil'] as String)
        : null,
  );
}

class AssetHistoryEvent {
  AssetHistoryEvent({
    required this.timestamp,
    required this.action,
    required this.detail,
    required this.performedBy,
  });

  final DateTime timestamp;
  final String action;
  final String detail;
  final String performedBy;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'detail': detail,
    'performedBy': performedBy,
  };

  factory AssetHistoryEvent.fromJson(Map<String, dynamic> j) =>
      AssetHistoryEvent(
        timestamp: DateTime.parse(j['timestamp'] as String),
        action: j['action'] as String,
        detail: j['detail'] as String,
        performedBy: j['performedBy'] as String,
      );
}

class Asset {
  Asset({
    required this.code,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.physicalLocation,
    required this.responsible,
    required this.responsibleId,
    required this.dependency,
    required this.costCenter,
    required this.acquisitionValue,
    required this.acquisitionDate,
    required this.estimatedUsefulLifeYears,
    required this.state,
    required this.observations,
    required this.program,
    List<AssetHistoryEvent>? history,
  }) : history = history ?? [];

  final String code;
  String name;
  String category;
  String subcategory;
  String physicalLocation;
  String responsible;
  String responsibleId;
  String dependency;
  String costCenter;
  double acquisitionValue;
  DateTime acquisitionDate;
  int estimatedUsefulLifeYears;
  AssetState state;
  String observations;
  String program;
  final List<AssetHistoryEvent> history;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'category': category,
    'subcategory': subcategory,
    'physicalLocation': physicalLocation,
    'responsible': responsible,
    'responsibleId': responsibleId,
    'dependency': dependency,
    'costCenter': costCenter,
    'acquisitionValue': acquisitionValue,
    'acquisitionDate': acquisitionDate.toIso8601String(),
    'estimatedUsefulLifeYears': estimatedUsefulLifeYears,
    'state': state.name,
    'observations': observations,
    'program': program,
    'history': history.map((h) => h.toJson()).toList(),
  };

  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
    code: j['code'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    subcategory: j['subcategory'] as String,
    physicalLocation: j['physicalLocation'] as String,
    responsible: j['responsible'] as String,
    responsibleId: (j['responsibleId'] as String?) ?? '',
    dependency: j['dependency'] as String,
    costCenter: j['costCenter'] as String,
    acquisitionValue: (j['acquisitionValue'] as num).toDouble(),
    acquisitionDate: DateTime.parse(j['acquisitionDate'] as String),
    estimatedUsefulLifeYears: j['estimatedUsefulLifeYears'] as int,
    state: AssetState.values.byName(j['state'] as String),
    observations: j['observations'] as String,
    program: j['program'] as String,
    history:
        (j['history'] as List?)
            ?.map((h) => AssetHistoryEvent.fromJson(h as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class InventoryVerification {
  InventoryVerification({
    required this.assetCode,
    required this.result,
    required this.notes,
    required this.timestamp,
    this.photoPath,
  });

  final String assetCode;
  final VerificationResult result;
  final String notes;
  final DateTime timestamp;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
    'assetCode': assetCode,
    'result': result.name,
    'notes': notes,
    'timestamp': timestamp.toIso8601String(),
    'photoPath': photoPath,
  };

  factory InventoryVerification.fromJson(Map<String, dynamic> j) =>
      InventoryVerification(
        assetCode: j['assetCode'] as String,
        result: VerificationResult.values.byName(j['result'] as String),
        notes: j['notes'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        photoPath: j['photoPath'] as String?,
      );
}

class InventorySession {
  InventorySession({
    required this.id,
    required this.name,
    required this.site,
    required this.building,
    required this.floor,
    required this.area,
    required this.createdAt,
    required this.baselineStates,
  });

  final String id;
  final String name;
  final String site;
  final String building;
  final String floor;
  final String area;
  final DateTime createdAt;
  final Map<String, AssetState> baselineStates;
  final List<InventoryVerification> verifications = [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'site': site,
    'building': building,
    'floor': floor,
    'area': area,
    'createdAt': createdAt.toIso8601String(),
    'baselineStates': baselineStates.map((k, v) => MapEntry(k, v.name)),
    'verifications': verifications.map((v) => v.toJson()).toList(),
  };

  factory InventorySession.fromJson(Map<String, dynamic> j) {
    final s = InventorySession(
      id: j['id'] as String,
      name: j['name'] as String,
      site: j['site'] as String,
      building: j['building'] as String,
      floor: j['floor'] as String,
      area: j['area'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      baselineStates: (j['baselineStates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, AssetState.values.byName(v as String)),
      ),
    );
    for (final v in (j['verifications'] as List? ?? [])) {
      s.verifications.add(
        InventoryVerification.fromJson(v as Map<String, dynamic>),
      );
    }
    return s;
  }
}

class MaintenanceRequest {
  MaintenanceRequest({
    required this.id,
    required this.assetCode,
    required this.type,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String assetCode;
  final MaintenanceType type;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  bool closed = false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetCode': assetCode,
    'type': type.name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'closed': closed,
  };

  factory MaintenanceRequest.fromJson(Map<String, dynamic> j) {
    final r = MaintenanceRequest(
      id: j['id'] as String,
      assetCode: j['assetCode'] as String,
      type: MaintenanceType.values.byName(j['type'] as String),
      description: j['description'] as String,
      createdBy: j['createdBy'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
    r.closed = j['closed'] as bool;
    return r;
  }
}

class DisposalRequest {
  DisposalRequest({
    required this.id,
    required this.assetCode,
    required this.cause,
    required this.justification,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String assetCode;
  final String cause;
  final String justification;
  final String createdBy;
  final DateTime createdAt;
  bool approvedByDependency = false;
  bool approvedByDAF = false;

  String get status {
    if (approvedByDependency && approvedByDAF) {
      return 'Aprobada';
    }
    if (approvedByDependency || approvedByDAF) {
      return 'En aprobacion';
    }
    return 'Pendiente';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetCode': assetCode,
    'cause': cause,
    'justification': justification,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'approvedByDependency': approvedByDependency,
    'approvedByDAF': approvedByDAF,
  };

  factory DisposalRequest.fromJson(Map<String, dynamic> j) {
    final r = DisposalRequest(
      id: j['id'] as String,
      assetCode: j['assetCode'] as String,
      cause: j['cause'] as String,
      justification: j['justification'] as String,
      createdBy: j['createdBy'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
    r.approvedByDependency = j['approvedByDependency'] as bool;
    r.approvedByDAF = j['approvedByDAF'] as bool;
    return r;
  }
}

class PostgresConfig {
  PostgresConfig({
    this.host = 'localhost',
    this.port = 5432,
    this.database = 'inventario',
    this.username = 'postgres',
    this.password = 'postgres',
  });

  String host;
  int port;
  String database;
  String username;
  String password;
}

// ── Notificaciones ────────────────────────────────────────────────────────────

enum NotificationStatus { pendiente, aprobada, denegada }

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.fromUser,
    required this.relatedId,
    this.toRoles = const [],
    this.status = NotificationStatus.pendiente,
    this.read = false,
  });

  final String id;
  final String type; // 'maintenance' | 'disposal' | 'info' | 'missing_asset'
  final String title;
  final String body;
  final DateTime createdAt;
  final String fromUser;
  final String relatedId;

  /// Si no está vacío, solo los usuarios con alguno de estos roles la ven.
  final List<String> toRoles;
  NotificationStatus status;
  bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'fromUser': fromUser,
    'relatedId': relatedId,
    'toRoles': toRoles,
    'status': status.name,
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    fromUser: j['fromUser'] as String,
    relatedId: j['relatedId'] as String,
    toRoles: (j['toRoles'] as List?)?.map((e) => e as String).toList() ?? [],
    status: NotificationStatus.values.byName(
      (j['status'] as String?) ?? 'pendiente',
    ),
    read: (j['read'] as bool?) ?? false,
  );
}

class AppState extends ChangeNotifier {
  final List<AppUser> users = [];
  final List<Asset> assets = [];
  final List<InventorySession> inventorySessions = [];
  final List<MaintenanceRequest> maintenanceRequests = [];
  final List<DisposalRequest> disposalRequests = [];
  final List<AppNotification> notifications = [];
  final PostgresConfig postgresConfig = PostgresConfig();

  AppUser? currentUser;
  AuthMode authMode = AuthMode.institutional;
  int maxFailedAttempts = 3;

  int get unreadCount =>
      notifications.where((n) => !n.read && _notifVisibleToMe(n)).length;

  bool _notifVisibleToMe(AppNotification n) {
    if (currentUser == null) return false;
    // El solicitante siempre ve sus propias notificaciones
    if (n.fromUser == currentUser!.username) return true;
    // Si la notificacion tiene roles objetivo, el usuario debe tener alguno
    if (n.toRoles.isNotEmpty) {
      return currentUser!.roles.any((r) => n.toRoles.contains(r.name));
    }
    // Sin roles objetivo: solo admins ven todo lo pendiente
    return currentUser!.roles.contains(UserRole.administrador);
  }

  List<AppNotification> get myNotifications =>
      notifications.where(_notifVisibleToMe).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  void notifyListeners() {
    super.notifyListeners();
    _save().catchError((e) => debugPrint('Persistence error: $e'));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final usersData = prefs.getString('users');
    if (usersData != null) {
      users.clear();
      for (final j in jsonDecode(usersData) as List) {
        users.add(AppUser.fromJson(j as Map<String, dynamic>));
      }
    }

    final assetsData = prefs.getString('assets');
    if (assetsData != null) {
      assets.clear();
      for (final j in jsonDecode(assetsData) as List) {
        assets.add(Asset.fromJson(j as Map<String, dynamic>));
      }
    }

    final sessionsData = prefs.getString('inventorySessions');
    if (sessionsData != null) {
      inventorySessions.clear();
      for (final j in jsonDecode(sessionsData) as List) {
        inventorySessions.add(
          InventorySession.fromJson(j as Map<String, dynamic>),
        );
      }
    }

    final maintData = prefs.getString('maintenanceRequests');
    if (maintData != null) {
      maintenanceRequests.clear();
      for (final j in jsonDecode(maintData) as List) {
        maintenanceRequests.add(
          MaintenanceRequest.fromJson(j as Map<String, dynamic>),
        );
      }
    }

    final disposalData = prefs.getString('disposalRequests');
    if (disposalData != null) {
      disposalRequests.clear();
      for (final j in jsonDecode(disposalData) as List) {
        disposalRequests.add(
          DisposalRequest.fromJson(j as Map<String, dynamic>),
        );
      }
    }

    final notifData = prefs.getString('notifications');
    if (notifData != null) {
      notifications.clear();
      for (final j in jsonDecode(notifData) as List) {
        notifications.add(AppNotification.fromJson(j as Map<String, dynamic>));
      }
    }

    if (users.isEmpty) {
      seedData();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'users',
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
    await prefs.setString(
      'assets',
      jsonEncode(assets.map((a) => a.toJson()).toList()),
    );
    await prefs.setString(
      'inventorySessions',
      jsonEncode(inventorySessions.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(
      'maintenanceRequests',
      jsonEncode(maintenanceRequests.map((m) => m.toJson()).toList()),
    );
    await prefs.setString(
      'disposalRequests',
      jsonEncode(disposalRequests.map((d) => d.toJson()).toList()),
    );
    await prefs.setString(
      'notifications',
      jsonEncode(notifications.map((n) => n.toJson()).toList()),
    );
  }

  void seedData() {
    if (users.isNotEmpty) {
      return;
    }
    users.addAll([
      AppUser(
        id: 'U001',
        username: 'admin',
        fullName: 'Admin General',
        email: 'admin@universidad.edu',
        password: 'admin123',
        area: 'Direccion Administrativa',
        roles: [UserRole.administrador, UserRole.soporteTI],
      ),
      AppUser(
        id: 'U002',
        username: 'auxiliar',
        fullName: 'Auxiliar Inventario',
        email: 'auxiliar@universidad.edu',
        password: 'aux123',
        area: 'Almacen e Inventarios',
        roles: [UserRole.auxiliarInventario],
      ),
      AppUser(
        id: 'U003',
        username: 'auditor',
        fullName: 'Auditoria Interna',
        email: 'auditor@universidad.edu',
        password: 'audit123',
        area: 'Control Interno',
        roles: [UserRole.auditor],
      ),
      AppUser(
        id: 'U004',
        username: 'daf',
        fullName: 'Direccion Admin Fin',
        email: 'daf@universidad.edu',
        password: 'daf123',
        area: 'Finanzas',
        roles: [UserRole.direccionAdminFin],
      ),
    ]);

    addAsset(
      Asset(
        code: 'ACT-1001',
        name: 'Laptop Dell 5420',
        category: 'Computo',
        subcategory: 'Portatil',
        physicalLocation: 'Almacen e Inventarios',
        responsible: 'Auxiliar Inventario',
        responsibleId: 'U002',
        dependency: 'Almacen e Inventarios',
        costCenter: 'CC-ADM-01',
        acquisitionValue: 3800000,
        acquisitionDate: DateTime(2023, 4, 5),
        estimatedUsefulLifeYears: 5,
        state: AssetState.activo,
        observations: 'Equipo en buen estado',
        program: 'Administracion',
      ),
      performedBy: 'system',
    );

    addAsset(
      Asset(
        code: 'ACT-2002',
        name: 'Silla Ergonomica',
        category: 'Mobiliario',
        subcategory: 'Silla',
        physicalLocation: 'Direccion Administrativa',
        responsible: 'Admin General',
        responsibleId: 'U001',
        dependency: 'Direccion Administrativa',
        costCenter: 'CC-ADM-01',
        acquisitionValue: 890000,
        acquisitionDate: DateTime(2022, 8, 14),
        estimatedUsefulLifeYears: 8,
        state: AssetState.activo,
        observations: 'Uso diario',
        program: 'Administracion',
      ),
      performedBy: 'system',
    );
  }

  bool hasRole(UserRole role) {
    return currentUser?.roles.contains(role) ?? false;
  }

  bool canManageUsers() => hasRole(UserRole.administrador);

  bool canManageAssets() =>
      hasRole(UserRole.administrador) || hasRole(UserRole.auxiliarInventario);

  void reportMissingAsset({
    required String scannedCode,
    required String notes,
  }) {
    final notifId = 'NOTIF-${DateTime.now().millisecondsSinceEpoch}';
    notifications.add(
      AppNotification(
        id: notifId,
        type: 'missing_asset',
        title: 'Activo no encontrado: $scannedCode',
        body:
            'El usuario ${currentUser?.fullName ?? currentUser?.username} reportó que el activo con código "$scannedCode" no existe físicamente.'
            '${notes.isNotEmpty ? '\nNota: $notes' : ''}',
        createdAt: DateTime.now(),
        fromUser: currentUser?.username ?? '',
        relatedId: scannedCode,
        toRoles: [UserRole.administrador.name, UserRole.direccionAdminFin.name],
      ),
    );
    notifyListeners();
  }

  bool canApproveDisposals() =>
      hasRole(UserRole.direccionAdminFin) || hasRole(UserRole.responsableArea);

  void setAuthMode(AuthMode mode) {
    authMode = mode;
    notifyListeners();
  }

  void setMaxFailedAttempts(int value) {
    if (value <= 0) {
      return;
    }
    maxFailedAttempts = value;
    notifyListeners();
  }

  AppUser? _findUserByUsername(String username) {
    for (final u in users) {
      if (u.username.toLowerCase() == username.toLowerCase()) {
        return u;
      }
    }
    return null;
  }

  /// URL base del backend. Configurable en tiempo de compilación con
  /// --dart-define=BACKEND_URL=http://10.0.2.2:3000  (Android emulador)
  static const _backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://3.22.221.113:3000',
  );

  /// Retorna null si el login fue exitoso.
  /// Retorna un String con el codigo del error para que la UI distinga el tipo:
  ///   Prefijo  LOCK:segundos   - cuenta bloqueada (RF03)
  ///   Prefijo  WARN:restantes  - credenciales invalidas, muestra intentos restantes (RF03)
  ///   Prefijo  INFO:mensaje    - error informativo sin conteo
  Future<String?> login(String username, String password) async {
    if (authMode == AuthMode.institutional) {
      return _loginWithBackend(username.trim(), password);
    }
    return _loginLocal(username.trim(), password);
  }

  Future<String?> _loginWithBackend(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final rawRoles = (body['roles'] as List).cast<String>();
        final appUser = AppUser(
          id: body['id'] as String,
          username: body['username'] as String,
          fullName: body['fullName'] as String,
          email: body['email'] as String,
          password: '', // no almacenamos la contraseña en cliente
          area: (body['area'] as String?) ?? '',
          roles: rawRoles.map((r) => UserRole.values.byName(r)).toList(),
          isActive: body['isActive'] as bool,
        );
        currentUser = appUser;
        notifyListeners();
        return null;
      }

      final code = body['code'] as String? ?? 'INFO';
      final message = body['message'] as String? ?? '';
      final seconds = body['seconds'] as int? ?? 900;
      final remaining = body['remaining'] as int? ?? 0;

      if (code == 'LOCK') return 'LOCK:$seconds';
      if (code == 'WARN') return 'WARN:$remaining';
      return 'INFO:$message';
    } on http.ClientException catch (e) {
      debugPrint('ClientException: $e');
      return 'INFO:No se pudo conectar al servidor. Verifique la red o use el modo local.';
    } catch (e) {
      debugPrint('Login error: $e');
      return 'INFO:No se pudo conectar al servidor. Verifique la red o use el modo local.';
    }
  }

  String? _loginLocal(String username, String password) {
    final user = _findUserByUsername(username.trim());
    if (user == null) {
      return 'INFO:Usuario no encontrado';
    }
    if (!user.isActive) {
      return 'INFO:Usuario desactivado. Contacte al Administrador';
    }
    if (user.lockUntil != null && user.lockUntil!.isAfter(DateTime.now())) {
      final seconds = user.lockUntil!.difference(DateTime.now()).inSeconds;
      return 'LOCK:$seconds';
    }

    final valid = _validateInstitutionalCredential(user, password);
    if (!valid) {
      user.failedAttempts += 1;
      if (user.failedAttempts >= maxFailedAttempts) {
        user.lockUntil = DateTime.now().add(const Duration(minutes: 15));
        user.failedAttempts = 0;
        notifyListeners();
        return 'LOCK:900';
      }
      final remaining = maxFailedAttempts - user.failedAttempts;
      notifyListeners();
      return 'WARN:$remaining';
    }

    user.failedAttempts = 0;
    user.lockUntil = null;
    user.lastSession = DateTime.now();
    currentUser = user;
    notifyListeners();
    return null;
  }

  bool _validateInstitutionalCredential(AppUser user, String password) {
    if (authMode == AuthMode.institutional) {
      // Integration point for SSO/LDAP institutional auth.
      return user.password == password;
    }
    return user.password == password;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  void requestCredentialReset(String username) {
    final user = _findUserByUsername(username);
    if (user == null) {
      return;
    }
    final temporaryPassword = 'Temp${Random().nextInt(8999) + 1000}';
    user.password = "admin123";
    notifyListeners();
  }

  void createUser(AppUser user) {
    users.add(user);
    notifyListeners();
  }

  void updateUser(
    AppUser user, {
    required String fullName,
    required String email,
    required String area,
    required List<UserRole> roles,
    required bool isActive,
  }) {
    user.fullName = fullName;
    user.email = email;
    user.area = area;
    user.roles = roles;
    user.isActive = isActive;
    notifyListeners();
  }

  void deleteUser(AppUser user) {
    users.remove(user);
    notifyListeners();
  }

  void deleteAsset(Asset asset) {
    assets.remove(asset);
    notifyListeners();
  }

  void addAsset(Asset asset, {required String performedBy}) {
    asset.history.add(
      AssetHistoryEvent(
        timestamp: DateTime.now(),
        action: 'CREACION',
        detail: 'Activo registrado',
        performedBy: performedBy,
      ),
    );
    assets.add(asset);
    notifyListeners();
  }

  void updateAsset(
    Asset asset, {
    required String performedBy,
    String? newResponsible,
    String? newLocation,
    AssetState? newState,
    String? notes,
  }) {
    final changes = <String>[];
    if (newResponsible != null && newResponsible != asset.responsible) {
      changes.add('Responsable: ${asset.responsible} -> $newResponsible');
      asset.responsible = newResponsible;
    }
    if (newLocation != null && newLocation != asset.physicalLocation) {
      changes.add('Ubicacion: ${asset.physicalLocation} -> $newLocation');
      asset.physicalLocation = newLocation;
    }
    if (newState != null && newState != asset.state) {
      changes.add('Estado: ${asset.state.label} -> ${newState.label}');
      asset.state = newState;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      changes.add('Observaciones: $notes');
      asset.observations = notes;
    }
    if (changes.isNotEmpty) {
      asset.history.add(
        AssetHistoryEvent(
          timestamp: DateTime.now(),
          action: 'ACTUALIZACION',
          detail: changes.join(' | '),
          performedBy: performedBy,
        ),
      );
      notifyListeners();
    }
  }

  Asset? findAsset(String code) {
    for (final a in assets) {
      if (a.code.toLowerCase() == code.toLowerCase()) {
        return a;
      }
    }
    return null;
  }

  InventorySession createInventorySession({
    required String name,
    required String site,
    required String building,
    required String floor,
    required String area,
  }) {
    final baseline = <String, AssetState>{};
    for (final a in assets) {
      baseline[a.code] = a.state;
    }
    final session = InventorySession(
      id: 'INV-${inventorySessions.length + 1}',
      name: name,
      site: site,
      building: building,
      floor: floor,
      area: area,
      createdAt: DateTime.now(),
      baselineStates: baseline,
    );
    inventorySessions.add(session);
    notifyListeners();
    return session;
  }

  void registerVerification({
    required InventorySession session,
    required String assetCode,
    required VerificationResult result,
    required String notes,
    String? photoPath,
  }) {
    final verification = InventoryVerification(
      assetCode: assetCode,
      result: result,
      notes: notes,
      timestamp: DateTime.now(),
      photoPath: photoPath,
    );
    session.verifications.add(verification);

    final asset = findAsset(assetCode);
    if (asset != null) {
      updateAsset(
        asset,
        performedBy: currentUser?.username ?? 'system',
        newState: _assetStateFromVerification(result),
        notes: notes,
      );
    }
    notifyListeners();
  }

  AssetState _assetStateFromVerification(VerificationResult result) {
    switch (result) {
      case VerificationResult.encontrado:
        return AssetState.activo;
      case VerificationResult.reubicado:
        return AssetState.reubicado;
      case VerificationResult.noEncontrado:
        return AssetState.noEncontrado;
      case VerificationResult.paraBaja:
        return AssetState.paraBaja;
      case VerificationResult.obsoleto:
        return AssetState.obsoleto;
      case VerificationResult.enReparacion:
        return AssetState.enReparacion;
    }
  }

  void createMaintenance({
    required String assetCode,
    required MaintenanceType type,
    required String description,
  }) {
    final id = 'MNT-${maintenanceRequests.length + 1}';
    maintenanceRequests.add(
      MaintenanceRequest(
        id: id,
        assetCode: assetCode,
        type: type,
        description: description,
        createdBy: currentUser?.username ?? 'system',
        createdAt: DateTime.now(),
      ),
    );

    // Generar notificacion para administradores
    final user = currentUser;
    final asset = findAsset(assetCode);
    notifications.add(
      AppNotification(
        id: 'NOTIF-${notifications.length + 1}',
        type: 'maintenance',
        title: 'Solicitud de mantenimiento',
        body:
            'Activo: ${asset?.name ?? assetCode}\n'
            'Tipo: ${type.name}\n'
            'Descripcion: $description\n'
            'Solicitante: ${user?.fullName ?? 'Desconocido'} '
            '(${user?.area ?? ''}) · ${user?.email ?? ''}',
        createdAt: DateTime.now(),
        fromUser: user?.username ?? 'system',
        relatedId: id,
      ),
    );
    notifyListeners();
  }

  void closeMaintenance(MaintenanceRequest req) {
    req.closed = true;
    notifyListeners();
  }

  void markNotificationRead(AppNotification n) {
    n.read = true;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in myNotifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void approveNotification(AppNotification n) {
    n.status = NotificationStatus.aprobada;
    n.read = true;
    if (n.type == 'maintenance') {
      // ya queda registrada la aprobacion en la notificacion misma
      maintenanceRequests.where((r) => r.id == n.relatedId).firstOrNull;
    }
    notifyListeners();
  }

  void denyNotification(AppNotification n) {
    n.status = NotificationStatus.denegada;
    n.read = true;
    notifyListeners();
  }

  void createDisposal({
    required String assetCode,
    required String cause,
    required String justification,
  }) {
    disposalRequests.add(
      DisposalRequest(
        id: 'DSP-${disposalRequests.length + 1}',
        assetCode: assetCode,
        cause: cause,
        justification: justification,
        createdBy: currentUser?.username ?? 'system',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void approveDisposalByDependency(DisposalRequest req) {
    req.approvedByDependency = true;
    _markAssetAsDisposedIfFullyApproved(req);
    notifyListeners();
  }

  void approveDisposalByDAF(DisposalRequest req) {
    req.approvedByDAF = true;
    _markAssetAsDisposedIfFullyApproved(req);
    notifyListeners();
  }

  void _markAssetAsDisposedIfFullyApproved(DisposalRequest req) {
    if (!(req.approvedByDependency && req.approvedByDAF)) {
      return;
    }
    final asset = findAsset(req.assetCode);
    if (asset != null) {
      updateAsset(
        asset,
        performedBy: currentUser?.username ?? 'system',
        newState: AssetState.paraBaja,
        notes: 'Baja aprobada: ${req.cause}',
      );
    }
  }

  List<Asset> reportFilteredAssets({
    String? site,
    String? area,
    String? dependency,
    String? program,
    String? responsible,
    String? category,
    AssetState? state,
  }) {
    return assets.where((asset) {
      if (site != null &&
          site.isNotEmpty &&
          !asset.physicalLocation.toLowerCase().contains(site.toLowerCase())) {
        return false;
      }
      if (area != null &&
          area.isNotEmpty &&
          !asset.physicalLocation.toLowerCase().contains(area.toLowerCase())) {
        return false;
      }
      if (dependency != null &&
          dependency.isNotEmpty &&
          asset.dependency.toLowerCase() != dependency.toLowerCase()) {
        return false;
      }
      if (program != null &&
          program.isNotEmpty &&
          asset.program.toLowerCase() != program.toLowerCase()) {
        return false;
      }
      if (responsible != null &&
          responsible.isNotEmpty &&
          asset.responsible.toLowerCase() != responsible.toLowerCase()) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          asset.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      if (state != null && asset.state != state) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic> auditFindings() {
    final duplicatedCodes = <String>[];
    final seen = <String>{};
    for (final a in assets) {
      if (seen.contains(a.code)) {
        duplicatedCodes.add(a.code);
      }
      seen.add(a.code);
    }
    final notFound = assets
        .where((a) => a.state == AssetState.noEncontrado)
        .map((a) => a.code)
        .toList();
    final withoutResponsible = assets
        .where((a) => a.responsible.trim().isEmpty)
        .map((a) => a.code)
        .toList();
    return {
      'notFound': notFound,
      'duplicated': duplicatedCodes,
      'withoutResponsible': withoutResponsible,
    };
  }

  double depreciationValue(Asset asset, DateTime atDate) {
    final years = atDate.difference(asset.acquisitionDate).inDays / 365;
    final annual =
        asset.acquisitionValue / max(1, asset.estimatedUsefulLifeYears);
    final depreciation = annual * years;
    return max(0, asset.acquisitionValue - depreciation);
  }

  String comparativeReport(InventorySession session) {
    final rows = <String>[];
    for (final asset in assets) {
      final before = session.baselineStates[asset.code]?.label ?? 'Sin dato';
      final after = asset.state.label;
      if (before != after) {
        rows.add('${asset.code}: $before -> $after');
      }
    }
    if (rows.isEmpty) {
      return 'No hay cambios entre el estado previo y posterior.';
    }
    return rows.join('\n');
  }

  String generateCsv(List<Asset> reportAssets) {
    final buffer = StringBuffer();
    buffer.writeln(
      'codigo,nombre,categoria,subcategoria,ubicacion,responsable,dependencia,programa,estado,valor_adquisicion,valor_depreciado',
    );
    for (final a in reportAssets) {
      buffer.writeln(
        '${a.code},${_safeCsv(a.name)},${_safeCsv(a.category)},${_safeCsv(a.subcategory)},${_safeCsv(a.physicalLocation)},${_safeCsv(a.responsible)},${_safeCsv(a.dependency)},${_safeCsv(a.program)},${a.state.label},${a.acquisitionValue.toStringAsFixed(2)},${depreciationValue(a, DateTime.now()).toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  String _safeCsv(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<List<int>> generatePdfBytes(
    List<Asset> reportAssets, {
    required ReportPeriod period,
  }) async {
    final doc = pw.Document();
    final formatter = NumberFormat.currency(symbol: '4', decimalDigits: 0);
    doc.addPage(
      pw.MultiPage(
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Reporte Institucional de Inventario',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Periodo: ${period.name}'),
            pw.Text(
              'Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 12),
          ];

          for (final a in reportAssets) {
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  '${a.code} | ${a.name} | ${a.state.label} | Valor: ${formatter.format(a.acquisitionValue)}',
                ),
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return doc.save();
  }

  Future<String> testPostgresConnection() async {
    PostgreSQLConnection? conn;
    try {
      conn = PostgreSQLConnection(
        postgresConfig.host,
        postgresConfig.port,
        postgresConfig.database,
        username: postgresConfig.username,
        password: postgresConfig.password,
      );
      await conn.open();
      final result = await conn.query('SELECT NOW()');
      return 'Conexion exitosa. Hora servidor: ${result.first.first}';
    } catch (e) {
      return 'Error de conexion: $e';
    } finally {
      await conn?.close();
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});

  final AppState state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');

  // RF03: tipo de error distinguido por prefijo devuelto desde login()
  _AuthError? _authError;
  Timer? _lockTimer;
  int _lockSecondsRemaining = 0;

  static const _demoUsers = [
    _DemoUser('admin', 'admin123', UserRole.administrador),
    _DemoUser('auxiliar', 'aux123', UserRole.auxiliarInventario),
    _DemoUser('auditor', 'audit123', UserRole.auditor),
    _DemoUser('daf', 'daf123', UserRole.direccionAdminFin),
  ];

  @override
  void dispose() {
    _lockTimer?.cancel();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  void _handleLogin() {
    _doLogin();
  }

  Future<void> _doLogin() async {
    if (_isLoading) return;
    _lockTimer?.cancel();
    setState(() => _isLoading = true);
    final raw = await widget.state.login(
      _userController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (raw == null) {
      return; // exitoso → AppState notifica y la app navega a HomePage
    }
    final parts = raw.split(':');
    final prefix = parts[0];
    final payload = parts.length > 1 ? parts.sublist(1).join(':') : '';

    if (prefix == 'LOCK') {
      final secs = int.tryParse(payload) ?? 900;
      setState(() {
        _lockSecondsRemaining = secs;
        _authError = _AuthError.locked;
      });
      // Refresca el contador cada segundo (RF03)
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(
          () => _lockSecondsRemaining = max(0, _lockSecondsRemaining - 1),
        );
        if (_lockSecondsRemaining == 0) {
          _lockTimer?.cancel();
          setState(() => _authError = null);
        }
      });
    } else if (prefix == 'WARN') {
      setState(() {
        _lockSecondsRemaining = int.tryParse(payload) ?? 0;
        _authError = _AuthError.wrongCredentials;
      });
    } else {
      // INFO: mensaje generico sin conteo
      setState(() {
        _authError = _AuthError.info;
        _infoMessage = payload;
      });
    }
  }

  String _infoMessage = '';

  String _formatLock() {
    final m = _lockSecondsRemaining ~/ 60;
    final s = _lockSecondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _prefill(_DemoUser demo) {
    setState(() {
      _userController.text = demo.username;
      _passwordController.text = demo.password;
      _authError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = _authError == _AuthError.locked || _isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F4),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/logo-ucp.png',
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // RF01: mecanismo de autenticacion configurable
                    DropdownButtonFormField<AuthMode>(
                      value: widget.state.authMode,
                      items: AuthMode.values
                          .map(
                            (m) => DropdownMenuItem<AuthMode>(
                              value: m,
                              child: Text(m.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) widget.state.setAuthMode(value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Mecanismo de autenticacion',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _userController,
                      enabled: !locked,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onSubmitted: (_) => locked ? null : _handleLogin(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      enabled: !locked,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Clave',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onSubmitted: (_) => locked ? null : _handleLogin(),
                    ),
                    const SizedBox(height: 14),

                    // RF03: banners de error diferenciados
                    _buildErrorBanner(),

                    FilledButton.icon(
                      onPressed: locked ? null : _handleLogin,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Iniciar sesion'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: locked
                          ? null
                          : () {
                              widget.state.requestCredentialReset(
                                _userController.text,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Solicitud enviada al area de TI.',
                                  ),
                                ),
                              );
                            },
                      child: const Text('Recuperar credenciales via TI'),
                    ),

                    const Divider(height: 28),
                    // RF02: accesos rapidos por rol para demo
                    const Text(
                      'Acceso rapido por rol (demo):',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _demoUsers
                          .map(
                            (d) => ActionChip(
                              avatar: const Icon(
                                Icons.badge_outlined,
                                size: 16,
                              ),
                              label: Text(
                                d.role.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: locked ? null : () => _prefill(d),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_authError == null) return const SizedBox.shrink();

    switch (_authError!) {
      case _AuthError.locked:
        // RF03: bloqueo temporal con cuenta regresiva
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cuenta bloqueada. Espera ${_formatLock()} para reintentar.',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            ],
          ),
        );

      case _AuthError.wrongCredentials:
        // RF03: credenciales invalidas con intentos restantes
        final restantes = _lockSecondsRemaining;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade800,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  restantes == 1
                      ? 'Credenciales invalidas. Ultimo intento antes del bloqueo.'
                      : 'Credenciales invalidas. Intentos restantes: $restantes.',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
        );

      case _AuthError.info:
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_infoMessage, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
    }
  }
}

enum _AuthError { locked, wrongCredentials, info }

class _DemoUser {
  const _DemoUser(this.username, this.password, this.role);
  final String username;
  final String password;
  final UserRole role;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    // Definicion de tabs con control de acceso por rol
    final allTabs =
        <
          ({
            Widget page,
            Icon icon,
            Icon selectedIcon,
            String label,
            bool allowed,
          })
        >[
          (
            page: DashboardPage(state: s),
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: 'Inicio',
            allowed: true,
          ),
          (
            page: UsersPage(state: s),
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: 'Usuarios',
            allowed: s.hasRole(UserRole.administrador),
          ),
          (
            page: AssetsPage(state: s),
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: 'Activos',
            allowed:
                s.hasRole(UserRole.auxiliarInventario) ||
                s.hasRole(UserRole.administrador) ||
                s.hasRole(UserRole.responsableArea) ||
                s.hasRole(UserRole.soporteTI) ||
                s.hasRole(UserRole.auditor) ||
                s.hasRole(UserRole.direccionAdminFin),
          ),
          (
            page: InventoryPage(state: s),
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check),
            label: 'Inventario',
            allowed:
                s.hasRole(UserRole.auxiliarInventario) ||
                s.hasRole(UserRole.administrador) ||
                s.hasRole(UserRole.auditor),
          ),
          (
            page: MaintenancePage(state: s),
            icon: const Icon(Icons.build_outlined),
            selectedIcon: const Icon(Icons.build),
            label: 'Manto/Bajas',
            allowed:
                s.hasRole(UserRole.auxiliarInventario) ||
                s.hasRole(UserRole.administrador) ||
                s.hasRole(UserRole.responsableArea) ||
                s.hasRole(UserRole.direccionAdminFin),
          ),
          (
            page: ReportsPage(state: s),
            icon: const Icon(Icons.assessment_outlined),
            selectedIcon: const Icon(Icons.assessment),
            label: 'Reportes',
            allowed:
                s.hasRole(UserRole.administrador) ||
                s.hasRole(UserRole.auditor) ||
                s.hasRole(UserRole.direccionAdminFin) ||
                s.hasRole(UserRole.responsableArea),
          ),
          (
            page: IntegrationPage(state: s),
            icon: const Icon(Icons.storage_outlined),
            selectedIcon: const Icon(Icons.storage),
            label: 'PostgreSQL',
            allowed:
                s.hasRole(UserRole.administrador) ||
                s.hasRole(UserRole.soporteTI),
          ),
          (
            page: NotificationsPage(state: s),
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Avisos',
            allowed: true,
          ),
        ];

    final tabs = allTabs.where((t) => t.allowed).toList();
    final safeIndex = _tabIndex.clamp(0, tabs.length - 1);
    final unread = s.unreadCount;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/isologo-ucp.png', fit: BoxFit.contain),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.state.currentUser?.fullName ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if ((widget.state.currentUser?.roles ?? []).isNotEmpty)
              Text(
                (widget.state.currentUser?.roles ?? [])
                    .map((r) => r.label)
                    .join(' · '),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: widget.state.logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Salir'),
            ),
          ),
        ],
      ),
      body: tabs[safeIndex].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: tabs
            .map(
              (t) => NavigationDestination(
                icon: t.label == 'Avisos' && unread > 0
                    ? Badge(label: Text('$unread'), child: t.icon)
                    : t.icon,
                selectedIcon: t.selectedIcon,
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Panel de Control',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
              'Activos',
              state.assets.length.toString(),
              Icons.inventory_2_outlined,
              const Color(0xFF00804E),
            ),
            _metricCard(
              'Mantenimientos',
              state.maintenanceRequests.length.toString(),
              Icons.build_outlined,
              const Color(0xFFE65100),
            ),
            _metricCard(
              'Bajas',
              state.disposalRequests.length.toString(),
              Icons.delete_sweep_outlined,
              const Color(0xFFC62828),
            ),
            _metricCard(
              'Jornadas',
              state.inventorySessions.length.toString(),
              Icons.fact_check_outlined,
              const Color(0xFF6A1B9A),
            ),
            _metricCard(
              'Usuarios',
              state.users.length.toString(),
              Icons.people_alt_outlined,
              const Color(0xFF1565C0),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesion actual',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.currentUser?.roles
                                .map((r) => r.label)
                                .join(' · ') ??
                            '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_outlined,
                      size: 18,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.currentUser?.lastSession != null
                          ? DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(state.currentUser!.lastSession!)
                          : 'Primera sesion',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.state});

  final AppState state;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  Widget build(BuildContext context) {
    if (!widget.state.canManageUsers()) {
      return const Center(
        child: Text('Solo Administrador puede gestionar usuarios.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _createUserDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Crear usuario'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Intentos maximos antes de bloqueo: ${widget.state.maxFailedAttempts}',
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max'),
                  onSubmitted: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      widget.state.setMaxFailedAttempts(parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: widget.state.users.length,
              itemBuilder: (context, index) {
                final user = widget.state.users[index];
                return Card(
                  child: ListTile(
                    title: Text('${user.fullName} (${user.username})'),
                    subtitle: Text(
                      'Roles: ${user.roles.map((r) => r.label).join(', ')}\nActivo: ${user.isActive ? 'Si' : 'No'} | Ultima sesion: ${user.lastSession != null ? DateFormat('yyyy-MM-dd HH:mm').format(user.lastSession!) : 'N/A'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar',
                          onPressed: () => _editUserDialog(context, user),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Eliminar usuario'),
                                content: Text(
                                  'Eliminar a ${user.fullName} (${user.username})?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              widget.state.deleteUser(user);
                            }
                          },
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createUserDialog(BuildContext context) async {
    final username = TextEditingController();
    final fullName = TextEditingController();
    final email = TextEditingController();
    final area = TextEditingController();
    final password = TextEditingController();
    final selectedRoles = <UserRole>{UserRole.auxiliarInventario};

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? errorMsg;
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            return AlertDialog(
              title: const Text('Crear usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fullName,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: area,
                      decoration: const InputDecoration(
                        labelText: 'Área / Dependencia',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Clave inicial * (min. 6 car.)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...UserRole.values.map(
                      (r) => CheckboxListTile(
                        value: selectedRoles.contains(r),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selectedRoles.add(r);
                            } else {
                              selectedRoles.remove(r);
                            }
                          });
                        },
                        title: Text(r.label),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final u = username.text.trim();
                    final f = fullName.text.trim();
                    final e = email.text.trim();
                    final p = password.text.trim();
                    if (u.isEmpty || f.isEmpty || e.isEmpty || p.isEmpty) {
                      setLocal(
                        () => errorMsg =
                            'Username, nombre, correo y clave son obligatorios.',
                      );
                      return;
                    }
                    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
                    if (!emailRegex.hasMatch(e)) {
                      setLocal(
                        () =>
                            errorMsg = 'El correo no tiene un formato valido.',
                      );
                      return;
                    }
                    if (p.length < 6) {
                      setLocal(
                        () => errorMsg =
                            'La clave debe tener al menos 6 caracteres.',
                      );
                      return;
                    }
                    if (widget.state.users.any((usr) => usr.username == u)) {
                      setLocal(
                        () =>
                            errorMsg = 'Ya existe un usuario con ese username.',
                      );
                      return;
                    }
                    if (selectedRoles.isEmpty) {
                      setLocal(() => errorMsg = 'Selecciona al menos un rol.');
                      return;
                    }
                    widget.state.createUser(
                      AppUser(
                        id: 'U${widget.state.users.length + 1}'.padLeft(4, '0'),
                        username: u,
                        fullName: f,
                        email: e,
                        area: area.text.trim(),
                        password: p,
                        roles: selectedRoles.toList(),
                      ),
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editUserDialog(BuildContext context, AppUser user) async {
    final fullName = TextEditingController(text: user.fullName);
    final email = TextEditingController(text: user.email);
    final area = TextEditingController(text: user.area);
    bool isActive = user.isActive;
    final selectedRoles = <UserRole>{...user.roles};

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? errorMsg;
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            return AlertDialog(
              title: Text('Editar ${user.username}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: fullName,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo *'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: area,
                      decoration: const InputDecoration(
                        labelText: 'Área / Dependencia',
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (v) => setLocal(() => isActive = v),
                    ),
                    ...UserRole.values.map(
                      (r) => CheckboxListTile(
                        value: selectedRoles.contains(r),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selectedRoles.add(r);
                            } else {
                              selectedRoles.remove(r);
                            }
                          });
                        },
                        title: Text(r.label),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final f = fullName.text.trim();
                    final e = email.text.trim();
                    if (f.isEmpty || e.isEmpty) {
                      setLocal(
                        () => errorMsg =
                            'El nombre y el correo son obligatorios.',
                      );
                      return;
                    }
                    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
                    if (!emailRegex.hasMatch(e)) {
                      setLocal(
                        () =>
                            errorMsg = 'El correo no tiene un formato valido.',
                      );
                      return;
                    }
                    if (selectedRoles.isEmpty) {
                      setLocal(() => errorMsg = 'Selecciona al menos un rol.');
                      return;
                    }
                    widget.state.updateUser(
                      user,
                      fullName: f,
                      email: e,
                      area: area.text.trim(),
                      roles: selectedRoles.toList(),
                      isActive: isActive,
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key, required this.state});

  final AppState state;

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered = widget.state.assets.where((a) {
      if (query.isEmpty) {
        return true;
      }
      return a.code.toLowerCase().contains(query) ||
          a.name.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar activo por codigo o nombre',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.state.canManageAssets())
                FilledButton.icon(
                  onPressed: () => _createAssetDialog(context),
                  icon: const Icon(Icons.add_box),
                  label: const Text('Registrar activo'),
                ),
              if (widget.state.canManageAssets()) const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _scanBarcode(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final asset = filtered[index];
                return Card(
                  child: ExpansionTile(
                    title: Text('${asset.code} - ${asset.name}'),
                    subtitle: Text(
                      '${asset.category} | ${asset.state.label} | Responsable: ${asset.responsible}',
                    ),
                    children: [
                      ListTile(
                        title: Text('Ubicacion: ${asset.physicalLocation}'),
                        subtitle: Text(
                          'Dependencia: ${asset.dependency} | Programa: ${asset.program}\nValor: ${asset.acquisitionValue.toStringAsFixed(0)}',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.state.canManageAssets())
                            OutlinedButton(
                              onPressed: () => _editAssetDialog(context, asset),
                              child: const Text('Editar activo'),
                            ),
                          OutlinedButton(
                            onPressed: () => _showHistory(context, asset),
                            child: const Text('Ver historial'),
                          ),
                          if (widget.state.canManageAssets())
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar activo'),
                                    content: Text(
                                      'Eliminar el activo ${asset.code} - ${asset.name}?\nEsta accion no se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  widget.state.deleteAsset(asset);
                                }
                              },
                              child: const Text('Eliminar'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAssetDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final code = TextEditingController();
    final name = TextEditingController();
    final category = TextEditingController();
    final subcategory = TextEditingController();
    final location = TextEditingController();
    final dependency = TextEditingController();
    final costCenter = TextEditingController();
    final value = TextEditingController();
    final usefulLife = TextEditingController(text: '5');
    final observations = TextEditingController();
    final program = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? errorMsg;
        AppUser? selectedResponsible;
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return AlertDialog(
              title: const Text('Registrar activo (manual)'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorMsg != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMsg!,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _field(code, 'Codigo interno'),
                      _field(name, 'Nombre / descripcion'),
                      _field(category, 'Categoria'),
                      _field(subcategory, 'Subcategoria'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<AppUser>(
                        value: selectedResponsible,
                        decoration: const InputDecoration(
                          labelText: 'Responsable *',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.state.users
                            .where((u) => u.isActive)
                            .map(
                              (u) => DropdownMenuItem<AppUser>(
                                value: u,
                                child: Text(
                                  '${u.fullName}${u.area.isNotEmpty ? ' — ${u.area}' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (u) {
                          if (u == null) return;
                          setLocal(() {
                            selectedResponsible = u;
                            dependency.text = u.area;
                            location.text = u.area;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      _field(dependency, 'Área / Dependencia'),
                      _field(location, 'Ubicación física'),
                      _field(costCenter, 'Centro de costo'),
                      _field(program, 'Programa academico'),
                      _field(value, 'Valor adquisicion'),
                      _field(usefulLife, 'Vida util (anios)'),
                      _field(observations, 'Observaciones'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                      setLocal(
                        () => errorMsg =
                            'El código y el nombre son obligatorios.',
                      );
                      return;
                    }
                    if (selectedResponsible == null) {
                      setLocal(
                        () => errorMsg = 'Debes seleccionar un responsable.',
                      );
                      return;
                    }
                    if (widget.state.findAsset(code.text.trim()) != null) {
                      setLocal(
                        () => errorMsg = 'Ya existe un activo con ese código.',
                      );
                      return;
                    }
                    widget.state.addAsset(
                      Asset(
                        code: code.text.trim(),
                        name: name.text.trim(),
                        category: category.text.trim(),
                        subcategory: subcategory.text.trim(),
                        physicalLocation: location.text.trim(),
                        responsible: selectedResponsible!.fullName,
                        responsibleId: selectedResponsible!.id,
                        dependency: dependency.text.trim(),
                        costCenter: costCenter.text.trim(),
                        acquisitionValue:
                            double.tryParse(value.text.trim()) ?? 0,
                        acquisitionDate: DateTime.now(),
                        estimatedUsefulLifeYears:
                            int.tryParse(usefulLife.text.trim()) ?? 5,
                        state: AssetState.activo,
                        observations: observations.text.trim(),
                        program: program.text.trim(),
                      ),
                      performedBy:
                          widget.state.currentUser?.username ?? 'system',
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    messenger.clearSnackBars();
  }

  Future<void> _editAssetDialog(BuildContext context, Asset asset) async {
    final responsible = TextEditingController(text: asset.responsible);
    final location = TextEditingController(text: asset.physicalLocation);
    final notes = TextEditingController(text: asset.observations);
    AssetState selectedState = asset.state;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Actualizar ${asset.code}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(responsible, 'Responsable'),
                  _field(location, 'Ubicacion'),
                  _field(notes, 'Observaciones'),
                  DropdownButtonFormField<AssetState>(
                    value: selectedState,
                    items: AssetState.values
                        .map(
                          (s) => DropdownMenuItem<AssetState>(
                            value: s,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => selectedState = v);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.state.updateAsset(
                      asset,
                      performedBy:
                          widget.state.currentUser?.username ?? 'system',
                      newResponsible: responsible.text.trim(),
                      newLocation: location.text.trim(),
                      newState: selectedState,
                      notes: notes.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showHistory(BuildContext context, Asset asset) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Historial ${asset.code}'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: asset.history.length,
              itemBuilder: (context, index) {
                final item = asset.history[index];
                return ListTile(
                  title: Text(item.action),
                  subtitle: Text(
                    '${DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp)} | ${item.performedBy}\n${item.detail}',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _scanBarcode(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'En web usa registro manual por compatibilidad de camara.',
          ),
        ),
      );
      return;
    }

    String? scannedCode;
    await showDialog<void>(
      context: context,
      builder: (context) {
        bool handled = false;
        return AlertDialog(
          title: const Text('Escanear codigo de barras'),
          content: SizedBox(
            width: 320,
            height: 320,
            child: MobileScanner(
              onDetect: (capture) {
                if (handled) {
                  return;
                }
                final code = capture.barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  handled = true;
                  scannedCode = code;
                  Navigator.pop(context);
                }
              },
            ),
          ),
        );
      },
    );

    if (scannedCode == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final asset = widget.state.findAsset(scannedCode!);
    if (asset == null) {
      if (!context.mounted) return;
      if (widget.state.canManageAssets()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Activo no existe: $scannedCode. Debe registrarse manualmente.',
            ),
          ),
        );
      } else {
        // Roles de solo lectura: ofrecer reportar activo inexistente
        final notesCtrl = TextEditingController();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Activo no encontrado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El código "$scannedCode" no está registrado en el sistema.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.report_outlined),
                onPressed: () => Navigator.pop(ctx, true),
                label: const Text('Reportar al administrador'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          widget.state.reportMissingAsset(
            scannedCode: scannedCode!,
            notes: notesCtrl.text.trim(),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reporte enviado al administrador.'),
              ),
            );
          }
        }
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activo encontrado'),
        content: Text(
          '${asset.code}\n${asset.name}\n${asset.state.label}\n${asset.physicalLocation}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.state});

  final AppState state;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  InventorySession? selectedSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _createSessionDialog(context),
                icon: const Icon(Icons.add_task),
                label: const Text('Crear jornada inventario'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<InventorySession>(
                  value: selectedSession,
                  items: widget.state.inventorySessions
                      .map(
                        (s) => DropdownMenuItem<InventorySession>(
                          value: s,
                          child: Text(
                            '${s.id} - ${s.name} (${s.site}/${s.area})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedSession = value),
                  decoration: const InputDecoration(
                    labelText: 'Jornada activa',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedSession != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () =>
                        _registerVerification(context, selectedSession!),
                    child: const Text('Registrar verificacion'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final comparative = widget.state.comparativeReport(
                        selectedSession!,
                      );
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Comparativo previo/posterior'),
                          content: SingleChildScrollView(
                            child: Text(comparative),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Reporte comparativo'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (selectedSession == null)
                  const Card(
                    child: ListTile(
                      title: Text(
                        'Cree o seleccione una jornada para verificar activos.',
                      ),
                    ),
                  ),
                if (selectedSession != null)
                  ...selectedSession!.verifications.map(
                    (v) => Card(
                      child: ListTile(
                        title: Text('${v.assetCode} - ${v.result.label}'),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd HH:mm').format(v.timestamp)}\n${v.notes}\nEvidencia: ${v.photoPath ?? 'No adjunta'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSessionDialog(BuildContext context) async {
    final name = TextEditingController();
    final site = TextEditingController();
    final building = TextEditingController();
    final floor = TextEditingController();
    final area = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva jornada inventario fisico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre jornada'),
              ),
              TextField(
                controller: site,
                decoration: const InputDecoration(labelText: 'Sede'),
              ),
              TextField(
                controller: building,
                decoration: const InputDecoration(labelText: 'Edificio'),
              ),
              TextField(
                controller: floor,
                decoration: const InputDecoration(labelText: 'Piso'),
              ),
              TextField(
                controller: area,
                decoration: const InputDecoration(
                  labelText: 'Area/dependencia',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final session = widget.state.createInventorySession(
                  name: name.text,
                  site: site.text,
                  building: building.text,
                  floor: floor.text,
                  area: area.text,
                );
                setState(() => selectedSession = session);
                Navigator.pop(context);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerVerification(
    BuildContext context,
    InventorySession session,
  ) async {
    final code = TextEditingController();
    final notes = TextEditingController();
    VerificationResult result = VerificationResult.encontrado;
    String? photoPath;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Registrar verificacion por activo'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Codigo activo',
                      ),
                    ),
                    DropdownButtonFormField<VerificationResult>(
                      value: result,
                      items: VerificationResult.values
                          .map(
                            (r) => DropdownMenuItem<VerificationResult>(
                              value: r,
                              child: Text(r.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setLocal(() => result = v);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Resultado'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.camera,
                            );
                            if (picked != null) {
                              setLocal(() => photoPath = picked.path);
                            }
                          },
                          child: const Text('Adjuntar foto (opcional)'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(photoPath ?? 'Sin evidencia')),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final asset = widget.state.findAsset(code.text.trim());
                    if (asset == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Activo no existe en inventario. Registrelo manualmente en Activos.',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.state.registerVerification(
                      session: session,
                      assetCode: code.text.trim(),
                      result: result,
                      notes: notes.text,
                      photoPath: photoPath,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar verificacion'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key, required this.state});

  final AppState state;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.build_outlined), text: 'Mantenimientos'),
              Tab(
                icon: Icon(Icons.delete_sweep_outlined),
                text: 'Bajas de activos',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // ── Tab 1: Mantenimientos ──────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Mantenimientos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _newMaintenanceDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Solicitar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: widget.state.maintenanceRequests
                              .map(
                                (m) => Card(
                                  child: ListTile(
                                    leading: Icon(
                                      m.closed
                                          ? Icons.check_circle_outline
                                          : Icons.build_circle_outlined,
                                      color: m.closed
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    title: Text(
                                      '${m.assetCode} · ${m.type.name}',
                                    ),
                                    subtitle: Text(
                                      '${m.description}\n${m.id} · ${m.closed ? 'Cerrado' : 'Abierto'}',
                                    ),
                                    trailing: m.closed
                                        ? null
                                        : OutlinedButton(
                                            onPressed: () => widget.state
                                                .closeMaintenance(m),
                                            child: const Text('Cerrar'),
                                          ),
                                    isThreeLine: true,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Tab 2: Bajas ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Bajas de activos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _newDisposalDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Solicitar baja'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: widget.state.disposalRequests
                              .map(
                                (d) => Card(
                                  child: ListTile(
                                    leading: Icon(
                                      d.status == 'Aprobada'
                                          ? Icons.check_circle_outline
                                          : Icons.hourglass_top_outlined,
                                      color: d.status == 'Aprobada'
                                          ? Colors.green
                                          : Colors.deepOrange,
                                    ),
                                    title: Text('${d.assetCode} · ${d.status}'),
                                    subtitle: Text(
                                      '${d.cause}\n${d.justification} · ${d.id}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        if (!d.approvedByDependency &&
                                            widget.state.hasRole(
                                              UserRole.responsableArea,
                                            ))
                                          OutlinedButton(
                                            onPressed: () => widget.state
                                                .approveDisposalByDependency(d),
                                            child: const Text(
                                              'Aprueba Dependencia',
                                            ),
                                          ),
                                        if (!d.approvedByDAF &&
                                            widget.state.hasRole(
                                              UserRole.direccionAdminFin,
                                            ))
                                          OutlinedButton(
                                            onPressed: () => widget.state
                                                .approveDisposalByDAF(d),
                                            child: const Text('Aprueba DAF'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _newMaintenanceDialog(BuildContext context) async {
    final code = TextEditingController();
    final description = TextEditingController();
    MaintenanceType type = MaintenanceType.preventivo;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? errorMsg;
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            return AlertDialog(
              title: const Text('Solicitud de mantenimiento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Codigo activo *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MaintenanceType>(
                    value: type,
                    items: MaintenanceType.values
                        .map(
                          (t) => DropdownMenuItem<MaintenanceType>(
                            value: t,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => type = v);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion *',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final c = code.text.trim();
                    final d = description.text.trim();
                    if (c.isEmpty || d.isEmpty) {
                      setLocal(
                        () => errorMsg =
                            'El codigo del activo y la descripcion son obligatorios.',
                      );
                      return;
                    }
                    if (widget.state.findAsset(c) == null) {
                      setLocal(
                        () => errorMsg = 'No existe un activo con ese codigo.',
                      );
                      return;
                    }
                    widget.state.createMaintenance(
                      assetCode: c,
                      type: type,
                      description: d,
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _newDisposalDialog(BuildContext context) async {
    final code = TextEditingController();
    final cause = TextEditingController();
    final justification = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? errorMsg;
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            return AlertDialog(
              title: const Text('Solicitud de baja'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Codigo activo *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cause,
                    decoration: const InputDecoration(labelText: 'Causal *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: justification,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Justificacion',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final c = code.text.trim();
                    final ca = cause.text.trim();
                    if (c.isEmpty || ca.isEmpty) {
                      setLocal(
                        () => errorMsg =
                            'El codigo del activo y el causal son obligatorios.',
                      );
                      return;
                    }
                    if (widget.state.findAsset(c) == null) {
                      setLocal(
                        () => errorMsg = 'No existe un activo con ese codigo.',
                      );
                      return;
                    }
                    widget.state.createDisposal(
                      assetCode: c,
                      cause: ca,
                      justification: justification.text.trim(),
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Solicitar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Pantalla de Notificaciones ────────────────────────────────────────────────

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.state});

  final AppState state;

  Color _statusColor(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.aprobada:
        return const Color(0xFF00804E);
      case NotificationStatus.denegada:
        return Colors.red;
      case NotificationStatus.pendiente:
        return Colors.orange;
    }
  }

  IconData _statusIcon(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.aprobada:
        return Icons.check_circle_outline;
      case NotificationStatus.denegada:
        return Icons.cancel_outlined;
      case NotificationStatus.pendiente:
        return Icons.hourglass_top_outlined;
    }
  }

  String _statusLabel(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.aprobada:
        return 'Aprobada';
      case NotificationStatus.denegada:
        return 'Denegada';
      case NotificationStatus.pendiente:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifs = state.myNotifications;
    final isAdmin = state.hasRole(UserRole.administrador);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Notificaciones',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (notifs.any((n) => !n.read))
                TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Marcar todo leído'),
                  onPressed: state.markAllNotificationsRead,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (notifs.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 64,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sin notificaciones',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: notifs.length,
                itemBuilder: (context, index) {
                  final notif = notifs[index];
                  final unread = !notif.read;
                  return Card(
                    color: unread ? const Color(0xFFF0F7F4) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                notif.type == 'maintenance'
                                    ? Icons.build_outlined
                                    : Icons.delete_sweep_outlined,
                                size: 18,
                                color: const Color(0xFF00804E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    notif.status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _statusIcon(notif.status),
                                      size: 13,
                                      color: _statusColor(notif.status),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _statusLabel(notif.status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(notif.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notif.body,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(notif.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                          // Acciones solo para administrador y notif pendiente
                          if (isAdmin &&
                              notif.status == NotificationStatus.pendiente)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Denegar'),
                                    onPressed: () =>
                                        state.denyNotification(notif),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Aprobar'),
                                    onPressed: () =>
                                        state.approveNotification(notif),
                                  ),
                                ],
                              ),
                            ),
                          if (!isAdmin && unread)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    state.markNotificationRead(notif),
                                child: const Text('Marcar como leída'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.state});

  final AppState state;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final site = TextEditingController();
  final area = TextEditingController();
  final dependency = TextEditingController();
  final program = TextEditingController();
  final responsible = TextEditingController();
  final category = TextEditingController();
  AssetState? stateFilter;
  ReportPeriod period = ReportPeriod.mensual;
  List<Asset> currentReport = [];

  @override
  void initState() {
    super.initState();
    currentReport = widget.state.assets;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reportes institucionales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallFilter(site, 'Sede'),
              _smallFilter(area, 'Area'),
              _smallFilter(dependency, 'Dependencia'),
              _smallFilter(program, 'Programa'),
              _smallFilter(responsible, 'Responsable'),
              _smallFilter(category, 'Categoria'),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<AssetState?>(
                  value: stateFilter,
                  items: [
                    const DropdownMenuItem<AssetState?>(
                      value: null,
                      child: Text('Todos estados'),
                    ),
                    ...AssetState.values.map(
                      (s) => DropdownMenuItem<AssetState?>(
                        value: s,
                        child: Text(s.label),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => stateFilter = v),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<ReportPeriod>(
                  value: period,
                  items: ReportPeriod.values
                      .map(
                        (p) => DropdownMenuItem<ReportPeriod>(
                          value: p,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => period = v);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Periodo consolidado',
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    currentReport = widget.state.reportFilteredAssets(
                      site: site.text,
                      area: area.text,
                      dependency: dependency.text,
                      program: program.text,
                      responsible: responsible.text,
                      category: category.text,
                      state: stateFilter,
                    );
                  });
                },
                child: const Text('Generar reporte'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final csv = widget.state.generateCsv(currentReport);
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV generado y copiado al portapapeles.'),
                    ),
                  );
                },
                child: const Text('Exportar CSV'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final bytes = await widget.state.generatePdfBytes(
                    currentReport,
                    period: period,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('PDF generado'),
                      content: Text(
                        'Bytes generados: ${bytes.length}\nBase64 (fragmento): ${base64Encode(bytes).substring(0, min(120, base64Encode(bytes).length))}...',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Exportar PDF'),
              ),
              OutlinedButton(
                onPressed: () => _showAuditReport(context),
                child: const Text('Reporte auditoria'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Resultados: ${currentReport.length} activos'),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: currentReport
                  .map(
                    (a) => Card(
                      child: ListTile(
                        title: Text('${a.code} - ${a.name}'),
                        subtitle: Text(
                          'Estado: ${a.state.label} | Dependencia: ${a.dependency}\nDepreciado: ${widget.state.depreciationValue(a, DateTime.now()).toStringAsFixed(0)}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallFilter(TextEditingController c, String label) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _showAuditReport(BuildContext context) async {
    final findings = widget.state.auditFindings();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reporte de auditoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No encontrados: ${(findings['notFound'] as List).join(', ')}',
              ),
              Text(
                'Duplicados: ${(findings['duplicated'] as List).join(', ')}',
              ),
              Text(
                'Sin responsable: ${(findings['withoutResponsible'] as List).join(', ')}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class IntegrationPage extends StatefulWidget {
  const IntegrationPage({super.key, required this.state});

  final AppState state;

  @override
  State<IntegrationPage> createState() => _IntegrationPageState();
}

class _IntegrationPageState extends State<IntegrationPage> {
  late final TextEditingController host;
  late final TextEditingController port;
  late final TextEditingController database;
  late final TextEditingController username;
  late final TextEditingController password;
  String result = 'Sin probar';

  @override
  void initState() {
    super.initState();
    final cfg = widget.state.postgresConfig;
    host = TextEditingController(text: cfg.host);
    port = TextEditingController(text: cfg.port.toString());
    database = TextEditingController(text: cfg.database);
    username = TextEditingController(text: cfg.username);
    password = TextEditingController(text: cfg.password);
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    database.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Integracion PostgreSQL (datos maestros)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: host,
            decoration: const InputDecoration(labelText: 'Host'),
          ),
          TextField(
            controller: port,
            decoration: const InputDecoration(labelText: 'Puerto'),
          ),
          TextField(
            controller: database,
            decoration: const InputDecoration(labelText: 'Base de datos'),
          ),
          TextField(
            controller: username,
            decoration: const InputDecoration(labelText: 'Usuario'),
          ),
          TextField(
            controller: password,
            decoration: const InputDecoration(labelText: 'Clave'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: () async {
                  widget.state.postgresConfig.host = host.text.trim();
                  widget.state.postgresConfig.port =
                      int.tryParse(port.text.trim()) ?? 5432;
                  widget.state.postgresConfig.database = database.text.trim();
                  widget.state.postgresConfig.username = username.text.trim();
                  widget.state.postgresConfig.password = password.text;
                  final response = await widget.state.testPostgresConnection();
                  setState(() => result = response);
                },
                child: const Text('Probar conexion'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(result),
          const SizedBox(height: 20),
          const Text(
            'Nota: esta integracion minima valida conectividad y deja preparado el punto para consumo de datos maestros de activos/dependencias.',
          ),
        ],
      ),
    );
  }
}
