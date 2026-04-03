import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  final List<Map<String, dynamic>> _notifications = const [
    {
      'title': 'Fuel Request Submitted',
      'message': 'Your fuel order has been submitted successfully.',
      'time': 'Just now',
      'icon': Icons.local_gas_station,
      'color': Colors.blue,
    },
    {
      'title': 'Order Accepted',
      'message': 'Your order has been accepted by the station.',
      'time': '5 min ago',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
    {
      'title': 'Fueling Completed',
      'message': 'Your fueling process is complete. Thank you!',
      'time': '1 hour ago',
      'icon': Icons.done_all,
      'color': Colors.teal,
    },
    {
      'title': 'Hazard Warning',
      'message': 'Please maintain safety distance during fueling.',
      'time': '2 hours ago',
      'icon': Icons.warning,
      'color': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: notification['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            notification['icon'],
            color: notification['color'],
            size: 28,
          ),
        ),
        title: Text(
          notification['title'],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  notification['time'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
