import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/wallet_service.dart';
import 'package:hook_app/models/wallet_transaction.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _balance = 0.0;
  List<WalletTransaction> _allTransactions = [];
  List<WalletTransaction> _earnings = [];
  List<WalletTransaction> _withdrawals = [];
  List<WalletTransaction> _pending = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadWalletData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load balance and transactions
      final balanceData = await WalletService.getWalletBalance();
      final transactions = await WalletService.getTransactions();

      setState(() {
        _balance = (balanceData['balance'] as num?)?.toDouble() ?? 0.0;
        _allTransactions = transactions;
        
        // Filter transactions
        _earnings = transactions.where((t) => 
          t.type == TransactionType.earning && t.status == TransactionStatus.completed
        ).toList();
        
        _withdrawals = transactions.where((t) => 
          t.type == TransactionType.withdrawal
        ).toList();
        
        _pending = transactions.where((t) => 
          t.status == TransactionStatus.pending
        ).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showWithdrawalDialog() async {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Request Withdrawal',
          style: TextStyle(color: AppConstants.softWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppConstants.softWhite),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                labelStyle: TextStyle(color: AppConstants.mutedGray),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppConstants.primaryColor),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppConstants.softWhite),
              decoration: InputDecoration(
                labelText: 'M-Pesa Phone Number',
                labelStyle: TextStyle(color: AppConstants.mutedGray),
                hintText: '0712345678',
                hintStyle: TextStyle(color: AppConstants.mutedGray.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppConstants.primaryColor),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppConstants.mutedGray),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              
              if (phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter phone number')),
                );
                return;
              }

              try {
                await WalletService.requestWithdrawal(
                  amount: amount,
                  phoneNumber: phoneController.text,
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal request submitted'),
                      backgroundColor: AppConstants.successColor,
                    ),
                  );
                  _loadWalletData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
            ),
            child: const Text(
              'Submit',
              style: TextStyle(color: AppConstants.softWhite),
            ),
          ),
        ],
      ),
    );
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
              // Header with balance
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Wallet',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.softWhite,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: AppConstants.primaryColor.withOpacity(0.5),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppConstants.softWhite),
                          onPressed: _loadWalletData,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Balance card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            AppConstants.primaryColor,
                            AppConstants.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Available Balance',
                            style: TextStyle(
                              color: AppConstants.softWhite.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'KES ${_balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppConstants.softWhite,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _balance > 0 ? _showWithdrawalDialog : null,
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('Withdraw'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.softWhite,
                              foregroundColor: AppConstants.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppConstants.primaryColor,
                  indicatorWeight: 3,
                  labelColor: AppConstants.primaryColor,
                  unselectedLabelColor: AppConstants.mutedGray,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Earnings'),
                    Tab(text: 'Withdrawals'),
                    Tab(text: 'Pending'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      )
                    : _error != null
                        ? _buildErrorWidget()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTransactionList(_allTransactions),
                              _buildTransactionList(_earnings),
                              _buildTransactionList(_withdrawals),
                              _buildTransactionList(_pending),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<WalletTransaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: AppConstants.mutedGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppConstants.softWhite.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWalletData,
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransaction transaction) {
    final isEarning = transaction.type == TransactionType.earning;
    final color = isEarning ? AppConstants.successColor : AppConstants.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.7),
            AppConstants.surfaceColor.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEarning ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.displayDescription,
                    style: const TextStyle(
                      color: AppConstants.softWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        transaction.formattedDate,
                        style: TextStyle(
                          color: AppConstants.mutedGray,
                          fontSize: 12,
                        ),
                      ),
                      if (transaction.bookingId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home,
                                size: 10,
                                color: AppConstants.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'BnB',
                                style: TextStyle(
                                  color: AppConstants.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transaction.clientName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Paid by: ${transaction.clientName}',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction.formattedAmount,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(transaction.status),
                    style: TextStyle(
                      color: _getStatusColor(transaction.status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return AppConstants.successColor;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return AppConstants.errorColor;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: AppConstants.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading wallet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.softWhite.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadWalletData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: AppConstants.softWhite),
            ),
          ),
        ],
      ),
    );
  }
}
