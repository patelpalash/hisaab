import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'splash/splash_screen.dart';
import 'auth/login_page.dart';
import 'models/user_model.dart';
import 'models/transaction_model.dart';
import 'models/category_model.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/category_provider.dart';
import 'providers/budget_provider.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/transactions/transactions_list_screen.dart';
import 'screens/transactions/transaction_detail_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'widgets/financial_summary_chart.dart';
import 'widgets/app_drawer.dart';

// App theme colors
final Color primaryColor = Color(0xFF6C63FF); // Main light purple color
final Color accentColor = Color(0xFF8B80FF); // Secondary purple shade
final Color lightPurple = Color(0xFF6C63FF); // For gradient elements
final Color lightPurpleFaded = Color(0xFF8B80FF); // For gradient elements

// Main dashboard page - Connected to providers
class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize providers with current user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        final userId = authProvider.user.uid;

        // Initialize transactions and categories
        Provider.of<TransactionProvider>(context, listen: false)
            .initTransactions(userId);
        Provider.of<CategoryProvider>(context, listen: false)
            .initCategories(userId);
      }
    });
  }

  // Format currency
  String _formatCurrency(double amount) {
    return '₹${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent and set icon color
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Access providers
    final authProvider = Provider.of<AuthProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    // Get user data
    final user = authProvider.user;

    // Get transaction data
    final recentTransactions = transactionProvider.recentTransactions;
    final totalIncome = transactionProvider.totalIncome;
    final totalExpenses = transactionProvider.totalExpenses;
    final balance = transactionProvider.balance;

    // Get category data
    final expenseCategories = categoryProvider.expenseCategories;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      drawer: AppDrawer(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Modern App Bar with transparent styling
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: lightPurple,
              elevation: 0,
              toolbarHeight: 80,
              title: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: Text(
                  'Hisaab',
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: Colors.white, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                // Notification Icon
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () {
                        // Show notifications
                      },
                    ),
                  ),
                ),
                // Profile Icon/Avatar - Shows first letter of user's name
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      // Show debug options in development mode
                      if (kDebugMode) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Development Options'),
                            content: const Text(
                                'These options are only available in debug mode.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Debug transactions view was removed
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Debug page was removed'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Text('Debug Transactions'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: lightPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Dashboard Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card (Similar to the image)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          lightPurple,
                          lightPurpleFaded,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: lightPurple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
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
                              'Current Balance',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.more_horiz,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatCurrency(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Income summary
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: Colors.green.shade300,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _formatCurrency(totalIncome),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // Expense summary
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      color: Colors.red.shade300,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _formatCurrency(totalExpenses),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick Actions - like in the image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(
                          icon: Icons.add,
                          iconColor: Colors.green,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          label: 'Add Income',
                          onTap: () {
                            // Add income action
                            _showAddTransactionDialog(context, false);
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.remove,
                          iconColor: Colors.red,
                          backgroundColor: Colors.red.withOpacity(0.1),
                          label: 'Add Expense',
                          onTap: () {
                            // Add expense action
                            _showAddTransactionDialog(context, true);
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.bar_chart,
                          iconColor: Colors.blue,
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          label: 'Reports',
                          onTap: () {
                            // Show reports
                          },
                        ),
                        _buildQuickAction(
                          icon: Icons.pie_chart,
                          iconColor: Colors.purple,
                          backgroundColor: Colors.purple.withOpacity(0.1),
                          label: 'Budget',
                          onTap: () {
                            // Show budget page
                          },
                        ),
                      ],
                    ),
                  ),

                  // Financial Summary Chart (replacing Categories)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, top: 24.0, bottom: 12.0),
                    child: FinancialSummaryChart(
                      income: totalIncome,
                      expense: totalExpenses,
                      balance: balance,
                    ),
                  ),

                  // Recent Transactions section header with "View All" text
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // View all transactions
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TransactionsListScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: lightPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Transaction List
            recentTransactions.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long,
                                size: 64, color: Colors.grey.shade400),
                            SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add your first transaction using the buttons above',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Find the category for this transaction
                        final transaction = recentTransactions[index];
                        final category = categoryProvider
                            .getCategoryById(transaction.categoryId);

                        return _buildTransactionItem(transaction, category);
                      },
                      childCount: recentTransactions.length,
                    ),
                  ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),

      // Floating action button for adding transactions - like in the image
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show add transaction dialog, default to expense
          _showAddTransactionDialog(context, true);
        },
        backgroundColor: lightPurple,
        child: const Icon(Icons.add),
      ),

      // Bottom navigation bar with Home, Transactions, Budget, Profile tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Navigate to screens based on index
          if (index == 1) {
            // Transactions tab
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TransactionsListScreen(),
              ),
            );
          } else if (index == 2) {
            // Budget tab
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BudgetListScreen(),
              ),
            );
          }
        },
        selectedItemColor: lightPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Helper method to build quick action buttons - square style like in the image
  Widget _buildQuickAction({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build category cards - rounded cards like in the image
  Widget _buildCategoryCard(CategoryModel category) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 70,
            width: 70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: category.backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              category.icon,
              color: category.color,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build transaction list items
  Widget _buildTransactionItem(
      TransactionModel transaction, CategoryModel? category) {
    // Default icon and colors for transaction if category is not found
    IconData icon =
        transaction.isExpense ? Icons.arrow_upward : Icons.arrow_downward;
    Color iconColor = transaction.isExpense ? Colors.red : Colors.green;
    Color backgroundColor = transaction.isExpense
        ? Colors.red.withOpacity(0.1)
        : Colors.green.withOpacity(0.1);

    // If category exists, use its icon and colors
    if (category != null) {
      icon = category.icon;
      iconColor = category.color;
      backgroundColor = category.backgroundColor;
    }

    // Create the transaction card
    Widget transactionCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Category icon with background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 16),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('MMMM dd, yyyy').format(transaction.date),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            transaction.isExpense
                ? '- ${_formatCurrency(transaction.amount)}'
                : '+ ${_formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: transaction.isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );

    // Wrap with Slidable for swipe actions
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        key: Key(transaction.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                _navigateToEditTransaction(context, transaction);
              },
              backgroundColor: Colors.transparent,
              foregroundColor: primaryColor,
              icon: Icons.edit_outlined,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              spacing: 4,
              autoClose: true,
            ),
            SlidableAction(
              onPressed: (_) {
                _confirmDeleteTransaction(context, transaction);
              },
              backgroundColor: Color(0xFFF06292), // Pink shade
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              spacing: 4,
              autoClose: true,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  // Navigate to transaction detail screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TransactionDetailScreen(transaction: transaction),
                    ),
                  );
                },
                child: transactionCard,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Confirm delete dialog
  void _confirmDeleteTransaction(
      BuildContext context, TransactionModel transaction) {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.isExpense ? 'expense' : 'income'} of ${_formatCurrency(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Delete the transaction
              final success =
                  await transactionProvider.deleteTransaction(transaction.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete transaction')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Show dialog to add a new transaction
  void _showAddTransactionDialog(BuildContext context, bool isExpense) {
    // Navigate to the new transaction screen instead of showing a dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(isExpense: isExpense),
      ),
    );
  }

  // Navigate to edit transaction screen
  void _navigateToEditTransaction(
      BuildContext context, TransactionModel transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          isExpense: transaction.isExpense,
          transactionToEdit: transaction,
        ),
      ),
    );
  }
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (kDebugMode) {
      print('Initializing Firebase...');
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode) {
      print('Firebase initialized successfully!');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase: $e');
    }
    // Continue anyway so the app can show an appropriate error screen
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set system UI styling
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return MaterialApp(
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightPurple,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: lightPurple,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: lightPurple,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const SplashScreen();
          }

          if (authProvider.isAuthenticated) {
            // User is logged in, show the home page
            return HomePage();
          } else {
            // User is not logged in, show the login page
            return const LoginPage();
          }
        },
      ),
    );
  }
}
