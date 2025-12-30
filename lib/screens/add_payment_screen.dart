import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/widgets/custom_text_field.dart';
import 'package:duitkita/utils/utils.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  final String groupId;
  final double monthlyAmount;
  final int selectedMonth;
  final int selectedYear;

  const AddPaymentScreen({
    Key? key,
    required this.groupId,
    required this.monthlyAmount,
    required this.selectedMonth,
    required this.selectedYear,
  }) : super(key: key);

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();
  late DateTime _selectedDate;

  String? _amountError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.monthlyAmount.toStringAsFixed(2),
    );
    _selectedDate = DateTime(
      widget.selectedYear,
      widget.selectedMonth,
      DateTime.now().day,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid amount';
      });
      return false;
    } else {
      setState(() {
        _amountError = null;
      });
      return true;
    }
  }

  Future<void> _addPayment() async {
    if (!_validateInputs()) {
      return;
    }

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        showSnackBar(context, 'User not logged in', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user profile for name
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      // Add payment
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.addPayment(
        groupId: widget.groupId,
        userId: userId,
        userName: profile?.name ?? 'Unknown',
        amount: double.parse(_amountController.text.trim()),
        paymentDate: _selectedDate,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );

      // Update member stats
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateMemberStats(
        groupId: widget.groupId,
        userId: userId,
        amount: double.parse(_amountController.text.trim()),
      );

      if (mounted) {
        showSnackBar(context, 'Payment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to add payment: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Record a payment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your monthly contribution',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Amount field
              CustomTextField(
                controller: _amountController,
                labelText: 'Amount (RM)',
                errorText: _amountError,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() {
                      _amountError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes field
              CustomTextField(
                controller: _notesController,
                labelText: 'Notes (optional)',
              ),
              const SizedBox(height: 8),
              Text(
                'Add any additional notes about this payment',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _addPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Add Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
