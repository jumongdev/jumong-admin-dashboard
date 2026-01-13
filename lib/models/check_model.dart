// lib/check_model.dart

class BusinessCheck {
  final int id;
  final String payeeName;
  final double amount;
  final DateTime dueDate;
  final String status;
  final DateTime? issueDate;
  final int? checkNumber;
  final String? memo;

  BusinessCheck({
    required this.id,
    required this.payeeName,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.issueDate,
    this.checkNumber,
    this.memo,
  });

  // A factory constructor to create a BusinessCheck from a map (the data from Supabase)
  factory BusinessCheck.fromMap(Map<String, dynamic> map) {
    return BusinessCheck(
      id: map['id'],
      payeeName: map['payee_name'],
      // Supabase might return amount as int or double, so we handle both.
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date']),
      status: map['status'],
      issueDate: map['issue_date'] != null ? DateTime.parse(map['issue_date']) : null,
      checkNumber: map['check_number'],
      memo: map['memo'],
    );
  }
}
