class StatementModel {
  final String id;
  final String userId;
  final String fileName;
  final String bankName;
  final String? accountNumber;
  final String? statementStart;
  final String? statementEnd;
  final String processingStatus;
  final String processingStep;
  final double processingProgress;
  final int totalTransactions;
  final DateTime createdAt;

  StatementModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.bankName,
    this.accountNumber,
    this.statementStart,
    this.statementEnd,
    required this.processingStatus,
    required this.processingStep,
    required this.processingProgress,
    required this.totalTransactions,
    required this.createdAt,
  });

  bool get isCompleted => processingStatus == 'completed';
  bool get isProcessing => processingStatus == 'processing' || processingStatus == 'uploaded';
  bool get isFailed => processingStatus == 'failed';

  factory StatementModel.fromJson(Map<String, dynamic> json) {
    return StatementModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      fileName: json['file_name'] ?? '',
      bankName: json['bank_name'] ?? 'Bank Statement',
      accountNumber: json['account_number'],
      statementStart: json['statement_start'],
      statementEnd: json['statement_end'],
      processingStatus: json['processing_status'] ?? 'uploaded',
      processingStep: json['processing_step'] ?? 'Uploaded',
      processingProgress: (json['processing_progress'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['total_transactions'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
