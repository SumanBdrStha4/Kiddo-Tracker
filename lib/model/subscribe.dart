class SubscriptionPlan {
  final String student_id;
  final String plan_name;
  final String plan_details;
  final int validity;
  final int price;
  final String startdate;
  final String enddate;
  final int status;
  final String userid;

  SubscriptionPlan({
    required this.student_id,
    required this.plan_name,
    required this.plan_details,
    required this.validity,
    required this.price,
    required this.startdate,
    required this.enddate,
    required this.status,
    required this.userid,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      student_id: json['student_id'],
      plan_name: json['plan_name'],
      plan_details: json['plan_details'],
      validity: json['validity'],
      price: json['price'],
      startdate: json['startdate'],
      enddate: json['enddate'],
      status: json['status'],
      userid: json['userid'],
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': student_id,
    'plan_name': plan_name,
    'plan_details': plan_details,
    'validity': validity,
    'price': price,
    'startdate': startdate,
    'enddate': enddate,
    'status': status,
    'userid': userid,
  };

  @override
  String toString() {
    return toJson().toString();
  }
}
