import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class AddChildScreen extends StatefulWidget {
  final Map<String, dynamic>? childData;
  final bool isEdit;

  const AddChildScreen({super.key, this.childData, this.isEdit = false});

  @override
  _AddChildScreenState createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  SqfliteHelper db = SqfliteHelper();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  // final TextEditingController _stateController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _nicknameFocus = FocusNode();
  final FocusNode _schoolFocus = FocusNode();
  final FocusNode _classFocus = FocusNode();
  final FocusNode _rollNoFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();

  String? gender;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.childData != null) {
      _nameController.text = widget.childData!['name'] ?? '';
      _nicknameController.text = widget.childData!['nickname'] ?? '';
      _schoolController.text = widget.childData!['school'] ?? '';
      _classNameController.text = widget.childData!['class_name'] ?? '';
      _rollNoController.text = widget.childData!['rollno'] ?? '';
      // _stateController.text = widget.childData!['state'] ?? '';
      _ageController.text = widget.childData!['age']?.toString() ?? '';
      gender = widget.childData!['gender'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _schoolController.dispose();
    _classNameController.dispose();
    _rollNoController.dispose();
    _ageController.dispose();
    _nameFocus.dispose();
    _nicknameFocus.dispose();
    _schoolFocus.dispose();
    _classFocus.dispose();
    _rollNoFocus.dispose();
    _ageFocus.dispose();
    // _stateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, [Color? color]) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _validateAndSubmit() async {
    //get the form data
    final String? userId = await SharedPreferenceHelper.getUserNumber();
    final String? sessionId = await SharedPreferenceHelper.getUserSessionId();
    final childname = _nameController.text;
    final nickname = _nicknameController.text;
    final school = _schoolController.text;
    final className = _classNameController.text;
    final rollNo = _rollNoController.text;
    final age = _ageController.text;
    //using database user table
    final users = await db.getUsers();
    final state = users[0]['state'];
    Logger().i(
      'name: $childname, nickname: $nickname, school: $school, class: $className, rollNo: $rollNo, age: $age, state: $state, gender: $gender',
    );
    //validate the form data
    if (childname.isEmpty ||
        nickname.isEmpty ||
        school.isEmpty ||
        className.isEmpty ||
        rollNo.isEmpty ||
        state.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.red);
    } else {
      //print
      Logger().i('userid: $userId');
      Logger().i('sessionid: $sessionId');
      Logger().i(
        'Name: $childname, Nickname: $nickname, School: $school, Class: $className, Roll No: $rollNo, State: $state, Gender: $gender',
      );

      final apiEndpoint = widget.isEdit
          ? 'ktuserstudentedit'
          : 'ktuseraddstudent';

      final response = await ApiManager().post(
        apiEndpoint,
        data: {
          'userid': userId,
          'sessionid': sessionId,
          'name': childname,
          'nickname': nickname,
          'school': school,
          'class': className,
          'rollno': rollNo,
          'gender': gender,
          'age': age,
          'state': state,
          if (widget.isEdit) 'student_id': widget.childData?['student_id'],
        },
      );
      final data = response.data;
      Logger().i(data);
      if (data[0]['result'] == 'ok') {
        final int parsedAge = int.parse(age);
        if (!widget.isEdit) {
          //add new child in database
          final studentId = data[1]['data']['student_id'] ?? '';
          final child = Child(
            studentId: studentId,
            name: childname,
            nickname: nickname,
            school: school,
            class_name: className,
            rollno: rollNo,
            age: parsedAge,
            gender: gender ?? '',
            tagId: "",
            routeInfo: [],
            tsp_id: [],
            status: 0,
            onboard_status: 0,
          );
          // save child to database
          await db.insertChild(child);
          //show child data
          Logger().i(child.toJson());
          Logger().i('Child added successfully');
          // update MQTT subscriptions with new child
          final provider = Provider.of<ChildrenProvider>(
            context,
            listen: false,
          );
          await provider.subscribeToNewStudentTopics(studentId);
        } else {
          // update existing child in database
          final studentId = widget.childData?['student_id'] ?? '';
          final child = Child(
            studentId: studentId,
            name: childname,
            nickname: nickname,
            school: school,
            class_name: className,
            rollno: rollNo,
            age: parsedAge,
            gender: gender ?? '',
            tagId: widget.childData?['tagId'] ?? '',
            routeInfo: widget.childData?['routeInfo'] ?? [],
            tsp_id: widget.childData?['tsp_id'] ?? '',
            status: widget.childData?['status'] ?? 0,
            onboard_status: widget.childData?['onboard_status'] ?? 0,
          );
          await db.updateChild(child);
          Logger().i('Child updated successfully');
        }
        _showSnackBar(
          widget.isEdit
              ? 'Child updated successfully'
              : 'Child added successfully',
          Colors.green,
        );
        // clear all the text fields
        clearAllField();
        // update the list of children in the HomeScreen
        Provider.of<ChildrenProvider>(context, listen: false).updateChildren();
        //back to home screen
        // Navigator.pushNamedAndRemoveUntil(
        //   context,
        //   AppRoutes.main,
        //   (route) => false,
        // );
      } else {
        _showSnackBar(
          widget.isEdit ? 'Error updating child' : 'Error adding child',
          Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.isEdit ? 'Edit Child' : 'Add Child'),
      //   backgroundColor: colorScheme.primary,
      //   foregroundColor: colorScheme.onPrimary,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                widget.isEdit
                    ? 'Edit '
                    : 'Add '
                          'Child Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(
                            Icons.person,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onFieldSubmitted: (value) =>
                            FocusScope.of(context).requestFocus(_nicknameFocus),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nicknameController,
                        focusNode: _nicknameFocus,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Nickname',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onFieldSubmitted: (value) =>
                            FocusScope.of(context).requestFocus(_schoolFocus),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter nickname'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _schoolController,
                        focusNode: _schoolFocus,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                          labelText: 'School Name',
                          prefixIcon: Icon(
                            Icons.school,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onFieldSubmitted: (value) =>
                            FocusScope.of(context).requestFocus(_classFocus),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter school'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _classNameController,
                        focusNode: _classFocus,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          prefixIcon: Icon(
                            Icons.class_,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onFieldSubmitted: (value) =>
                            FocusScope.of(context).requestFocus(_rollNoFocus),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter class'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rollNoController,
                        focusNode: _rollNoFocus,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Roll No',
                          prefixIcon: Icon(
                            Icons.numbers,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter roll no';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        initialValue: gender,
                        items: ['Male', 'Female', 'Other']
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Row(
                                  children: [
                                    Icon(
                                      g == 'Male'
                                          ? Icons.male
                                          : g == 'Female'
                                          ? Icons.female
                                          : Icons.person,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(g),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => gender = value),
                        validator: (value) =>
                            value == null ? 'Select gender' : null,
                        dropdownColor: colorScheme.surface,
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(
                            Icons.calendar_month,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter age' : null,
                      ),
                      // SizedBox(height: 16),
                      // TextFormField(
                      //   controller: _stateController,
                      //   keyboardType: TextInputType.streetAddress,
                      //   decoration: InputDecoration(
                      //     labelText: 'State',
                      //     prefixIcon: Icon(Icons.location_on),
                      //     border: OutlineInputBorder(),
                      //   ),
                      //   validator: (value) => value == null || value.isEmpty
                      //       ? 'Enter state'
                      //       : null,
                      // ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(widget.isEdit ? 'Update Child' : 'Add Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void clearAllField() {
    // Clear all text fields and Dropdown and selected
    _nameController.clear();
    _nicknameController.clear();
    _schoolController.clear();
    _classNameController.clear();
    _rollNoController.clear();
    _ageController.clear();
    gender = null;
    setState(() {});
  }
}
