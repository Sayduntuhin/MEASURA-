import 'package:cloud_firestore/cloud_firestore.dart';
import 'tolerance_standard.dart';

/// A single POM (Point of Measure) row from a specification tech-pack.
class SpecPomRow {
  final int no;
  final String pomCode;
  final String description;
  final String variation;
  /// Map of size -> spec measurement string, e.g. {"30/30": "32 1/4", "30/32": "32 1/4"}
  final Map<String, String> sizeSpecs;

  SpecPomRow({
    required this.no,
    required this.pomCode,
    required this.description,
    this.variation = '',
    required this.sizeSpecs,
  });

  Map<String, dynamic> toMap() {
    return {
      'no': no,
      'pomCode': pomCode,
      'description': description,
      'variation': variation,
      'sizeSpecs': sizeSpecs,
    };
  }

  factory SpecPomRow.fromMap(Map<String, dynamic> map) {
    return SpecPomRow(
      no: (map['no'] as num?)?.toInt() ?? 0,
      pomCode: map['pomCode'] ?? '',
      description: map['description'] ?? '',
      variation: map['variation'] ?? '',
      sizeSpecs: Map<String, String>.from(map['sizeSpecs'] ?? {}),
    );
  }

  SpecPomRow copyWith({
    int? no,
    String? pomCode,
    String? description,
    String? variation,
    Map<String, String>? sizeSpecs,
  }) {
    return SpecPomRow(
      no: no ?? this.no,
      pomCode: pomCode ?? this.pomCode,
      description: description ?? this.description,
      variation: variation ?? this.variation,
      sizeSpecs: sizeSpecs ?? Map<String, String>.from(this.sizeSpecs),
    );
  }
}

/// A recorded sample reading for a specific POM, size, and sample number (1..5).
class SampleReading {
  final String pomCode;
  final String size;
  final int sampleIndex; // 1-indexed (1 to 5)
  final double deviation; // e.g. -0.25, 0.0, 0.125
  final String deviationText; // e.g. "-1/4", "0", "+1/8"
  final DateTime recordedAt;

