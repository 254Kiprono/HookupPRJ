import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/wallet_service.dart';
import 'package:hook_app/models/wallet_transaction.dart';
import 'package:intl/intl.dart';
import 'package:hook_app/utils/responsive.dart';
import 'package:hook_app/utils/nav.dart';

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
  List<WalletTransaction> _subscriptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

        final upperCategory = (WalletTransaction t) =>
            (t.category ?? '').toUpperCase();
        
        // Filter transactions
        _earnings = transactions.where((t) => 
          t.type == TransactionType.earning &&
          t.status == TransactionStatus.completed &&
          upperCategory(t) != 'SUBSCRIPTION'
        ).toList();
        
        _withdrawals = transactions.where((t) => 
          t.type == TransactionType.withdrawal
        ).toList();

        _subscriptions = transactions.where((t) =>
          upperCategory(t) == 'SUBSCRIPTION'
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
            onPressed: () => Nav.safePop(context),
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
                  Nav.safePop(context);
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
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Wallet', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConstants.mutedGray, size: 20),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
          : _error != null
              ? _buildErrorWidget()
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _buildBalanceCard(),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _buildTransactionSections(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(color: AppConstants.mutedGray, fontSize: 13, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 8),
          Text(
            'KSh ${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Sora',
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _balance > 0 ? _showWithdrawalDialog : null,
                  icon: const Icon(Icons.account_balance_wallet, size: 18, color: Colors.white),
                  label: const Text('Withdraw', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: const Icon(Icons.history, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSections() {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorColor: AppConstants.primaryColor,
            labelColor: Colors.white,
            unselectedLabelColor: AppConstants.mutedGray,
            labelStyle: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Earnings'),
              Tab(text: 'Subs'),
              Tab(text: 'Withdraws'),
              Tab(text: 'Pending'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionList(_allTransactions),
              _buildTransactionList(_earnings),
              _buildTransactionList(_subscriptions),
              _buildTransactionList(_withdrawals),
              _buildTransactionList(_pending),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<WalletTransaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppConstants.mutedGray.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No transactions yet', style: TextStyle(color: AppConstants.mutedGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        final isCredit = t.type == TransactionType.earning;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.cardNavy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isCredit ? AppConstants.successColor : AppConstants.accentColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit ? Icons.add_rounded : Icons.remove_rounded,
                  color: isCredit ? AppConstants.successColor : AppConstants.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.displayDescription,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      t.formattedDate,
                      style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'}${t.formattedAmount}',
                    style: TextStyle(
                      color: isCredit ? AppConstants.successColor : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(t.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getStatusText(t.status),
                      style: TextStyle(color: _getStatusColor(t.status), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed: return AppConstants.successColor;
      case TransactionStatus.pending: return Colors.orange;
      case TransactionStatus.failed: return AppConstants.errorColor;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed: return 'Completed';
      case TransactionStatus.pending: return 'Pending';
      case TransactionStatus.failed: return 'Failed';
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppConstants.errorColor),
          const SizedBox(height: 16),
          const Text('Error loading wallet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', style: const TextStyle(color: AppConstants.mutedGray), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadWalletData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
