import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../models/measurement_point.dart';
import '../models/spec_sheet_model.dart';
import 'histogram_image_renderer.dart';

class ExcelExportService {
  /// Generates full .xlsx bytes formatted like the digital inspection sheet
  /// and embeds the live measurement deviation histogram (visual chart image + frequency table).
  static Future<List<int>> generateExcelBytes(
    GarmentSpecSheet specSheet, {
    List<String>? selectedSizes,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook(2);
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Inspection Sheet';
    final xlsio.Worksheet analyticsSheet = workbook.worksheets[1];
    analyticsSheet.name = 'Histogram & Analytics';

    // 1. Header Metadata Section
    // Title Banner (Rows 1-3)
    final xlsio.Range titleRange = sheet.getRangeByName('A1:H1');
    titleRange.merge();
    titleRange.setText('MEASURA - GARMENT MEASUREMENT INSPECTION REPORT');
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.backColor = '#0F172A'; // Dark Navy
    titleRange.cellStyle.fontColor = '#FFFFFF';
    titleRange.cellStyle.hAlign = xlsio.HAlignType.center;
    titleRange.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 36);

    // Meta Details (Row 2 & 3)
    sheet.getRangeByName('A2').setText('STYLE:');
    sheet.getRangeByName('A2').cellStyle.bold = true;
    sheet.getRangeByName('B2').setText(specSheet.style);

    sheet.getRangeByName('C2').setText('PO:');
    sheet.getRangeByName('C2').cellStyle.bold = true;
    sheet.getRangeByName('D2').setText(specSheet.po.isNotEmpty ? specSheet.po : 'N/A');

    sheet.getRangeByName('E2').setText('BRAND:');
    sheet.getRangeByName('E2').cellStyle.bold = true;
    sheet.getRangeByName('F2').setText(specSheet.brand);

    sheet.getRangeByName('A3').setText('STAGE:');
    sheet.getRangeByName('A3').cellStyle.bold = true;
    sheet.getRangeByName('B3').setText(specSheet.stage);

    sheet.getRangeByName('C3').setText('TOLERANCE:');
    sheet.getRangeByName('C3').cellStyle.bold = true;
    sheet.getRangeByName('D3').setText('±${specSheet.tolerance}" (${specSheet.toleranceCategory.shortLabel})');

    sheet.getRangeByName('E3').setText('DATE:');
    sheet.getRangeByName('E3').cellStyle.bold = true;
    final now = DateTime.now();
    sheet.getRangeByName('F3').setText('${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

    // Style meta rows
    for (int r = 2; r <= 3; r++) {
      sheet.setRowHeightInPixels(r, 22);
      for (int c = 1; c <= 6; c++) {
        final cell = sheet.getRangeByIndex(r, c);
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.backColor = '#F8FAFC';
      }
    }

    // 2. Table Column Headers
    // Row 5: Top Header (POM, Description, Sizes)
    // Row 6: Sub-column Header (Spec, 1, 2, 3, 4, 5)
    const int headerRow1 = 5;
    const int headerRow2 = 6;
    sheet.setRowHeightInPixels(headerRow1, 26);
    sheet.setRowHeightInPixels(headerRow2, 24);

    // POM Col (Col 1)
    final pomHeader = sheet.getRangeByIndex(headerRow1, 1, headerRow2, 1);
    pomHeader.merge();
    pomHeader.setText('POM');
    _styleHeaderCell(pomHeader, isNavy: true);

    // Description Col (Col 2)
    final descHeader = sheet.getRangeByIndex(headerRow1, 2, headerRow2, 2);
    descHeader.merge();
    descHeader.setText('DESCRIPTION');
    _styleHeaderCell(descHeader, isNavy: true);

    final sizes = (selectedSizes != null && selectedSizes.isNotEmpty)
        ? specSheet.sizes.where((s) => selectedSizes.contains(s)).toList()
        : specSheet.sizes;

    final samplesCount = specSheet.sampleCountPerSize;
    final int subColsPerSize = 1 + samplesCount; // 1 Spec + N Samples

    int currentCol = 3;
    for (final size in sizes) {
      final int sizeStartCol = currentCol;
      final int sizeEndCol = currentCol + subColsPerSize - 1;

      // Size Group Header (Row 5)
      final sizeHeader = sheet.getRangeByIndex(headerRow1, sizeStartCol, headerRow1, sizeEndCol);
      sizeHeader.merge();
      sizeHeader.setText('Size: $size');
      sizeHeader.cellStyle.bold = true;
      sizeHeader.cellStyle.fontSize = 11;
      sizeHeader.cellStyle.backColor = '#1E3A8A'; // Primary Navy Blue
      sizeHeader.cellStyle.fontColor = '#FFFFFF';
      sizeHeader.cellStyle.hAlign = xlsio.HAlignType.center;
      sizeHeader.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(sizeHeader);

      // Sub-columns (Row 6)
      // Spec
      final specCell = sheet.getRangeByIndex(headerRow2, sizeStartCol);
      specCell.setText('SPEC');
      specCell.cellStyle.bold = true;
      specCell.cellStyle.fontSize = 10;
      specCell.cellStyle.backColor = '#E2E8F0';
      specCell.cellStyle.hAlign = xlsio.HAlignType.center;
      specCell.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(specCell);

      // Sample 1..5
      for (int sIdx = 1; sIdx <= samplesCount; sIdx++) {
        final sampleHeader = sheet.getRangeByIndex(headerRow2, sizeStartCol + sIdx);
        sampleHeader.setText('SMP $sIdx');
        sampleHeader.cellStyle.bold = true;
        sampleHeader.cellStyle.fontSize = 10;
        sampleHeader.cellStyle.backColor = '#F1F5F9';
        sampleHeader.cellStyle.fontColor = '#2563EB';
        sampleHeader.cellStyle.hAlign = xlsio.HAlignType.center;
        sampleHeader.cellStyle.vAlign = xlsio.VAlignType.center;
        _setBorders(sampleHeader);
      }

      currentCol += subColsPerSize;
    }

    final int totalCols = currentCol - 1;

    // 3. Data Rows
    int currentRow = 7;
    for (final pom in specSheet.poms) {
      sheet.setRowHeightInPixels(currentRow, 22);

      // Col 1: POM Code
      final pomCell = sheet.getRangeByIndex(currentRow, 1);
      pomCell.setText(pom.pomCode);
      pomCell.cellStyle.bold = true;
      pomCell.cellStyle.fontSize = 10;
      pomCell.cellStyle.fontColor = '#2563EB';
      pomCell.cellStyle.hAlign = xlsio.HAlignType.center;
      pomCell.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(pomCell);

      // Col 2: Description
      final descCell = sheet.getRangeByIndex(currentRow, 2);
      descCell.setText(pom.description);
      descCell.cellStyle.fontSize = 10;
      descCell.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(descCell);

      // Size columns
      int dataCol = 3;
      for (final size in sizes) {
        final specVal = pom.sizeSpecs[size] ?? '-';

        // Spec Value Cell
        final specValCell = sheet.getRangeByIndex(currentRow, dataCol);
        specValCell.setText(specVal);
        specValCell.cellStyle.bold = true;
        specValCell.cellStyle.fontSize = 10;
        specValCell.cellStyle.backColor = '#F8FAFC';
        specValCell.cellStyle.hAlign = xlsio.HAlignType.center;
        specValCell.cellStyle.vAlign = xlsio.VAlignType.center;
        _setBorders(specValCell);

        // Samples 1..N
        for (int sIdx = 1; sIdx <= samplesCount; sIdx++) {
          final sampleCell = sheet.getRangeByIndex(currentRow, dataCol + sIdx);
          final reading = specSheet.getReading(pom.pomCode, size, sIdx);

          if (reading != null) {
            sampleCell.setText(reading.deviationText);
            sampleCell.cellStyle.bold = true;
            sampleCell.cellStyle.fontSize = 10;
            sampleCell.cellStyle.hAlign = xlsio.HAlignType.center;
            sampleCell.cellStyle.vAlign = xlsio.VAlignType.center;

            final isWithin = specSheet.isWithinTolerance(reading.deviation, pomCode: pom.pomCode, size: size);
            if (reading.deviation == 0.0) {
              sampleCell.cellStyle.backColor = '#DCFCE7'; // Light green
              sampleCell.cellStyle.fontColor = '#15803D';
            } else if (isWithin) {
              sampleCell.cellStyle.backColor = '#F0FDF4'; // Soft green
              sampleCell.cellStyle.fontColor = '#166534';
            } else {
              sampleCell.cellStyle.backColor = '#FEE2E2'; // Light red
              sampleCell.cellStyle.fontColor = '#B91C1C';
            }
          } else {
            sampleCell.setText('-');
            sampleCell.cellStyle.fontSize = 10;
            sampleCell.cellStyle.fontColor = '#94A3B8';
            sampleCell.cellStyle.hAlign = xlsio.HAlignType.center;
            sampleCell.cellStyle.vAlign = xlsio.VAlignType.center;
          }
          _setBorders(sampleCell);
        }

        dataCol += subColsPerSize;
      }

      currentRow++;
    }

    // 4. Inspection Statistics Summary (Bottom of Sheet)
    currentRow += 2;
    final int total = specSheet.recordedCount;
    final int outOfTol = specSheet.outOfToleranceCount;
    final int inTol = total - outOfTol;
    final int passRate = (total == 0) ? 100 : ((inTol / total) * 100).round();

    final summaryHeader = sheet.getRangeByIndex(currentRow, 1, currentRow, 4);
    summaryHeader.merge();
    summaryHeader.setText('QA INSPECTION SUMMARY & PASS RATE');
    summaryHeader.cellStyle.bold = true;
    summaryHeader.cellStyle.fontSize = 11;
    summaryHeader.cellStyle.backColor = '#0F172A';
    summaryHeader.cellStyle.fontColor = '#FFFFFF';
    summaryHeader.cellStyle.hAlign = xlsio.HAlignType.center;
    summaryHeader.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(currentRow, 26);

    final stats = [
      ['Total Measurements Taken', '$total'],
      ['In Tolerance (Accepted)', '$inTol'],
      ['Out of Tolerance (Defects)', '$outOfTol'],
      ['Overall Pass Rate', '$passRate%'],
    ];

    for (final stat in stats) {
      currentRow++;
      sheet.setRowHeightInPixels(currentRow, 20);

      final labelCell = sheet.getRangeByIndex(currentRow, 1, currentRow, 3);
      labelCell.merge();
      labelCell.setText(stat[0]);
      labelCell.cellStyle.fontSize = 10;
      labelCell.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(labelCell);

      final valCell = sheet.getRangeByIndex(currentRow, 4);
      valCell.setText(stat[1]);
      valCell.cellStyle.bold = true;
      valCell.cellStyle.fontSize = 10;
      valCell.cellStyle.hAlign = xlsio.HAlignType.center;
      valCell.cellStyle.vAlign = xlsio.VAlignType.center;
      if (stat[0].contains('Pass Rate')) {
        valCell.cellStyle.backColor = passRate >= 90 ? '#DCFCE7' : '#FEE2E2';
        valCell.cellStyle.fontColor = passRate >= 90 ? '#15803D' : '#B91C1C';
      }
      _setBorders(valCell);
    }

    // 5. Gather All Measured Deviations for Histogram
    final List<double> allDeviations = [];
    for (final pom in specSheet.poms) {
      for (final size in sizes) {
        for (int sIdx = 1; sIdx <= specSheet.sampleCountPerSize; sIdx++) {
          final reading = specSheet.getReading(pom.pomCode, size, sIdx);
          if (reading != null) {
            allDeviations.add(reading.deviation);
          }
        }
      }
    }

    // 6. Generate High-Resolution Histogram Chart Graphic
    Uint8List? chartPngBytes;
    try {
      chartPngBytes = await HistogramImageRenderer.renderHistogramPng(
        deviations: allDeviations,
        tolerance: specSheet.tolerance,
        title: 'MEASURA - DEVIATION HISTOGRAM (${specSheet.style})',
        subtitle: 'Brand: ${specSheet.brand}  •  PO: ${specSheet.po}  •  Stage: ${specSheet.stage}  •  Tol: ±${specSheet.tolerance}" (${specSheet.toleranceCategory.label})',
        width: 820,
        height: 400,
      );
    } catch (_) {
      // Fallback gracefully if running in a headless test without graphic context
    }

    // 7. Embed Visual Chart Image into Inspection Sheet
    currentRow += 2;
    if (chartPngBytes != null && chartPngBytes.isNotEmpty) {
      final pic = sheet.pictures.addStream(currentRow, 1, chartPngBytes);
      pic.width = 680;
      pic.height = 320;
      currentRow += 17; // allocate row space for the visual image
    }

    // 8. Histogram Frequency Distribution Table on Inspection Sheet
    currentRow += 1;
    final distHeader = sheet.getRangeByIndex(currentRow, 1, currentRow, 5);
    distHeader.merge();
    distHeader.setText('MEASUREMENT DEVIATION DISTRIBUTION (HISTOGRAM)');
    distHeader.cellStyle.bold = true;
    distHeader.cellStyle.fontSize = 11;
    distHeader.cellStyle.backColor = '#0F172A';
    distHeader.cellStyle.fontColor = '#FFFFFF';
    distHeader.cellStyle.hAlign = xlsio.HAlignType.center;
    distHeader.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(currentRow, 26);

    currentRow++;
    sheet.setRowHeightInPixels(currentRow, 22);
    final dh1 = sheet.getRangeByIndex(currentRow, 1);
    dh1.setText('DEVIATION');
    _styleHeaderCell(dh1, isNavy: true);

    final dh2 = sheet.getRangeByIndex(currentRow, 2);
    dh2.setText('TOLERANCE STATUS');
    _styleHeaderCell(dh2);

    final dh3 = sheet.getRangeByIndex(currentRow, 3);
    dh3.setText('COUNT (PCS)');
    _styleHeaderCell(dh3);

    final dh4 = sheet.getRangeByIndex(currentRow, 4);
    dh4.setText('FREQUENCY');
    _styleHeaderCell(dh4);

    final dh5 = sheet.getRangeByIndex(currentRow, 5);
    dh5.setText('DISTRIBUTION BAR');
    _styleHeaderCell(dh5);

    for (final b in HistogramImageRenderer.buckets) {
      currentRow++;
      sheet.setRowHeightInPixels(currentRow, 20);

      final isZero = b == 0.0;
      final isWithin = b.abs() <= (specSheet.tolerance + 0.0001);
      final count = allDeviations.where((d) => (d - b).abs() < 0.0624).length;
      final double freq = total > 0 ? (count / total * 100) : 0.0;

      // Col 1: Bucket label
      final c1 = sheet.getRangeByIndex(currentRow, 1);
      c1.setText(_formatBucketLabel(b));
      c1.cellStyle.fontSize = 10;
      c1.cellStyle.bold = true;
      c1.cellStyle.hAlign = xlsio.HAlignType.center;
      c1.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c1);

      // Col 2: Status
      final c2 = sheet.getRangeByIndex(currentRow, 2);
      c2.setText(isZero ? 'Nominal (0)' : (isWithin ? 'Within Tolerance' : 'Out of Tolerance'));
      c2.cellStyle.fontSize = 9.5;
      c2.cellStyle.hAlign = xlsio.HAlignType.center;
      c2.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c2);

      // Col 3: Count
      final c3 = sheet.getRangeByIndex(currentRow, 3);
      c3.setNumber(count.toDouble());
      c3.cellStyle.fontSize = 10;
      c3.cellStyle.bold = count > 0;
      c3.cellStyle.hAlign = xlsio.HAlignType.center;
      c3.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c3);

