import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/statement_provider.dart';
import '../providers/transaction_provider.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  Future<void> _pickAndUploadPDF(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final stmtProv = Provider.of<StatementProvider>(context, listen: false);
    final txnProv = Provider.of<TransactionProvider>(context, listen: false);
    final analyticsProv = Provider.of<AnalyticsProvider>(context, listen: false);
    final forecastProv = Provider.of<ForecastProvider>(context, listen: false);

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result.isNotEmpty) {
      final file = result.first;
      final success = await stmtProv.uploadStatementFile(file);

      if (success) {
        await txnProv.fetchTransactions();
        await analyticsProv.fetchAnalytics();
        await forecastProv.fetchForecast();

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Statement processed successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _seedSample(BuildContext context, String bank) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final stmtProv = Provider.of<StatementProvider>(context, listen: false);
    final txnProv = Provider.of<TransactionProvider>(context, listen: false);
    final analyticsProv = Provider.of<AnalyticsProvider>(context, listen: false);
    final forecastProv = Provider.of<ForecastProvider>(context, listen: false);

    final success = await stmtProv.seedSampleStatement(bank: bank);

    if (success) {
      await txnProv.fetchTransactions();
      await analyticsProv.fetchAnalytics();
      await forecastProv.fetchForecast();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$bank 6-Month Statement ingested successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<StatementProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Statement Ingestion'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFC8E6C9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF10B981), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Bank Statement',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supports text-based or scanned 6-month PDF bank statements (HDFC, SBI, ICICI, etc.)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Upload Button Box
                InkWell(
                  onTap: provider.isUploading ? null : () => _pickAndUploadPDF(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.6),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Color(0xFF10B981)),
                        const SizedBox(height: 12),
                        Text(
                          'Choose PDF File to Upload',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click to browse statement from device',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Live 7-Stage Pipeline Progress Stepper (PRD Section 34)
                if (provider.isUploading) ...[
                  Text(
                    'Processing Statement Pipeline',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              provider.currentStep,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              '${(provider.uploadProgress * 100).toInt()}%',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: provider.uploadProgress,
                            minHeight: 8,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _stepperItem('Reading PDF document', provider.uploadProgress >= 0.15, isDark),
                        _stepperItem('Extracting transactions', provider.uploadProgress >= 0.35, isDark),
                        _stepperItem('Cleaning descriptions & removing noise', provider.uploadProgress >= 0.50, isDark),
                        _stepperItem('Normalizing merchants', provider.uploadProgress >= 0.65, isDark),
                        _stepperItem('AI Categorization & confidence scoring', provider.uploadProgress >= 0.80, isDark),
                        _stepperItem('Building spending analytics', provider.uploadProgress >= 0.90, isDark),
                        _stepperItem('Generating expense forecast', provider.uploadProgress >= 1.0, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 1-Click Sample Ingestion Section
                Text(
                  '1-Click Sample Bank Statements',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pre-generated authentic 6-month bank statements for instant evaluation',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),

                _sampleBankCard(
                  context: context,
                  bank: 'HDFC Bank',
                  period: 'Jan 2026 – Jun 2026 (128 txns)',
                  color: const Color(0xFF004C8F),
                  isDark: isDark,
                  disabled: provider.isUploading,
                ),
                const SizedBox(height: 10),
                _sampleBankCard(
                  context: context,
                  bank: 'State Bank of India',
                  period: 'Jan 2026 – Jun 2026 (119 txns)',
                  color: const Color(0xFF280071),
                  isDark: isDark,
                  disabled: provider.isUploading,
                ),
                const SizedBox(height: 10),
                _sampleBankCard(
                  context: context,
                  bank: 'ICICI Bank',
                  period: 'Jan 2026 – Jun 2026 (124 txns)',
                  color: const Color(0xFF8A1E0B),
                  isDark: isDark,
                  disabled: provider.isUploading,
                ),
                const SizedBox(height: 24),

                // Uploaded History
                if (provider.statements.isNotEmpty) ...[
                  Text(
                    'Ingested Statements',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...provider.statements.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.bankName,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${s.fileName} • ${s.totalTransactions} transactions',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Analyzed',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stepperItem(String label, bool isDone, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? const Color(0xFF10B981) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
              color: isDone
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sampleBankCard({
    required BuildContext context,
    required String bank,
    required String period,
    required Color color,
    required bool isDark,
    required bool disabled,
  }) {
    return InkWell(
      onTap: disabled ? null : () => _seedSample(context, bank),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.account_balance_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    period,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: disabled ? null : () => _seedSample(context, bank),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Load', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
