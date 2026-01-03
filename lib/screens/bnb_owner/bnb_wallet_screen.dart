import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/wallet_service.dart';
import 'package:hook_app/models/wallet_transaction.dart';
import 'package:hook_app/services/booking_service.dart';

class BnBWalletScreen extends StatefulWidget {
  const BnBWalletScreen({super.key});

  @override
  State<BnBWalletScreen> createState() => _BnBWalletScreenState();
}

class _BnBWalletScreenState extends State<BnBWalletScreen> {
  bool _isLoading = true;
  double _totalEarnings = 0.0;
  double _totalWithdrawals = 0.0;
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  String _selectedFilter = 'all'; // 'all', 'earnings', 'withdrawals'

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);

    try {
      // Load balance
      final balanceData = await WalletService.getWalletBalance();
      
      // Load transactions
      List<WalletTransaction> transactions = await WalletService.getTransactions();
      
      // If no transactions from API, try to get from bookings
      if (transactions.isEmpty) {
        try {
          final bookings = await BookingService.getBookingsByBnbOwner();
          final earnings = await WalletService.getEarningsFromBookings(
            bookings.map((b) => b.toJson()).toList(),
          );
          transactions = earnings;
        } catch (e) {
          print('Error loading bookings for earnings: $e');
        }
      }

      if (mounted) {
        setState(() {
          _totalEarnings = balanceData['total_earnings']?.toDouble() ?? 0.0;
          _totalWithdrawals = balanceData['total_withdrawals']?.toDouble() ?? 0.0;
          _balance = balanceData['balance']?.toDouble() ?? 0.0;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load wallet data: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _requestWithdrawal() async {
    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final accountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.deepPurple,
        title: const Text(
          'Request Withdrawal',
          style: TextStyle(color: AppConstants.softWhite),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                style: const TextStyle(color: AppConstants.softWhite),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  labelStyle: const TextStyle(color: AppConstants.softWhite),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: methodController,
                style: const TextStyle(color: AppConstants.softWhite),
                decoration: InputDecoration(
                  labelText: 'Method (e.g., M-Pesa, Bank Transfer)',
                  labelStyle: const TextStyle(color: AppConstants.softWhite),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accountController,
                style: const TextStyle(color: AppConstants.softWhite),
                decoration: InputDecoration(
                  labelText: 'Account Details',
                  labelStyle: const TextStyle(color: AppConstants.softWhite),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppConstants.primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppConstants.mutedGray)),
          ),
          TextButton(
            onPressed: () {
              if (amountController.text.isNotEmpty && methodController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Request', style: TextStyle(color: AppConstants.primaryColor)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final amount = double.tryParse(amountController.text) ?? 0.0;
        if (amount <= 0) {
          throw Exception('Invalid amount');
        }
        if (amount > _balance) {
          throw Exception('Insufficient balance');
        }

        // Use phone number from account details field for M-Pesa withdrawal
        await WalletService.requestWithdrawal(
          amount: amount,
          phoneNumber: accountController.text.isNotEmpty ? accountController.text : methodController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
          _loadWalletData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error requesting withdrawal: $e'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      }
    }
  }

  List<WalletTransaction> get _filteredTransactions {
    if (_selectedFilter == 'all') return _transactions;
    if (_selectedFilter == 'earnings') {
      return _transactions.where((t) => t.type == TransactionType.earning).toList();
    }
    return _transactions.where((t) => t.type == TransactionType.withdrawal).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBalanceCard(),
                            const SizedBox(height: 24),
                            _buildFilterTabs(),
                            const SizedBox(height: 16),
                            _buildTransactionList(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppConstants.softWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'My Wallet',
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadWalletData,
            icon: const Icon(
              Icons.refresh,
              color: AppConstants.softWhite,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 16,
                ),
              ),
              const Icon(
                Icons.account_balance_wallet,
                color: AppConstants.softWhite,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KES ${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppConstants.softWhite,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Earnings', _totalEarnings, Icons.trending_up),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Withdrawals', _totalWithdrawals, Icons.trending_down),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _balance > 0 ? _requestWithdrawal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.softWhite,
                foregroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Request Withdrawal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.softWhite.withOpacity(0.8), size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppConstants.softWhite.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'KES ${value.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppConstants.softWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _buildFilterTab('all', 'All'),
        const SizedBox(width: 8),
        _buildFilterTab('earnings', 'Earnings'),
        const SizedBox(width: 8),
        _buildFilterTab('withdrawals', 'Withdrawals'),
      ],
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primaryColor.withOpacity(0.3)
                : AppConstants.surfaceColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppConstants.primaryColor
                  : AppConstants.mutedGray.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppConstants.primaryColor : AppConstants.mutedGray,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    final filtered = _filteredTransactions;
    
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 64,
                color: AppConstants.mutedGray.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  color: AppConstants.mutedGray,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by timestamp (newest first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final txn = filtered[index];
        return _buildTransactionItem(txn);
      },
    );
  }

  Widget _buildTransactionItem(WalletTransaction txn) {
    final isEarning = txn.type == TransactionType.earning;
    final isCompleted = txn.status == TransactionStatus.completed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEarning
                  ? AppConstants.successColor.withOpacity(0.2)
                  : AppConstants.accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEarning ? Icons.arrow_downward : Icons.arrow_upward,
              color: isEarning ? AppConstants.successColor : AppConstants.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.displayDescription,
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppConstants.mutedGray.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      txn.formattedDate,
                      style: TextStyle(
                        color: AppConstants.mutedGray.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    if (txn.reference != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${txn.reference}',
                        style: TextStyle(
                          color: AppConstants.mutedGray.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                txn.formattedAmount,
                style: TextStyle(
                  color: isEarning ? AppConstants.successColor : AppConstants.accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppConstants.successColor.withOpacity(0.2)
                      : AppConstants.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  txn.status == TransactionStatus.completed
                      ? 'Completed'
                      : txn.status == TransactionStatus.pending
                          ? 'Pending'
                          : 'Failed',
                  style: TextStyle(
                    color: isCompleted
                        ? AppConstants.successColor
                        : AppConstants.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
