class TransactionModel {
  final String id;
  final String type; // 'topup' or 'purchase'
  final double amount;
  final String description;
  final DateTime timestamp;
  final String? status;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      type: map['type'],
      amount: map['amount'].toDouble(),
      description: map['description'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
    );
  }
}
