import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';

class BnBWalletScreen extends StatefulWidget {
  const BnBWalletScreen({super.key});

  @override
  State<BnBWalletScreen> createState() => _BnBWalletScreenState();
}

class _BnBWalletScreenState extends State<BnBWalletScreen> {
  // Mock data for now
  final double _totalEarnings = 45000.0;
  final double _pendingPayout = 12500.0;
  final List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN123456',
      'date': '2025-11-28',
      'amount': 5000.0,
      'status': 'Completed',
      'bnb': 'Cozy Apartment in CBD',
    },
    {
      'id': 'TXN123457',
      'date': '2025-11-27',
      'amount': 3500.0,
      'status': 'Completed',
      'bnb': 'Luxury Villa',
    },
    {
      'id': 'TXN123458',
      'date': '2025-11-26',
      'amount': 4000.0,
      'status': 'Pending',
      'bnb': 'Cozy Apartment in CBD',
    },
  ];

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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
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
              Text(
                'Total Earnings',
                style: TextStyle(
                  color: AppConstants.softWhite.withOpacity(0.9),
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
            'KES ${_totalEarnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppConstants.softWhite,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Payout',
                      style: TextStyle(
                        color: AppConstants.softWhite.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${_pendingPayout.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppConstants.softWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Withdrawal request sent!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.softWhite,
                    foregroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Withdraw'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final txn = _transactions[index];
        final isCompleted = txn['status'] == 'Completed';
        
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
                  color: isCompleted 
                      ? AppConstants.successColor.withOpacity(0.2)
                      : AppConstants.accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.access_time,
                  color: isCompleted ? AppConstants.successColor : AppConstants.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn['bnb'],
                      style: const TextStyle(
                        color: AppConstants.softWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txn['date'],
                      style: TextStyle(
                        color: AppConstants.mutedGray.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+ KES ${txn['amount'].toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppConstants.successColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    txn['status'],
                    style: TextStyle(
                      color: isCompleted 
                          ? AppConstants.successColor 
                          : AppConstants.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
}
