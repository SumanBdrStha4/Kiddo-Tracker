import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:kiddo_tracker/model/subscription.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? childid;
  final String? already;
  const SubscriptionScreen({super.key, this.childid, this.already});
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionPackage> _packages = [];
  bool _loading = true;
  String? _selectedPackageId;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
    // fetch data from server
    final response = await ApiManager().post(
      'ktusersubplans',
      data: {
        'userid': await SharedPreferenceHelper.getUserNumber(),
        'sessionid': await SharedPreferenceHelper.getUserSessionId(),
      },
    );
    if (response.statusCode == 200) {
      Logger().i(response.data);
      if (response.data[0]['result'] == 'ok') {
        setState(() {
          _packages = (response.data[1]['data'] as List)
              .map((e) => SubscriptionPackage.fromJson(e))
              .toList();
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectPackage(SubscriptionPackage package) async {
    final id = package.planid.toString();
    final price = package.price;
    setState(() {
      _selectedPackageId = id;
    });
    //check the price of the package if it is free or 0 then make payment directly success
    if (price == 0) {
      //sucess of selected plan name
      await runAddSubAPI('');
    } else {
      // Open Razorpay payment
      await _openRazorpayPayment(id);
    }
  }

  Future<void> _openRazorpayPayment(String packageId) async {
    final pkg = _packages.firstWhere((p) => p.planid.toString() == packageId);
    final userNumber = await SharedPreferenceHelper.getUserNumber();
    var options = {
      'key': 'rzp_live_8FVRENTw3hD1fy',
      'amount': (pkg.price * 100).toInt(),
      'name': 'Kiddo Tracker',
      'description': pkg.plan_name,
      'prefill': {'contact': userNumber},
    };
    _razorpay.open(options);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('Payment successful');
    Logger().i('Payment successful');
    // store the payment details
    final paymentId = response.paymentId;
    print('Payment ID: $paymentId');

    Logger().i(paymentId);
    //call another method
    await runAddSubAPI(paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message}',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Subscription Packages')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.card_membership,
                              color: Colors.blueGrey,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pkg.plan_name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Price: \₹${pkg.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Features:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: pkg.plan_details
                              .split(',')
                              .map(
                                (feature) => Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.blueGrey.shade400,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        feature.trim(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blueGrey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _selectPackage(pkg),
                          child: Center(
                            child: Text(
                              'Select & Pay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> runAddSubAPI(String? paymentId) async {
    // store the payment details
    final packageId = _selectedPackageId;
    final packageName = _packages
        .firstWhere((p) => p.planid.toString() == packageId)
        .plan_name;
    final packageDetails = _packages
        .firstWhere((p) => p.planid.toString() == packageId)
        .plan_details;
    final packageValidity = _packages
        .firstWhere((p) => p.planid.toString() == packageId)
        .validity;
    final price = _packages
        .firstWhere((p) => p.planid.toString() == packageId)
        .price;
    //only date and time 2025-09-12 13:53:35.885821 remove .885821
    final currentDate = DateTime.now().toIso8601String().split('.')[0];
    final endDateString = DateTime.now()
        .add(Duration(days: packageValidity))
        .toIso8601String()
        .split('.')[0];
    Logger().i(
      'Payment successful: $paymentId, $packageName, $packageDetails, $packageValidity, $price, $currentDate, $endDateString',
    );
    // send the payment details to the server
    final userNumber = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    final previous = widget.already;
    Logger().i(
      'check $userNumber $sessionId ${widget.childid?.toString()}, previous: $previous',
    );
    final response2 = await ApiManager().post(
      previous == "already" ? "ktusersubplanrenew" : 'ktusersubplanadd',
      data: {
        'userid': userNumber,
        'sessionid': sessionId,
        "student_id": widget.childid,
        "plan_name": packageName,
        "plan_details": packageDetails,
        "validity": packageValidity,
        "price": price,
        "startdate": currentDate,
        "enddate": endDateString,
        "status": "0",
        "subscribed_date": currentDate,
        "transaction_id": paymentId,
        "trdetails": paymentId,
      },
    );
    Logger().i(response2.data);
    if (response2.statusCode == 200) {
      if (response2.data[0]['result'] == 'ok') {
        if (response2.data[1]['data'] == 'ok') {
          //ADD TO studentSubscriptions DATABASE
          await SqfliteHelper().insertStudentSubscription(
            SubscriptionPlan(
              student_id: widget.childid ?? '',
              plan_name: packageName,
              plan_details: packageDetails,
              validity: packageValidity,
              price: price,
              startdate: currentDate,
              enddate: endDateString,
              status: 1,
              userid: userNumber ?? '',
            ),
          );
          //update child table status
          // await SqfliteHelper().updateChildStatus(widget.childid ?? '', 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment successful: ${response2.data[1]['data']}',
                style: TextStyle(color: Colors.green),
              ),
            ),
          );
          //after payment is successful, navigate back to the home screen and update the student details
          Navigator.pop(context, true);
        }
      }
    }
  }
}
