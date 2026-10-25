import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';

class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key});

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getAdminStatistics();
    if (!mounted) return;
    setState(() {
      _stats = result.data;
      _isLoading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_stats == null) return;
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DevLink Statistics', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateTime.now().toString().split(' ')[0]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                'CONFIDENTIAL: This data is private and only for the admin. Do not share with anyone.',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.red, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('Overview', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Users', '${_stats!['totalUsers'] ?? 0}'],
                ['Customers', '${_stats!['customers'] ?? 0}'],
                ['Programmers', '${_stats!['programmers'] ?? 0}'],
                ['Total Posts', '${_stats!['posts'] ?? 0}'],
                ['Pending Posts', '${_stats!['pendingPosts'] ?? 0}'],
                ['Verified Programmers', '${_stats!['verifiedProgrammers'] ?? 0}'],
                ['Support Messages', '${_stats!['supportMessages'] ?? 0}'],
                ['Unread Messages', '${_stats!['unreadSupportMessages'] ?? 0}'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();

      // ✅ نستخدم Printing.sharePdf اللي شغالة على الويب والموبايل
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'DevLink_Statistics_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF Ready'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insights_rounded, color: Color(0xFFEC4899), size: 18),
            ),
            const SizedBox(width: 10),
            Text('Statistics', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isExporting
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : TextButton.icon(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 20),
                    label: const Text('Export PDF', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900)),
                  ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _stats == null
                  ? Center(child: Text('Failed to load statistics', style: TextStyle(color: textSecondary)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ تنبيه الخصوصية
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(isDark ? 0.10 : 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Confidential: This data is private for the admin only. Please do not share it with anyone.',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ✅ إحصائيات سريعة
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 800;
                              
                              final cardWidth = isWide 
                                  ? (constraints.maxWidth - 36) / 4 
                                  : (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(width: cardWidth, child: _statCard('Total Users', '${_stats!['totalUsers'] ?? 0}', Icons.people_alt_rounded, const Color(0xFF3B82F6), cardColor, textPrimary, textSecondary, borderColor)),
                                  SizedBox(width: cardWidth, child: _statCard('Customers', '${_stats!['customers'] ?? 0}', Icons.person_rounded, const Color(0xFF10B981), cardColor, textPrimary, textSecondary, borderColor)),
                                  SizedBox(width: cardWidth, child: _statCard('Programmers', '${_stats!['programmers'] ?? 0}', Icons.code_rounded, const Color(0xFF8B5CF6), cardColor, textPrimary, textSecondary, borderColor)),
                                  SizedBox(width: cardWidth, child: _statCard('Posts', '${_stats!['posts'] ?? 0}', Icons.article_rounded, const Color(0xFFF59E0B), cardColor, textPrimary, textSecondary, borderColor)),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // ✅ الرسوم البيانية
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 800;

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildLineChartCard(cardColor, textPrimary, textSecondary, borderColor)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildPieChartCard(cardColor, textPrimary, textSecondary, borderColor)),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _buildLineChartCard(cardColor, textPrimary, textSecondary, borderColor),
                                  const SizedBox(height: 16),
                                  _buildPieChartCard(cardColor, textPrimary, textSecondary, borderColor),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title, 
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary), 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final totalUsers = (_stats!['totalUsers'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Users Growth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary)),
          Text('Current: ${totalUsers.toInt()} users', style: TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.8,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: borderColor, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: textSecondary, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (value.toInt() < days.length) {
                          return Text(days[value.toInt()], style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w700));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, totalUsers * 0.2),
                      FlSpot(1, totalUsers * 0.35),
                      FlSpot(2, totalUsers * 0.5),
                      FlSpot(3, totalUsers * 0.7),
                      FlSpot(4, totalUsers * 0.85),
                      FlSpot(5, totalUsers),
                    ],
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.2)),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final customers = (_stats!['customers'] ?? 0).toDouble();
    final programmers = (_stats!['programmers'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary)),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.5,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: customers,
                    title: 'Customers',
                    color: const Color(0xFF10B981),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  PieChartSectionData(
                    value: programmers,
                    title: 'Programmers',
                    color: const Color(0xFF8B5CF6),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('Customers', const Color(0xFF10B981), textSecondary),
              const SizedBox(width: 16),
              _legendItem('Programmers', const Color(0xFF8B5CF6), textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }
}