      // Col 4: Frequency
      final c4 = sheet.getRangeByIndex(currentRow, 4);
      c4.setText('${freq.toStringAsFixed(1)}%');
      c4.cellStyle.fontSize = 10;
      c4.cellStyle.hAlign = xlsio.HAlignType.center;
      c4.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c4);

      // Col 5: Distribution Bar
      final c5 = sheet.getRangeByIndex(currentRow, 5);
      final barLength = (freq / 3).round().clamp(0, 30);
      c5.setText(count > 0 ? ('█' * (barLength == 0 ? 1 : barLength)) : '');
      c5.cellStyle.fontSize = 10;
      c5.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c5);

      if (isZero) {
        c1.cellStyle.backColor = '#EFF6FF';
        c1.cellStyle.fontColor = '#0284C7';
        c2.cellStyle.fontColor = '#0284C7';
        c5.cellStyle.fontColor = '#0284C7';
      } else if (isWithin) {
        c1.cellStyle.backColor = '#F0FDF4';
        c1.cellStyle.fontColor = '#166534';
        c2.cellStyle.fontColor = '#166534';
        c5.cellStyle.fontColor = '#10B981';
      } else {
        c1.cellStyle.backColor = '#FEF2F2';
        c1.cellStyle.fontColor = '#DC2626';
        c2.cellStyle.fontColor = '#DC2626';
        c5.cellStyle.fontColor = '#EF4444';
      }
    }

    // 9. Format Sheet 1: "Histogram & Analytics" (Executive Tab)
    _buildAnalyticsWorksheet(
      analyticsSheet,
      specSheet: specSheet,
      total: total,
      inTol: inTol,
      outOfTol: outOfTol,
      passRate: passRate,
      allDeviations: allDeviations,
      chartPngBytes: chartPngBytes,
    );

    // 10. Column Widths for Inspection Sheet
    sheet.setColumnWidthInPixels(1, 75);  // POM / Deviation
    sheet.setColumnWidthInPixels(2, 190); // Description / Status
    sheet.setColumnWidthInPixels(3, 85);  // Count
    sheet.setColumnWidthInPixels(4, 90);  // Frequency
    sheet.setColumnWidthInPixels(5, 180); // Distribution Bar
    for (int c = 6; c <= totalCols; c++) {
      sheet.setColumnWidthInPixels(c, 52); // Spec and Sample cells
    }

    // Save and dispose
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  static void _buildAnalyticsWorksheet(
    xlsio.Worksheet sheet, {
    required GarmentSpecSheet specSheet,
    required int total,
    required int inTol,
    required int outOfTol,
    required int passRate,
    required List<double> allDeviations,
    Uint8List? chartPngBytes,
  }) {
    // Title Banner
    final title = sheet.getRangeByName('A1:G1');
    title.merge();
    title.setText('MEASURA - INSPECTION HISTOGRAM & STATISTICAL QA REPORT');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 13;
    title.cellStyle.backColor = '#0F172A';
    title.cellStyle.fontColor = '#FFFFFF';
    title.cellStyle.hAlign = xlsio.HAlignType.center;
    title.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 36);

    // Metadata Rows
    sheet.getRangeByName('A2').setText('STYLE:');
    sheet.getRangeByName('A2').cellStyle.bold = true;
    sheet.getRangeByName('B2').setText(specSheet.style);

    sheet.getRangeByName('C2').setText('BRAND:');
    sheet.getRangeByName('C2').cellStyle.bold = true;
    sheet.getRangeByName('D2').setText(specSheet.brand);

    sheet.getRangeByName('E2').setText('PO:');
    sheet.getRangeByName('E2').cellStyle.bold = true;
    sheet.getRangeByName('F2').setText(specSheet.po.isNotEmpty ? specSheet.po : 'N/A');

    sheet.getRangeByName('A3').setText('STAGE:');
    sheet.getRangeByName('A3').cellStyle.bold = true;
    sheet.getRangeByName('B3').setText(specSheet.stage);

    sheet.getRangeByName('C3').setText('TOLERANCE:');
    sheet.getRangeByName('C3').cellStyle.bold = true;
    sheet.getRangeByName('D3').setText('±${specSheet.tolerance}" (${specSheet.toleranceCategory.label})');

    final now = DateTime.now();
    sheet.getRangeByName('E3').setText('DATE:');
    sheet.getRangeByName('E3').cellStyle.bold = true;
    sheet.getRangeByName('F3').setText('${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

    for (int r = 2; r <= 3; r++) {
      sheet.setRowHeightInPixels(r, 22);
      for (int c = 1; c <= 6; c++) {
        sheet.getRangeByIndex(r, c).cellStyle.backColor = '#F8FAFC';
        sheet.getRangeByIndex(r, c).cellStyle.vAlign = xlsio.VAlignType.center;
      }
    }

    // KPI Badges (Row 5)
    sheet.setRowHeightInPixels(5, 30);
    final kpis = [
      ['Total Samples', '$total pcs', '#0284C7', '#EFF6FF'],
      ['In Tolerance', '$inTol pcs', '#166534', '#F0FDF4'],
      ['Out of Tol (Defects)', '$outOfTol pcs', outOfTol > 0 ? '#DC2626' : '#166534', outOfTol > 0 ? '#FEF2F2' : '#F0FDF4'],
      ['Pass Rate', '$passRate%', passRate >= 90 ? '#166534' : '#DC2626', passRate >= 90 ? '#F0FDF4' : '#FEF2F2'],
    ];

    for (int i = 0; i < kpis.length; i++) {
      final col = (i * 2) + 1;
      final kpiRange = sheet.getRangeByIndex(5, col, 5, col + 1);
      kpiRange.merge();
      kpiRange.setText('${kpis[i][0]}: ${kpis[i][1]}');
      kpiRange.cellStyle.bold = true;
      kpiRange.cellStyle.fontSize = 11;
      kpiRange.cellStyle.hAlign = xlsio.HAlignType.center;
      kpiRange.cellStyle.vAlign = xlsio.VAlignType.center;
      kpiRange.cellStyle.fontColor = kpis[i][2];
      kpiRange.cellStyle.backColor = kpis[i][3];
      _setBorders(kpiRange);
    }

    int curRow = 7;
    // Embed Visual Chart Graphic
    if (chartPngBytes != null && chartPngBytes.isNotEmpty) {
      final pic = sheet.pictures.addStream(curRow, 1, chartPngBytes);
      pic.width = 760;
      pic.height = 360;
      curRow += 19;
    }

    // Distribution Table
    final distTitle = sheet.getRangeByIndex(curRow, 1, curRow, 5);
    distTitle.merge();
    distTitle.setText('DETAILED DEVIATION FREQUENCY BREAKDOWN');
    distTitle.cellStyle.bold = true;
    distTitle.cellStyle.fontSize = 11;
    distTitle.cellStyle.backColor = '#0F172A';
    distTitle.cellStyle.fontColor = '#FFFFFF';
    distTitle.cellStyle.hAlign = xlsio.HAlignType.center;
    distTitle.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(curRow, 26);

    curRow++;
    sheet.setRowHeightInPixels(curRow, 22);
    final ah1 = sheet.getRangeByIndex(curRow, 1);
    ah1.setText('DEVIATION BUCKET');
    _styleHeaderCell(ah1, isNavy: true);

    final ah2 = sheet.getRangeByIndex(curRow, 2);
    ah2.setText('TOLERANCE STATUS');
    _styleHeaderCell(ah2);

    final ah3 = sheet.getRangeByIndex(curRow, 3);
    ah3.setText('COUNT (PCS)');
    _styleHeaderCell(ah3);

    final ah4 = sheet.getRangeByIndex(curRow, 4);
    ah4.setText('FREQUENCY %');
    _styleHeaderCell(ah4);

    final ah5 = sheet.getRangeByIndex(curRow, 5);
    ah5.setText('DISTRIBUTION BAR');
    _styleHeaderCell(ah5);

    for (final b in HistogramImageRenderer.buckets) {
      curRow++;
      sheet.setRowHeightInPixels(curRow, 20);

      final isZero = b == 0.0;
      final isWithin = b.abs() <= (specSheet.tolerance + 0.0001);
      final count = allDeviations.where((d) => (d - b).abs() < 0.0624).length;
      final double freq = total > 0 ? (count / total * 100) : 0.0;

      final c1 = sheet.getRangeByIndex(curRow, 1);
      c1.setText(_formatBucketLabel(b));
      c1.cellStyle.fontSize = 10;
      c1.cellStyle.bold = true;
      c1.cellStyle.hAlign = xlsio.HAlignType.center;
      c1.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c1);

      final c2 = sheet.getRangeByIndex(curRow, 2);
      c2.setText(isZero ? 'Nominal (0)' : (isWithin ? 'Within Tolerance' : 'Out of Tolerance'));
      c2.cellStyle.fontSize = 9.5;
      c2.cellStyle.hAlign = xlsio.HAlignType.center;
      c2.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c2);

      final c3 = sheet.getRangeByIndex(curRow, 3);
      c3.setNumber(count.toDouble());
      c3.cellStyle.fontSize = 10;
      c3.cellStyle.bold = count > 0;
      c3.cellStyle.hAlign = xlsio.HAlignType.center;
      c3.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c3);

      final c4 = sheet.getRangeByIndex(curRow, 4);
      c4.setText('${freq.toStringAsFixed(1)}%');
      c4.cellStyle.fontSize = 10;
      c4.cellStyle.hAlign = xlsio.HAlignType.center;
      c4.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c4);

      final c5 = sheet.getRangeByIndex(curRow, 5);
      final barLength = (freq / 3).round().clamp(0, 30);
      c5.setText(count > 0 ? ('█' * (barLength == 0 ? 1 : barLength)) : '');
      c5.cellStyle.fontSize = 10;
      c5.cellStyle.vAlign = xlsio.VAlignType.center;
      _setBorders(c5);

      if (isZero) {
        c1.cellStyle.backColor = '#EFF6FF';
        c1.cellStyle.fontColor = '#0284C7';
        c2.cellStyle.fontColor = '#0284C7';
        c5.cellStyle.fontColor = '#0284C7';
      } else if (isWithin) {
        c1.cellStyle.backColor = '#F0FDF4';
        c1.cellStyle.fontColor = '#166534';
        c2.cellStyle.fontColor = '#166534';
        c5.cellStyle.fontColor = '#10B981';
      } else {
        c1.cellStyle.backColor = '#FEF2F2';
        c1.cellStyle.fontColor = '#DC2626';
        c2.cellStyle.fontColor = '#DC2626';
        c5.cellStyle.fontColor = '#EF4444';
      }
    }

    // Set Column Widths for Analytics Sheet
    sheet.setColumnWidthInPixels(1, 110);
    sheet.setColumnWidthInPixels(2, 170);
    sheet.setColumnWidthInPixels(3, 100);
    sheet.setColumnWidthInPixels(4, 110);
    sheet.setColumnWidthInPixels(5, 260);
    sheet.setColumnWidthInPixels(6, 90);
    sheet.setColumnWidthInPixels(7, 90);
    sheet.setColumnWidthInPixels(8, 90);
  }

  static String _formatBucketLabel(double val) {
    if (val == 0.0) return '0 (Spec)';
    final s = formatDeviation(val);
    return val > 0 ? '+$s"' : '$s"';
  }

  /// Exports the spec sheet to an Excel file and presents the native share/save dialog
  static Future<void> exportAndShare(
    BuildContext context,
    GarmentSpecSheet specSheet, {
    List<String>? selectedSizes,
  }) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generating Excel spreadsheet...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final bytes = await generateExcelBytes(specSheet, selectedSizes: selectedSizes);
      final tempDir = await getTemporaryDirectory();

      final cleanStyle = specSheet.style.replaceAll(RegExp(r'[^\w\-]'), '_');
      final cleanPo = specSheet.po.replaceAll(RegExp(r'[^\w\-]'), '_');
      final fileName = cleanPo.isNotEmpty
          ? 'MEASURA_${cleanStyle}_PO_$cleanPo.xlsx'
          : 'MEASURA_${cleanStyle}_Inspection.xlsx';

      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;

      // Share file natively
      final xFile = XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await Share.shareXFiles(
        [xFile],
        text: 'MEASURA Garment Measurement Sheet - Style: ${specSheet.style}',
        subject: 'Garment Inspection Report - ${specSheet.style}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Failed to export Excel: $e'),
        ),
      );
    }
  }

  static void _styleHeaderCell(xlsio.Range range, {bool isNavy = false}) {
    range.cellStyle.bold = true;
    range.cellStyle.fontSize = 11;
    range.cellStyle.backColor = isNavy ? '#0F172A' : '#F1F5F9';
    range.cellStyle.fontColor = isNavy ? '#FFFFFF' : '#0F172A';
    range.cellStyle.hAlign = xlsio.HAlignType.center;
    range.cellStyle.vAlign = xlsio.VAlignType.center;
    _setBorders(range);
  }

  static void _setBorders(xlsio.Range range) {
    range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    range.cellStyle.borders.all.color = '#CBD5E1';
  }
}
