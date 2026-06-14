import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAccountPage extends StatefulWidget {
  final String? rejectReason;
  const CreateAccountPage({super.key, this.rejectReason});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  bool _showMoreInfo = false;
  bool _isLocked = false;
  bool _isLoading = false;

  final FocusNode _emailFocusNode = FocusNode();
  bool _hasEmailError = false;

  bool _idError = false;
  bool _selfieError = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedGovernorate;
  final List<String> _governorates = [
    'Beirut',
    'Mount Lebanon',
    'North Lebanon',
    'South Lebanon',
    'Bekaa',
    'Nabatieh',
    'Akkar',
    'Baalbek-Hermel',
  ];

  final Color primaryGreen = const Color(0xFF1D9E75);
  final Color bgWhite = const Color(0xFFF9F9F9);

  File? _idImage;
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    if (widget.rejectReason != null) {
      _showMoreInfo = true;
      _isLocked = false;

      if (widget.rejectReason!.contains("ID") ||
          widget.rejectReason!.contains("Passport") ||
          widget.rejectReason!.contains("Expired")) {
        _idError = true;
      } else if (widget.rejectReason!.contains("Photo") ||
          widget.rejectReason!.contains("clear") ||
          widget.rejectReason!.contains("Selfie")) {
        _selfieError = true;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Declined Reason: ${widget.rejectReason!} - Please re-upload.",
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 6),
          ),
        );
      });
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('saved_zam_name') ?? '';
      _emailController.text = prefs.getString('saved_zam_email') ?? '';
      _phoneController.text = prefs.getString('saved_zam_phone') ?? '';
      _dateController.text = prefs.getString('saved_zam_dob') ?? '';
      _addressController.text = prefs.getString('saved_zam_address') ?? '';
      _selectedGovernorate = prefs.getString('saved_zam_gov');

      _passController.text = prefs.getString('saved_zam_pass') ?? '';
      _confirmPassController.text = prefs.getString('saved_zam_pass') ?? '';

      String? idPath = prefs.getString('saved_zam_id_img');
      if (idPath != null && File(idPath).existsSync()) _idImage = File(idPath);

      String? selfiePath = prefs.getString('saved_zam_selfie_img');
      if (selfiePath != null && File(selfiePath).existsSync())
        _selfieImage = File(selfiePath);
    });
  }

  Future<void> _saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_zam_name', _nameController.text);
    await prefs.setString('saved_zam_email', _emailController.text);
    await prefs.setString('saved_zam_phone', _phoneController.text);
    await prefs.setString('saved_zam_pass', _passController.text);
    await prefs.setString('saved_zam_dob', _dateController.text);
    await prefs.setString('saved_zam_address', _addressController.text);
    if (_selectedGovernorate != null)
      await prefs.setString('saved_zam_gov', _selectedGovernorate!);

    if (_idImage != null)
      await prefs.setString('saved_zam_id_img', _idImage!.path);
    if (_selfieImage != null)
      await prefs.setString('saved_zam_selfie_img', _selfieImage!.path);
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == 'id') {
            _idImage = File(pickedFile.path);
            _idError = false;
          }
          if (type == 'selfie') {
            _selfieImage = File(pickedFile.path);
            _selfieError = false;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open camera. Check permissions.'),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null)
      setState(
        () => _dateController.text =
            "${picked.day}/${picked.month}/${picked.year}",
      );
  }

  Future<void> _submitData() async {
    setState(() {
      _isLoading = true;
      _hasEmailError = false;
    });
    await _saveDataLocally();

    try {
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        print("Error getting FCM Token: $e");
      }

      String currentCountry = "Unknown";
      String currentCity = "Unknown";
      try {
        final ipResponse = await http.get(Uri.parse('http://ip-api.com/json/'));
        if (ipResponse.statusCode == 200) {
          final ipData = jsonDecode(ipResponse.body);
          currentCountry = ipData['country'] ?? "Unknown";
          currentCity = ipData['city'] ?? "Unknown";
        }
      } catch (e) {
        print("Location fetch error: $e");
      }

      bool isResubmit = widget.rejectReason != null;
      var urlString = isResubmit
          ? "http://10.242.103.201:5000/api/auth/zamil/resubmit"
          : "http://10.242.103.201:5000/api/auth/zamil/register";

      var request = http.MultipartRequest(
        isResubmit ? 'PUT' : 'POST',
        Uri.parse(urlString),
      );

      request.fields['full_name'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone'] = _phoneController.text;
      if (!isResubmit) request.fields['password'] = _passController.text;
      request.fields['dob'] = _dateController.text;
      request.fields['governorate'] = _selectedGovernorate ?? '';
      request.fields['address'] = _addressController.text;
      request.fields['fcm_token'] = fcmToken ?? '';

      request.fields['current_country'] = currentCountry;
      request.fields['current_city'] = currentCity;

      if (_idImage != null)
        request.files.add(
          await http.MultipartFile.fromPath('id_image', _idImage!.path),
        );
      if (_selfieImage != null)
        request.files.add(
          await http.MultipartFile.fromPath('selfie_image', _selfieImage!.path),
        );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var decodedData = jsonDecode(responseData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isResubmit
                  ? "Application updated! Pending Admin review."
                  : "Account Created Successfully! Pending Admin Approval.",
            ),
          ),
        );
        context.go('/');
      } else {
        String errorMsg = decodedData['message'] ?? "Failed to save account.";

        if (errorMsg.contains("already registered") && !isResubmit) {
          setState(() {
            _showMoreInfo = false;
            _isLocked = false;
            _hasEmailError = true;
          });
          Future.delayed(
            const Duration(milliseconds: 100),
            () => _emailFocusNode.requestFocus(),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isResubmit = widget.rejectReason != null;

    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isResubmit ? "Fix Application 🛠️" : "Hello Zamil!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isResubmit ? Colors.red : primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isResubmit
                    ? "Please update the highlighted sections below."
                    : "Please fill all info to create your account",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              _buildHeader("Your profile"),
              _buildTextField(
                "Full Name",
                Icons.person,
                false,
                controller: _nameController,
                enabled: !_isLocked,
              ),
              _buildTextField(
                "Email Address",
                Icons.email,
                false,
                controller: _emailController,
                enabled: isResubmit ? false : !_isLocked,
                focusNode: _emailFocusNode,
                hasError: _hasEmailError,
              ),
              _buildTextField(
                "Phone Number",
                Icons.phone,
                false,
                controller: _phoneController,
                keyboard: TextInputType.number,
                enabled: !_isLocked,
              ),
              _buildTextField(
                "Password",
                Icons.lock,
                true,
                controller: _passController,
                enabled: isResubmit ? false : !_isLocked,
              ),
              _buildTextField(
                "Confirm Password",
                Icons.lock_outline,
                true,
                controller: _confirmPassController,
                isConfirm: true,
                enabled: isResubmit ? false : !_isLocked,
              ),

              const SizedBox(height: 20),

              if (!_showMoreInfo)
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate())
                        setState(() {
                          _showMoreInfo = true;
                          _isLocked = true;
                        });
                    },
                    child: const Text(
                      "More Information →",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else if (!isResubmit)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _showMoreInfo = false;
                      _isLocked = false;
                    }),
                    icon: Icon(Icons.edit, color: primaryGreen),
                    label: Text(
                      "Edit Personal Info",
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

              if (_showMoreInfo) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(thickness: 1),
                ),
                _buildHeader("Identity & Location"),

                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: _buildTextField(
                      "Date of Birth",
                      Icons.calendar_today,
                      false,
                      controller: _dateController,
                      hint: "Select your birthday",
                    ),
                  ),
                ),
                _buildDropdown(),
                _buildTextField(
                  "Full Address Details",
                  Icons.home,
                  false,
                  controller: _addressController,
                  hint: "Example: Beirut, Hamra, Main St, Bldg 5",
                ),

                const SizedBox(height: 20),
                _buildUploadTile(
                  "Take ID / Passport Photo",
                  Icons.camera_alt,
                  'id',
                  _idImage,
                  hasError: _idError,
                ),
                _buildUploadTile(
                  "Take a Selfie",
                  Icons.face_retouching_natural,
                  'selfie',
                  _selfieImage,
                  hasError: _selfieError,
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isResubmit ? Colors.red : primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              if (!isResubmit &&
                                  (_idImage == null || _selfieImage == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please take your ID and Selfie photos.",
                                    ),
                                  ),
                                );
                                return;
                              }
                              _submitData();
                            }
                          },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isResubmit ? "RESUBMIT CHANGES" : "FINISH & CREATE",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryGreen.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    bool isPassword, {
    TextEditingController? controller,
    bool isConfirm = false,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool enabled = true,
    FocusNode? focusNode,
    bool hasError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        keyboardType: keyboard,
        enabled: enabled,
        onChanged: (val) {
          if (hasError && label == "Email Address")
            setState(() => _hasEmailError = false);
        },
        inputFormatters: label == "Phone Number"
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: label == "Phone Number" ? "70 123 456" : hint,
          prefixIcon: Icon(icon, color: hasError ? Colors.red : primaryGreen),
          prefixText: label == "Phone Number" ? "+961 " : null,
          prefixStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: hasError
                ? const BorderSide(color: Colors.red, width: 2)
                : const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: hasError
                ? const BorderSide(color: Colors.red, width: 2)
                : BorderSide(color: primaryGreen, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "This field is required";
          if (label == "Email Address" && !value.contains('@'))
            return "Invalid email (must contain @)";
          if (label == "Phone Number" && value.length < 7)
            return "Number is too short";
          if (isConfirm && value != _passController.text)
            return "Passwords do not match!";
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "Governorate",
          prefixIcon: Icon(Icons.location_city, color: primaryGreen),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
        ),
        value: _selectedGovernorate,
        items: _governorates
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (val) => setState(() => _selectedGovernorate = val),
        validator: (value) =>
            value == null ? "Please select a governorate" : null,
      ),
    );
  }

  Widget _buildUploadTile(
    String title,
    IconData icon,
    String type,
    File? imageFile, {
    bool hasError = false,
  }) {
    bool isUploaded = imageFile != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasError
            ? Colors.red.withOpacity(0.05)
            : (isUploaded
                  ? primaryGreen.withOpacity(0.1)
                  : primaryGreen.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Colors.red
              : (isUploaded ? primaryGreen : primaryGreen.withOpacity(0.2)),
          width: hasError ? 2.0 : 1.0,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isUploaded ? Icons.check_circle : icon,
          color: hasError ? Colors.red : primaryGreen,
        ),
        title: Text(
          isUploaded ? "Uploaded: $title" : title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: hasError ? FontWeight.bold : FontWeight.w500,
            color: hasError
                ? Colors.red
                : (isUploaded ? primaryGreen : Colors.black87),
          ),
        ),
        trailing: isUploaded
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  imageFile,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                Icons.camera_alt,
                color: hasError ? Colors.red : Colors.grey,
              ),
        onTap: () => _pickImage(type),
      ),
    );
  }
}
