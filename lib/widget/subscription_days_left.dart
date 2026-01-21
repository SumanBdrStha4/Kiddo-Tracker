import 'package:flutter/material.dart';

class SubscriptionDaysLeft extends StatelessWidget {
  final DateTime subscriptionEndDate;

  const SubscriptionDaysLeft({
    super.key,
    required this.subscriptionEndDate,
  });

  int _checkSubscriptionDaysLeft() {
    final now = DateTime.now();
    final difference = subscriptionEndDate.difference(now);
    return difference.inDays;
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _checkSubscriptionDaysLeft();
    return Text('$daysLeft');
  }
}