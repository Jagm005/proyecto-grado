import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:postgres/postgres.dart';

void main() {
  runApp(InventoryApp(state: AppState()..seedData()));
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
              seedColor: const Color(0xFF0E6BA8),
            ),
            useMaterial3: true,
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
  List<UserRole> roles;
  bool isActive;
  DateTime? lastSession;
  int failedAttempts;
  DateTime? lockUntil;
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
}

class Asset {
  Asset({
    required this.code,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.physicalLocation,
    required this.responsible,
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
  String dependency;
  String costCenter;
  double acquisitionValue;
  DateTime acquisitionDate;
  int estimatedUsefulLifeYears;
  AssetState state;
  String observations;
  String program;
  final List<AssetHistoryEvent> history;
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

class AppState extends ChangeNotifier {
  final List<AppUser> users = [];
  final List<Asset> assets = [];
  final List<InventorySession> inventorySessions = [];
  final List<MaintenanceRequest> maintenanceRequests = [];
  final List<DisposalRequest> disposalRequests = [];
  final PostgresConfig postgresConfig = PostgresConfig();

  AppUser? currentUser;
  AuthMode authMode = AuthMode.institutional;
  int maxFailedAttempts = 3;

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
        roles: [UserRole.administrador, UserRole.soporteTI],
      ),
      AppUser(
        id: 'U002',
        username: 'auxiliar',
        fullName: 'Auxiliar Inventario',
        email: 'auxiliar@universidad.edu',
        password: 'aux123',
        roles: [UserRole.auxiliarInventario],
      ),
      AppUser(
        id: 'U003',
        username: 'auditor',
        fullName: 'Auditoria Interna',
        email: 'auditor@universidad.edu',
        password: 'audit123',
        roles: [UserRole.auditor],
      ),
      AppUser(
        id: 'U004',
        username: 'daf',
        fullName: 'Direccion Admin Fin',
        email: 'daf@universidad.edu',
        password: 'daf123',
        roles: [UserRole.direccionAdminFin],
      ),
    ]);

