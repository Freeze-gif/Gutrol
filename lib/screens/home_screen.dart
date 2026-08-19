import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/esp32_service.dart';
import '../services/wallet_service.dart';
import 'fuel_order_screen.dart';
import 'live_status_screen.dart';
import 'history_screen.dart';
import 'notification_screen.dart';
import 'login_screen.dart';
import 'payment/wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnecting = false;
  Timer? _hazardPollingTimer;

  @override
  void initState() {
    super.initState();
    AppState.init();
    
    // Load wallet data and orders from Firebase
    _loadFirebaseData();
    
    // Configure ESP32 IP address
    if (AppState.hasEsp32Ip) {
      Esp32Service.setIpAddress(AppState.esp32IpAddress);
    }
    
    // Test connection to ESP32
    _testConnection();

    // Start global hazard polling
    _startHazardPolling();
  }

  @override
  void dispose() {
    _hazardPollingTimer?.cancel();
    super.dispose();
  }

  void _startHazardPolling() {
    _hazardPollingTimer?.cancel();
    _hazardPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkHazardStatus();
    });
  }

  Future<void> _checkHazardStatus() async {
    try {
      final status = await Esp32Service.getStatus();
      if (status != null) {
        AppState.updateHazardStatus(status.hazardActive);
      }
    } catch (e) {
      // Ignore polling errors to prevent UI noise
    }
  }

  Future<void> _loadFirebaseData() async {
    await WalletService.loadWalletData();
    await WalletService.loadOrders();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isConnecting = true);

    try {
      final isConnected = await Esp32Service.testConnection().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      setState(() {
        _isConnecting = false;
        AppState.isEsp32Connected = isConnected;
      });

      if (mounted && isConnected) {
        // Only show success snackbar, don't block on failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Fuel pump system connected!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        AppState.isEsp32Connected = false;
      });
      print('[ESP32] Connection test error: $e');
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final result = await AuthService.logout();
    if (result['success']) {
      AppState.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      // Refresh state when returning (for wallet balance updates)
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Connection Status Indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppState.isEsp32Connected 
                ? Colors.green.withAlpha((0.2 * 255).round())
                : Colors.red.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppState.isEsp32Connected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: AppState.isEsp32Connected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  AppState.isEsp32Connected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppState.isEsp32Connected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header with User Info
              _buildWelcomeHeader(),
              const SizedBox(height: 20),
              
              // Wallet Balance Card
              _buildWalletCard(),
              const SizedBox(height: 20),
              
              // Quick Stats Row
              _buildQuickStats(),
              const SizedBox(height: 24),
              
              // Quick Actions Grid
              _buildSectionTitle('Quick Actions', Icons.flash_on),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),
              
              // Fuel Prices Section
              _buildSectionTitle('Fuel Prices Today', Icons.local_gas_station),
              const SizedBox(height: 12),
              _buildFuelPricesCard(),
              const SizedBox(height: 24),
              
              // Recent Activity Section
              _buildRecentActivitySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha((0.3 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good Day,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppState.customerName.isEmpty
                        ? 'Customer'
                        : AppState.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          if (AppState.licensePlate.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppState.licensePlate,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Ready to fuel up? Your vehicle is waiting!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Color(0xFF1565C0),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet Balance',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppState.walletBalance.toStringAsFixed(0)} MMK',
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _navigateTo(const WalletScreen()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Top Up'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    // Calculate total liters from history
    double totalLiters = 0;
    for (var order in AppState.history) {
      if (order['status'] == 'Completed' || order['status'] == 'stopped_by_hazard') {
        final amountStr = order['amount'] as String? ?? '';
        // Extract liters from strings like "2.50 Liters / 8000 MMK" or "1.25 L / 4000 MMK"
        try {
          if (amountStr.contains('Liters')) {
            totalLiters += double.parse(amountStr.split(' Liters')[0]);
          } else if (amountStr.contains(' L ')) {
            totalLiters += double.parse(amountStr.split(' L ')[0]);
          }
        } catch (e) {
          debugPrint('Error parsing liters: $e');
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_gas_station,
            label: 'Total Fill-ups',
            value: '${AppState.history.length}',
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.speed,
            label: 'Liters Fueled',
            value: '${totalLiters.toStringAsFixed(1)} L',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildActionCard(
          icon: Icons.local_gas_station,
          title: 'New Order',
          subtitle: 'Start fueling',
          color: const Color(0xFF1565C0),
          onTap: () => _navigateTo(const FuelOrderScreen()),
        ),
        _buildActionCard(
          icon: Icons.account_balance_wallet,
          title: 'My Wallet',
          subtitle: 'Top up & balance',
          color: const Color(0xFF0D47A1),
          onTap: () => _navigateTo(const WalletScreen()),
        ),
        _buildActionCard(
          icon: Icons.sync,
          title: 'Live Status',
          subtitle: 'Monitor pump',
          color: Colors.green,
          onTap: () => _navigateTo(const LiveStatusScreen()),
        ),
        _buildActionCard(
          icon: Icons.history,
          title: 'History',
          subtitle: 'Past transactions',
          color: Colors.orange,
          onTap: () => _navigateTo(const HistoryScreen()),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withAlpha((0.1 * 255).round()), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelPricesCard() {
    final fuelTypes = [
      {'name': 'Petrol 92', 'price': '3,200', 'icon': Icons.local_gas_station},
      {'name': 'Petrol 95', 'price': '3,400', 'icon': Icons.local_gas_station},
      {'name': 'Diesel', 'price': '2,800', 'icon': Icons.local_shipping},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: fuelTypes.map((fuel) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    fuel['icon'] as IconData,
                    color: const Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fuel['name'] as String,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${fuel['price']} MMK/L',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    // Combine fuel orders and wallet transactions
    final List<Map<String, dynamic>> allActivities = [];
    
    // Add fuel orders
    for (var order in AppState.history) {
      final isHazardStop = order['status'] == 'stopped_by_hazard';
      allActivities.add({
        'title': order['fuelType'],
        'subtitle': order['date'],
        'detail': order['amount'],
        'status': isHazardStop ? 'Hazard Stop' : order['status'],
        'icon': isHazardStop ? Icons.warning_amber_rounded : Icons.local_gas_station,
        'iconColor': isHazardStop ? Colors.red : const Color(0xFF1565C0),
        'isPositive': false,
        'isHazard': isHazardStop,
      });
    }
    
    // Add wallet transactions
    for (var tx in AppState.walletTransactions) {
      final isTopUp = tx['type'] == 'topup';
      final timestamp = DateTime.parse(tx['timestamp'] as String);
      allActivities.add({
        'title': tx['description'],
        'subtitle': timestamp.toString().substring(0, 16),
        'detail': '${isTopUp ? "+" : "-"}${(tx['amount'] as double).toStringAsFixed(0)} MMK',
        'status': tx['status'],
        'icon': isTopUp ? Icons.add_circle : Icons.remove_circle,
        'iconColor': isTopUp ? Colors.green : Colors.red,
        'isPositive': isTopUp,
      });
    }

    if (allActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No recent activity',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final recent = allActivities.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: recent.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          final isLast = index == recent.length - 1;
          
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (activity['iconColor'] as Color).withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['iconColor'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          activity['subtitle'] as String,
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                        activity['detail'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: activity['isPositive'] == true 
                              ? Colors.green 
                              : (activity['isHazard'] == true ? Colors.red : const Color(0xFF1565C0)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (activity['isHazard'] == true ? Colors.red : Colors.green).withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          activity['status'] as String,
                          style: TextStyle(
                            color: activity['isHazard'] == true ? Colors.red : Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isLast) 
                Divider(height: 24, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      children: [
        // Recent Activity
        _buildSectionTitle('Recent Activity', Icons.history),
        const SizedBox(height: 12),
        _buildRecentActivityCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppState.customerName.isEmpty ? 'Guest' : AppState.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (AppState.licensePlate.isNotEmpty)
                    Text(
                      AppState.licensePlate,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Wallet',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(const WalletScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.pop(context);
                      _showProfile();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Fueling History',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(const HistoryScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(const NotificationScreen());
                    },
                  ),
                  const Divider(height: 1),
                  _buildDrawerItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpSupport();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      _showAbout();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      _showPrivacyPolicy();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () {
                      Navigator.pop(context);
                      _showTermsOfService();
                    },
                  ),
                ],
              ),
            ),
            
            // App Version
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Version 1.0.0 • Gutrol Edition',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const Divider(height: 1),
            // Logout at bottom
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Registered Customer Information',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileItem('Full Name', AppState.customerName),
            _buildProfileItem('Vehicle Number', AppState.licensePlate),
            _buildProfileItem('Preferred Fuel', AppState.selectedFuelType.isEmpty ? 'Not selected' : AppState.selectedFuelType),
            _buildProfileItem('Member Since', '2024'),
            _buildProfileItem('Total Fill-ups', '${AppState.history.length} times'),
            const SizedBox(height: 24),
            // Edit Profile Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditProfile();
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text(
          'To update your profile information, please visit the station counter or contact support.\n\n'
          'For security reasons, profile changes cannot be made through the app directly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not available' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.headset_mic, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Help & Support'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Guide Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Guide',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHelpItem(Icons.local_gas_station, 'Step 1: Choose Fuel', 'Select Petrol 92, Petrol 95, or Diesel.'),
                    _buildHelpItem(Icons.attach_money, 'Step 2: Enter Amount', 'Enter MMK amount or tap "Full Tank".'),
                    _buildHelpItem(Icons.shopping_cart, 'Step 3: Submit Order', 'Press "Submit Order" to start.'),
                    _buildHelpItem(Icons.sync, 'Step 4: Monitor', 'Watch live status while fueling.'),
                    _buildHelpItem(Icons.payment, 'Step 5: Payment', 'Pay at counter after completion.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fuel Types Available in Myanmar
              Text(
                'Available Fuel Types',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              _buildFuelTypeInfo('Petrol 92', 'Standard unleaded for most vehicles'),
              _buildFuelTypeInfo('Petrol 95', 'Premium for high-performance engines'),
              _buildFuelTypeInfo('Diesel', 'For diesel vehicles and trucks'),
              const SizedBox(height: 16),
              const Divider(),
              // Contact Information (Myanmar)
              Text(
                'Contact Us (Myanmar)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 12),
              _buildContactItem(Icons.phone, 'Hotline', '09 123 456 789'),
              _buildContactItem(Icons.phone_android, 'Viber', '09 987 654 321'),
              _buildContactItem(Icons.email, 'Email', 'support@myanmarpetrol.com'),
              _buildContactItem(Icons.location_on, 'Address', 'No. 123, Pyay Road, Yangon'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Support Hours: 6:00 AM - 10:00 PM',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelTypeInfo(String type, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_gas_station, color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_gas_station,
                size: 50,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gutrol',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A modern fuel station application designed for Myanmar customers. '
                'Connect to smart pumps and enjoy a seamless, cashless fueling experience.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Features
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Features',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem('Real-time pump monitoring'),
                    _buildFeatureItem('MMK currency support'),
                    _buildFeatureItem('Multiple fuel types (92, 95, Diesel)'),
                    _buildFeatureItem('Automatic & manual modes'),
                    _buildFeatureItem('Emergency stop functionality'),
                    _buildFeatureItem('Fill history tracking'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Myanmar Specific
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Licensed by Myanmar Ministry of Energy',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '© 2024 Gutrol Fuel Station.\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Text(feature, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    _showInfoDialog('Privacy Policy', 
      'Gutrol - Privacy Policy\n\n'
      '1. Information We Collect:\n'
      '   • Name and phone number for account registration\n'
      '   • Vehicle license plate for fueling records\n'
      '   • Fueling history and transaction data\n\n'
      '2. How We Use Your Data:\n'
      '   • To process fuel orders and payments\n'
      '   • To maintain fueling records for receipts\n'
      '   • To improve our services\n\n'
      '3. Data Protection:\n'
      '   • All data is encrypted and stored securely\n'
      '   • We comply with Myanmar data protection regulations\n'
      '   • Your data is never sold to third parties\n\n'
      '4. Your Rights:\n'
      '   • You can request your data deletion\n'
      '   • You can access your fueling history anytime\n'
      '   • Contact us for any privacy concerns\n\n'
      'For questions: privacy@myanmarpetrol.com');
  }

  void _showTermsOfService() {
    _showInfoDialog('Terms of Service',
      'GUTROL - TERMS OF SERVICE\n\n'
      '1. Acceptance of Terms:\n'
      '   By using this application, you agree to these terms and conditions.\n\n'
      '2. User Responsibilities:\n'
      '   • Provide accurate personal and vehicle information\n'
      '   • Ensure your vehicle is in safe condition for fueling\n'
      '   • Follow all safety instructions at the station\n'
      '   • Pay the full amount for fuel consumed\n\n'
      '3. Prohibited Actions:\n'
      '   • Tampering with or misusing fuel pumps\n'
      '   • Using the app for fraudulent transactions\n'
      '   • Attempting to access other users\' accounts\n\n'
      '4. Payment Terms:\n'
      '   • All prices are in Myanmar Kyats (MMK)\n'
      '   • Prices subject to daily market rates\n'
      '   • Payment must be made immediately after fueling\n\n'
      '5. Liability:\n'
      '   • The station is not liable for vehicle issues unrelated to fuel quality\n'
      '   • Users assume responsibility for correct fuel type selection\n\n'
      '6. Termination:\n'
      '   - We reserve the right to suspend accounts for violations\n'
      '   - Users may delete their account at any time\n\n'
      '7. Governing Law:\n'
      '   • These terms are governed by Myanmar law\n'
      '   • Disputes will be resolved in Myanmar courts\n\n'
      'Last updated: April 2024');
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
