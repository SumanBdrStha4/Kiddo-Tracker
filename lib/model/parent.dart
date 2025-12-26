class Parent {
  final String userid;
  final String name;
  final String city;
  final String state;
  final String address;
  final String contact;
  final String email;
  final String mobile;
  final int wards;
  final int status;
  final int pin;

  Parent({
    required this.userid,
    required this.name,
    required this.city,
    required this.state,
    required this.address,
    required this.contact,
    required this.email,
    required this.mobile,
    required this.wards,
    required this.status,
    required this.pin,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      userid: json['userid'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      address: json['address'] as String,
      contact: json['contact'] as String,
      email: json['email'] as String,
      mobile: json['mobile'] as String,
      wards: json['wards'] as int,
      status: json['status'] as int,
      pin: json['pin'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userid': userid,
      'name': name,
      'city': city,
      'state': state,
      'address': address,
      'contact': contact,
      'email': email,
      'mobile': mobile,
      'wards': wards,
      'status': status,
      'pin': pin,
    };
  }
}