  SampleReading({
    required this.pomCode,
    required this.size,
    required this.sampleIndex,
    required this.deviation,
    required this.deviationText,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'pomCode': pomCode,
      'size': size,
      'sampleIndex': sampleIndex,
      'deviation': deviation,
      'deviationText': deviationText,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory SampleReading.fromMap(Map<String, dynamic> map) {
    return SampleReading(
      pomCode: map['pomCode'] ?? '',
      size: map['size'] ?? '',
      sampleIndex: (map['sampleIndex'] as num?)?.toInt() ?? 1,
      deviation: (map['deviation'] as num?)?.toDouble() ?? 0.0,
      deviationText: map['deviationText'] ?? '0',
      recordedAt: map['recordedAt'] is Timestamp
          ? (map['recordedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

/// The complete Garment Spec Sheet and digital inspection job.
class GarmentSpecSheet {
  final String id;
  final String userId;
  final String style;
  final String po;
  final String brand;
  final String stage; // e.g. "Before Wash", "Finished Product"
  final DateTime date;
  final double tolerance; // default/fallback symmetric tolerance, e.g. 0.25 for ±1/4"
  final ToleranceCategory toleranceCategory;
  /// Custom manual tolerance per POM code: e.g. {"B1": PomTolerance(posTol: 1.0, negTol: 0.5)}
  final Map<String, PomTolerance> customPomTolerances;
  final int sampleCountPerSize; // usually 5, matching the paper form columns
  final List<String> sizes;
  final List<SpecPomRow> poms;
  /// Key: "${pomCode}_${size}_${sampleIndex}" -> SampleReading
  final Map<String, SampleReading> readings;
  final DateTime createdAt;

  GarmentSpecSheet({
    required this.id,
    this.userId = '',
    required this.style,
    this.po = '',
    this.brand = '',
    this.stage = 'Before Wash',
    required this.date,
    this.tolerance = 0.25,
    this.toleranceCategory = ToleranceCategory.adultMaleStretch,
    Map<String, PomTolerance>? customPomTolerances,
    this.sampleCountPerSize = 5,
    required this.sizes,
    required this.poms,
    Map<String, SampleReading>? readings,
    DateTime? createdAt,
  })  : customPomTolerances = customPomTolerances ?? {},
        readings = readings ?? {},
        createdAt = createdAt ?? DateTime.now();

  static String cellKey(String pomCode, String size, int sampleIndex) {
    return '${pomCode}_${size}_$sampleIndex';
  }

  SampleReading? getReading(String pomCode, String size, int sampleIndex) {
    return readings[cellKey(pomCode, size, sampleIndex)];
  }

  /// Resolves the specific positive/negative tolerance for a POM,
  /// accounting for manual overrides, Kontoor categories, and waist >= 38" logic.
  PomTolerance getPomTolerance(String pomCode, {String? size}) {
    if (customPomTolerances.containsKey(pomCode)) {
      return customPomTolerances[pomCode]!;
    }

    final pomRow = poms.cast<SpecPomRow?>().firstWhere(
      (p) => p?.pomCode == pomCode,
      orElse: () => null,
    );

    final desc = pomRow?.description ?? '';
    final specVal = (size != null && pomRow != null) ? pomRow.sizeSpecs[size] : null;
    final is38OrAbove = size != null
        ? KontoorToleranceEngine.isSizeOrSpec38OrAbove(size: size, specValue: specVal)
        : false;

    return KontoorToleranceEngine.getStandardTolerance(
      category: toleranceCategory,
      pomCode: pomCode,
      description: desc,
      is38OrAbove: is38OrAbove,
      defaultTolerance: tolerance,
    );
  }

  bool isWithinTolerance(double deviation, {String? pomCode, String? size}) {
    if (pomCode != null) {
      final pomTol = getPomTolerance(pomCode, size: size);
      return pomTol.isWithin(deviation);
    }
    return deviation.abs() <= (tolerance + 0.0001);
  }

  /// Total number of sample cells recorded
  int get recordedCount => readings.length;

  /// Total out of tolerance sample count
  int get outOfToleranceCount {
    return readings.values
        .where((r) => !isWithinTolerance(r.deviation, pomCode: r.pomCode, size: r.size))
        .length;
  }

  /// Pass rate between 0.0 and 1.0
  double get passRate {
    if (readings.isEmpty) return 1.0;
    final passing = readings.values
        .where((r) => isWithinTolerance(r.deviation, pomCode: r.pomCode, size: r.size))
        .length;
    return passing / readings.length;
  }

  GarmentSpecSheet copyWith({
    String? id,
    String? userId,
    String? style,
    String? po,
    String? brand,
    String? stage,
    DateTime? date,
    double? tolerance,
    ToleranceCategory? toleranceCategory,
    Map<String, PomTolerance>? customPomTolerances,
    int? sampleCountPerSize,
    List<String>? sizes,
    List<SpecPomRow>? poms,
    Map<String, SampleReading>? readings,
    DateTime? createdAt,
  }) {
    return GarmentSpecSheet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      style: style ?? this.style,
      po: po ?? this.po,
      brand: brand ?? this.brand,
      stage: stage ?? this.stage,
      date: date ?? this.date,
      tolerance: tolerance ?? this.tolerance,
      toleranceCategory: toleranceCategory ?? this.toleranceCategory,
      customPomTolerances: customPomTolerances ?? Map<String, PomTolerance>.from(this.customPomTolerances),
      sampleCountPerSize: sampleCountPerSize ?? this.sampleCountPerSize,
      sizes: sizes ?? List<String>.from(this.sizes),
      poms: poms ?? List<SpecPomRow>.from(this.poms),
      readings: readings ?? Map<String, SampleReading>.from(this.readings),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final readingsMap = <String, dynamic>{};
    readings.forEach((key, val) {
      readingsMap[key] = val.toMap();
    });

    final customTolMap = <String, dynamic>{};
    customPomTolerances.forEach((key, val) {
      customTolMap[key] = val.toMap();
    });

    return {
      'id': id,
      'userId': userId,
      'style': style,
      'po': po,
      'brand': brand,
      'stage': stage,
      'date': Timestamp.fromDate(date),
      'tolerance': tolerance,
      'toleranceCategory': toleranceCategory.name,
      'customPomTolerances': customTolMap,
      'sampleCountPerSize': sampleCountPerSize,
      'sizes': sizes,
      'poms': poms.map((p) => p.toMap()).toList(),
      'readings': readingsMap,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GarmentSpecSheet.fromMap(String id, Map<String, dynamic> map) {
    final rawReadings = map['readings'] as Map<String, dynamic>? ?? {};
    final readings = <String, SampleReading>{};
    rawReadings.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        readings[key] = SampleReading.fromMap(val);
      }
    });

    final rawCustomTol = map['customPomTolerances'] as Map<String, dynamic>? ?? {};
    final customPomTolerances = <String, PomTolerance>{};
    rawCustomTol.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        customPomTolerances[key] = PomTolerance.fromMap(val);
      }
    });

    final rawPoms = map['poms'] as List<dynamic>? ?? [];
    final poms = rawPoms
        .map((p) => SpecPomRow.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    return GarmentSpecSheet(
      id: id,
      userId: map['userId'] ?? '',
      style: map['style'] ?? '',
      po: map['po'] ?? '',
      brand: map['brand'] ?? '',
      stage: map['stage'] ?? 'Before Wash',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      tolerance: (map['tolerance'] as num?)?.toDouble() ?? 0.25,
      toleranceCategory: ToleranceCategory.fromString(map['toleranceCategory'] as String?),
      customPomTolerances: customPomTolerances,
      sampleCountPerSize: (map['sampleCountPerSize'] as num?)?.toInt() ?? 5,
      sizes: List<String>.from(map['sizes'] ?? []),
      poms: poms,
      readings: readings,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