    addAsset(
      Asset(
        code: 'ACT-1001',
        name: 'Laptop Dell 5420',
        category: 'Computo',
        subcategory: 'Portatil',
        physicalLocation: 'Sede Centro - Bloque A - Piso 2',
        responsible: 'Auxiliar Inventario',
        dependency: 'Direccion Administrativa',
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
        physicalLocation: 'Sede Norte - Bloque C - Piso 1',
        responsible: 'Responsable Area Sistemas',
        dependency: 'Tecnologia',
        costCenter: 'CC-TI-02',
        acquisitionValue: 890000,
        acquisitionDate: DateTime(2022, 8, 14),
        estimatedUsefulLifeYears: 8,
        state: AssetState.activo,
        observations: 'Uso diario',
        program: 'Ingenieria',
      ),
      performedBy: 'system',
    );
  }

  bool hasRole(UserRole role) {
    return currentUser?.roles.contains(role) ?? false;
  }

  bool canManageUsers() => hasRole(UserRole.administrador);

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

  /// Retorna null si el login fue exitoso.
  /// Retorna un String con el codigo del error para que la UI distinga el tipo:
  ///   Prefijo  LOCK:segundos   - cuenta bloqueada (RF03)
  ///   Prefijo  WARN:restantes  - credenciales invalidas, muestra intentos restantes (RF03)
  ///   Prefijo  INFO:mensaje    - error informativo sin conteo
  String? login(String username, String password) {
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
    user.password = temporaryPassword;
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
    required List<UserRole> roles,
    required bool isActive,
  }) {
    user.fullName = fullName;
    user.email = email;
    user.roles = roles;
    user.isActive = isActive;
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
    maintenanceRequests.add(
      MaintenanceRequest(
        id: 'MNT-${maintenanceRequests.length + 1}',
        assetCode: assetCode,
        type: type,
        description: description,
        createdBy: currentUser?.username ?? 'system',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void closeMaintenance(MaintenanceRequest req) {
    req.closed = true;
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

  void _handleLogin() {
    _lockTimer?.cancel();
    final raw = widget.state.login(
      _userController.text,
      _passwordController.text,
    );
    if (raw == null) {
      return; // exitoso → AppState notifica y la app navega a HomePage
    }
    final parts = raw.split(':');
    final prefix = parts[0];
    final payload = parts.length > 1 ? parts[1] : '';

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
    final locked = _authError == _AuthError.locked;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sistema de Inventario Institucional',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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
                    icon: const Icon(Icons.login),
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
                            avatar: const Icon(Icons.badge_outlined, size: 16),
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
    final pages = <Widget>[
      DashboardPage(state: widget.state),
      UsersPage(state: widget.state),
      AssetsPage(state: widget.state),
      InventoryPage(state: widget.state),
      MaintenancePage(state: widget.state),
      ReportsPage(state: widget.state),
      IntegrationPage(state: widget.state),
    ];

    // RF02: construye los chips de roles del usuario autenticado
    final roleChips = (widget.state.currentUser?.roles ?? <UserRole>[])
        .map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Chip(
              label: Text(r.label, style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.state.currentUser?.fullName ?? ''),
            const SizedBox(width: 10),
            ...roleChips,
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.state.logout,
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Usuarios'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2),
                label: Text('Activos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check),
                label: Text('Inventario'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build),
                label: Text('Manto/Bajas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment),
                label: Text('Reportes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storage),
                label: Text('PostgreSQL'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_tabIndex]),
        ],
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard('Usuarios', state.users.length.toString()),
            _metricCard('Activos', state.assets.length.toString()),
            _metricCard('Jornadas', state.inventorySessions.length.toString()),
            _metricCard(
              'Mantenimientos',
              state.maintenanceRequests.length.toString(),
            ),
            _metricCard('Bajas', state.disposalRequests.length.toString()),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Roles del usuario actual: ${state.currentUser?.roles.map((r) => r.label).join(', ') ?? ''}',
        ),
        const SizedBox(height: 8),
        Text(
          'Ultima sesion: ${state.currentUser?.lastSession != null ? DateFormat('yyyy-MM-dd HH:mm').format(state.currentUser!.lastSession!) : 'N/A'}',
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editUserDialog(context, user),
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
    final password = TextEditingController();
    final selectedRoles = <UserRole>{UserRole.auxiliarInventario};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Crear usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: fullName,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional',
                      ),
                    ),
                    TextField(
                      controller: password,
                      decoration: const InputDecoration(
                        labelText: 'Clave inicial',
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
                      ),
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
                    widget.state.createUser(
                      AppUser(
                        id: 'U${widget.state.users.length + 1}'.padLeft(4, '0'),
                        username: username.text,
                        fullName: fullName.text,
                        email: email.text,
                        password: password.text,
                        roles: selectedRoles.toList(),
                      ),
                    );
                    Navigator.pop(context);
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
    bool isActive = user.isActive;
    final selectedRoles = <UserRole>{...user.roles};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Editar ${user.username}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullName,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Correo'),
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
                      ),
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
                    widget.state.updateUser(
                      user,
                      fullName: fullName.text,
                      email: email.text,
                      roles: selectedRoles.toList(),
                      isActive: isActive,
                    );
                    Navigator.pop(context);
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
              FilledButton.icon(
                onPressed: () => _createAssetDialog(context),
                icon: const Icon(Icons.add_box),
                label: const Text('Registrar activo'),
              ),
              const SizedBox(width: 8),
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
                          OutlinedButton(
                            onPressed: () => _editAssetDialog(context, asset),
                            child: const Text('Editar activo'),
                          ),
                          OutlinedButton(
                            onPressed: () => _showHistory(context, asset),
                            child: const Text('Ver historial'),
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
    final code = TextEditingController();
    final name = TextEditingController();
    final category = TextEditingController();
    final subcategory = TextEditingController();
    final location = TextEditingController();
    final responsible = TextEditingController();
    final dependency = TextEditingController();
    final costCenter = TextEditingController();
    final value = TextEditingController();
    final usefulLife = TextEditingController(text: '5');
    final observations = TextEditingController();
    final program = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar activo (manual)'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(code, 'Codigo interno'),
                  _field(name, 'Nombre / descripcion'),
                  _field(category, 'Categoria'),
                  _field(subcategory, 'Subcategoria'),
                  _field(location, 'Ubicacion fisica'),
                  _field(responsible, 'Responsable'),
                  _field(dependency, 'Dependencia'),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                widget.state.addAsset(
                  Asset(
                    code: code.text.trim(),
                    name: name.text.trim(),
                    category: category.text.trim(),
                    subcategory: subcategory.text.trim(),
                    physicalLocation: location.text.trim(),
                    responsible: responsible.text.trim(),
                    dependency: dependency.text.trim(),
                    costCenter: costCenter.text.trim(),
                    acquisitionValue: double.tryParse(value.text.trim()) ?? 0,
                    acquisitionDate: DateTime.now(),
                    estimatedUsefulLifeYears:
                        int.tryParse(usefulLife.text.trim()) ?? 5,
                    state: AssetState.activo,
                    observations: observations.text.trim(),
                    program: program.text.trim(),
                  ),
                  performedBy: widget.state.currentUser?.username ?? 'system',
                );
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Activo no existe: $scannedCode. Debe registrarse manualmente.',
          ),
        ),
      );
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mantenimientos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _newMaintenanceDialog(context),
                      child: const Text('Solicitar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: widget.state.maintenanceRequests
                        .map(
                          (m) => Card(
                            child: ListTile(
                              title: Text(
                                '${m.id} | ${m.assetCode} | ${m.type.name}',
                              ),
                              subtitle: Text(
                                '${m.description}\nEstado: ${m.closed ? 'Cerrado' : 'Abierto'}',
                              ),
                              trailing: m.closed
                                  ? null
                                  : OutlinedButton(
                                      onPressed: () =>
                                          widget.state.closeMaintenance(m),
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
          const VerticalDivider(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bajas de activos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _newDisposalDialog(context),
                      child: const Text('Solicitar baja'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: widget.state.disposalRequests
                        .map(
                          (d) => Card(
                            child: ListTile(
                              title: Text(
                                '${d.id} | ${d.assetCode} | ${d.status}',
                              ),
                              subtitle: Text('${d.cause} - ${d.justification}'),
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
                                      child: const Text('Aprueba Dependencia'),
                                    ),
                                  if (!d.approvedByDAF &&
                                      widget.state.hasRole(
                                        UserRole.direccionAdminFin,
                                      ))
                                    OutlinedButton(
                                      onPressed: () =>
                                          widget.state.approveDisposalByDAF(d),
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
    );
  }

  Future<void> _newMaintenanceDialog(BuildContext context) async {
    final code = TextEditingController();
    final description = TextEditingController();
    MaintenanceType type = MaintenanceType.preventivo;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Solicitud de mantenimiento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Codigo activo',
                    ),
                  ),
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
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descripcion'),
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
                    widget.state.createMaintenance(
                      assetCode: code.text.trim(),
                      type: type,
                      description: description.text.trim(),
                    );
                    Navigator.pop(context);
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Solicitud de baja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Codigo activo'),
              ),
              TextField(
                controller: cause,
                decoration: const InputDecoration(labelText: 'Causal'),
              ),
              TextField(
                controller: justification,
                decoration: const InputDecoration(labelText: 'Justificacion'),
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
                widget.state.createDisposal(
                  assetCode: code.text.trim(),
                  cause: cause.text.trim(),
                  justification: justification.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('Solicitar'),
            ),
          ],
        );
      },
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
