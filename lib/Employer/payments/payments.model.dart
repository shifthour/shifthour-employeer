import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class Payment {
  final String id;
  final String workerName;
  final String workerId;
  final double amount;
  final DateTime dueDate;
  final PaymentStatus status;
  final String? jobReference;
  final double? hoursWorked;
  final String? paymentMethod;
  final String? transactionId;

  Payment({
    required this.id,
    required this.workerName,
    required this.workerId,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.jobReference,
    this.hoursWorked,
    this.paymentMethod,
    this.transactionId,
  });
}

enum PaymentStatus { pending, processing, completed, failed }

extension PaymentStatusExtension on PaymentStatus {
  String get name {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return Colors.amber.shade700;
      case PaymentStatus.processing:
        return Colors.blue.shade700;
      case PaymentStatus.completed:
        return Colors.green.shade600;
      case PaymentStatus.failed:
        return Colors.red.shade600;
    }
  }
}

class PaymentsRepository {
  // Mock data for the payments
  List<Payment> getPayments() {
    return [
      Payment(
        id: 'PAY-001',
        workerName: 'Sarah Johnson',
        workerId: 'W-12345',
        amount: 450.00,
        dueDate: DateTime(2023, 5, 15),
        status: PaymentStatus.pending,
        jobReference: 'JOB-123',
        hoursWorked: 30.0,
        paymentMethod: 'Bank Transfer',
      ),
      Payment(
        id: 'PAY-002',
        workerName: 'Michael Chen',
        workerId: 'W-67890',
        amount: 720.00,
        dueDate: DateTime(2023, 5, 17),
        status: PaymentStatus.pending,
        jobReference: 'JOB-124',
        hoursWorked: 48.0,
        paymentMethod: 'Bank Transfer',
      ),
      Payment(
        id: 'PAY-003',
        workerName: 'Emily Rodriguez',
        workerId: 'W-54321',
        amount: 325.50,
        dueDate: DateTime(2023, 5, 20),
        status: PaymentStatus.pending,
        jobReference: 'JOB-125',
        hoursWorked: 21.7,
        paymentMethod: 'PayPal',
      ),
      Payment(
        id: 'PAY-004',
        workerName: 'David Wilson',
        workerId: 'W-11223',
        amount: 510.75,
        dueDate: DateTime(2023, 5, 10),
        status: PaymentStatus.processing,
        jobReference: 'JOB-120',
        hoursWorked: 34.05,
        paymentMethod: 'Bank Transfer',
        transactionId: 'TRX-567890',
      ),
      Payment(
        id: 'PAY-005',
        workerName: 'Jessica Brown',
        workerId: 'W-33445',
        amount: 825.25,
        dueDate: DateTime(2023, 5, 5),
        status: PaymentStatus.completed,
        jobReference: 'JOB-118',
        hoursWorked: 55.0,
        paymentMethod: 'Bank Transfer',
        transactionId: 'TRX-123456',
      ),
      Payment(
        id: 'PAY-006',
        workerName: 'Robert Taylor',
        workerId: 'W-99887',
        amount: 675.00,
        dueDate: DateTime(2023, 5, 12),
        status: PaymentStatus.failed,
        jobReference: 'JOB-121',
        hoursWorked: 45.0,
        paymentMethod: 'PayPal',
        transactionId: 'TRX-ERROR',
      ),
    ];
  }

  // Get payments by status
  List<Payment> getPaymentsByStatus(PaymentStatus status) {
    return getPayments().where((payment) => payment.status == status).toList();
  }

  // Get total amount of payments
  double getTotalPaymentsAmount() {
    return getPayments().fold(0, (sum, payment) => sum + payment.amount);
  }

  // Get pending payments amount
  double getPendingPaymentsAmount() {
    return getPaymentsByStatus(
      PaymentStatus.pending,
    ).fold(0, (sum, payment) => sum + payment.amount);
  }

  // Get monthly payments amount
  double getMonthlyPaymentsAmount() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return getPayments()
        .where(
          (payment) =>
              payment.dueDate.isAfter(startOfMonth) &&
              payment.dueDate.isBefore(endOfMonth),
        )
        .fold(0, (sum, payment) => sum + payment.amount);
  }
}

class PaymentsController {
  final PaymentsRepository _repository = PaymentsRepository();

  // Selected payment status tab
  final Rx<PaymentStatus> selectedStatus = PaymentStatus.pending.obs;

  // Get payments based on selected status
  List<Payment> getPayments() {
    return _repository.getPaymentsByStatus(selectedStatus.value);
  }

  // Change selected status
  void changeStatus(PaymentStatus status) {
    selectedStatus.value = status;
  }

  // Format currency
  String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  // Format date
  String formatDate(DateTime date) {
    return 'Due: ${date.month}/${date.day}/${date.year}';
  }

  // Get payment stats
  Map<String, double> getPaymentStats() {
    return {
      'total': _repository.getTotalPaymentsAmount(),
      'pending': _repository.getPendingPaymentsAmount(),
      'monthly': _repository.getMonthlyPaymentsAmount(),
    };
  }
}
