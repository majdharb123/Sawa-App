import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAccCaptain extends StatefulWidget {
  final String? rejectReason;
  const CreateAccCaptain({super.key, this.rejectReason});

  @override
  State<CreateAccCaptain> createState() => _CreateAccCaptainState();
}

class _CreateAccCaptainState extends State<CreateAccCaptain> {
  final _formKey = GlobalKey<FormState>();
  bool _showMoreInfo = false;
  bool _isLocked = false;
  bool _isLoading = false;

  final FocusNode _emailFocusNode = FocusNode();
  bool _hasEmailError = false;

  bool _idError = false;
  bool _selfieError = false;
  bool _busPapersError = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _busNameController = TextEditingController();
  final TextEditingController _busTypeController = TextEditingController();

  final List<String> _availableFeatures = [
    'WiFi',
    'A/C',
    'USB',
    'TV',
    'Power',
    'Wheelchair',
    'Pet Friendly',
    'Luggage',
  ];
  List<String> _selectedFeatures = [];

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

  final Color primaryBlue = const Color(0xFF185FA5);
  final Color bgWhite = const Color(0xFFF9F9F9);

  File? _idImage;
  File? _selfieImage;
  File? _busPapersImage;
  File? _busInteriorImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    if (widget.rejectReason != null) {
      _showMoreInfo = true;
      _isLocked = false;

      if (widget.rejectReason!.contains("ID") ||
          widget.rejectReason!.contains("Expired")) {
        _idError = true;
      } else if (widget.rejectReason!.contains("Photo") ||
          widget.rejectReason!.contains("clear") ||
          widget.rejectReason!.contains("Selfie")) {
        _selfieError = true;
      } else if (widget.rejectReason!.contains("Papers") ||
          widget.rejectReason!.contains("criteria") ||
          widget.rejectReason!.contains("Bus")) {
        _busPapersError = true;
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
      _nameController.text = prefs.getString('saved_cap_name') ?? '';
      _emailController.text = prefs.getString('saved_cap_email') ?? '';
      _phoneController.text = prefs.getString('saved_cap_phone') ?? '';
      _dateController.text = prefs.getString('saved_cap_dob') ?? '';
      _addressController.text = prefs.getString('saved_cap_address') ?? '';
      _busNameController.text = prefs.getString('saved_cap_busName') ?? '';
      _busTypeController.text = prefs.getString('saved_cap_busType') ?? '';
      _selectedGovernorate = prefs.getString('saved_cap_gov');

      _passController.text = prefs.getString('saved_cap_pass') ?? '';
      _confirmPassController.text = prefs.getString('saved_cap_pass') ?? '';

      String? featsRaw = prefs.getString('saved_cap_feats');
      if (featsRaw != null) {
        _selectedFeatures = List<String>.from(jsonDecode(featsRaw));
      }

      String? idPath = prefs.getString('saved_cap_id_img');
      if (idPath != null && File(idPath).existsSync()) _idImage = File(idPath);

      String? selfiePath = prefs.getString('saved_cap_selfie_img');
      if (selfiePath != null && File(selfiePath).existsSync())
        _selfieImage = File(selfiePath);

      String? papersPath = prefs.getString('saved_cap_papers_img');
      if (papersPath != null && File(papersPath).existsSync())
        _busPapersImage = File(papersPath);

      String? interiorPath = prefs.getString('saved_cap_interior_img');
      if (interiorPath != null && File(interiorPath).existsSync())
        _busInteriorImage = File(interiorPath);
    });
  }

  Future<void> _saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_cap_name', _nameController.text);
    await prefs.setString('saved_cap_email', _emailController.text);
    await prefs.setString('saved_cap_phone', _phoneController.text);
    await prefs.setString('saved_cap_pass', _passController.text);
    await prefs.setString('saved_cap_dob', _dateController.text);
    await prefs.setString('saved_cap_address', _addressController.text);
    await prefs.setString('saved_cap_busName', _busNameController.text);
    await prefs.setString('saved_cap_busType', _busTypeController.text);

    if (_selectedGovernorate != null)
      await prefs.setString('saved_cap_gov', _selectedGovernorate!);
    await prefs.setString('saved_cap_feats', jsonEncode(_selectedFeatures));

    if (_idImage != null)
      await prefs.setString('saved_cap_id_img', _idImage!.path);
    if (_selfieImage != null)
      await prefs.setString('saved_cap_selfie_img', _selfieImage!.path);
    if (_busPapersImage != null)
      await prefs.setString('saved_cap_papers_img', _busPapersImage!.path);
    if (_busInteriorImage != null)
      await prefs.setString('saved_cap_interior_img', _busInteriorImage!.path);
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
          if (type == 'bus_papers') {
            _busPapersImage = File(pickedFile.path);
            _busPapersError = false;
          }
          if (type == 'bus_interior') _busInteriorImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open camera.')));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: primaryBlue)),
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
          ? "http://10.242.103.201:5000/api/auth/captain/resubmit"
          : "http://10.242.103.201:5000/api/auth/captain/register";

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
      request.fields['bus_name'] = _busNameController.text;
      request.fields['bus_type'] = _busTypeController.text;
      request.fields['features'] = jsonEncode(_selectedFeatures);
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
      if (_busPapersImage != null)
        request.files.add(
          await http.MultipartFile.fromPath(
            'bus_papers_image',
            _busPapersImage!.path,
          ),
        );
      if (_busInteriorImage != null)
        request.files.add(
          await http.MultipartFile.fromPath(
            'bus_interior_image',
            _busInteriorImage!.path,
          ),
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
                  : "Application sent! Pending Admin Approval.",
            ),
          ),
        );
        context.go('/');
      } else {
        String errorMsg = decodedData['message'] ?? "Operation failed.";
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
                isResubmit ? "Fix Application 🛠️" : "Hello Captain!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isResubmit ? Colors.red : primaryBlue,
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
                      backgroundColor: primaryBlue,
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
                    icon: Icon(Icons.edit, color: primaryBlue),
                    label: Text(
                      "Edit Personal Info",
                      style: TextStyle(
                        color: primaryBlue,
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
                _buildHeader("Bus & Documents"),
                _buildTextField(
                  "Bus Name",
                  Icons.directions_bus,
                  false,
                  controller: _busNameController,
                  hint: "e.g. Mercedes Sprinter",
                ),
                _buildTextField(
                  "Bus Type / Model",
                  Icons.model_training,
                  false,
                  controller: _busTypeController,
                  hint: "e.g. 2018 Model / 24 Seats",
                ),

                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Bus Features (Optional)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: _availableFeatures.map((feature) {
                    bool isSelected = _selectedFeatures.contains(feature);
                    return FilterChip(
                      label: Text(
                        feature,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.blueGrey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      showCheckmark: false,
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? primaryBlue
                              : Colors.grey.shade300,
                        ),
                      ),
                      onSelected: (bool selected) => setState(() {
                        selected
                            ? _selectedFeatures.add(feature)
                            : _selectedFeatures.remove(feature);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

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
                  "Full Address",
                  Icons.home,
                  false,
                  controller: _addressController,
                  hint: "Street, Building, Floor...",
                ),

                const SizedBox(height: 20),
                _buildUploadTile(
                  "Take ID Photo",
                  Icons.badge,
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
                _buildUploadTile(
                  "Take Bus Papers Photo",
                  Icons.description,
                  'bus_papers',
                  _busPapersImage,
                  hasError: _busPapersError,
                ),
                _buildUploadTile(
                  "Take Bus Interior Photo",
                  Icons.airline_seat_recline_normal,
                  'bus_interior',
                  _busInteriorImage,
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isResubmit ? Colors.red : primaryBlue,
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
                                  (_idImage == null ||
                                      _selfieImage == null ||
                                      _busPapersImage == null ||
                                      _busInteriorImage == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please upload all required photos.",
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
                            isResubmit ? "RESUBMIT CHANGES" : "FINISH & APPLY",
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
          color: primaryBlue.withOpacity(0.9),
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
          prefixIcon: Icon(icon, color: hasError ? Colors.red : primaryBlue),
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
                : BorderSide(color: primaryBlue, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "This field is required";
          if (label == "Email Address" && !value.contains('@'))
            return "Invalid email";
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
          prefixIcon: Icon(Icons.location_city, color: primaryBlue),
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
                  ? primaryBlue.withOpacity(0.1)
                  : primaryBlue.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? Colors.red
              : (isUploaded ? primaryBlue : primaryBlue.withOpacity(0.2)),
          width: hasError ? 2.0 : 1.0,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isUploaded ? Icons.check_circle : icon,
          color: hasError ? Colors.red : primaryBlue,
        ),
        title: Text(
          isUploaded ? "Ready: $title" : title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: hasError ? FontWeight.bold : FontWeight.w500,
            color: hasError
                ? Colors.red
                : (isUploaded ? primaryBlue : Colors.black87),
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
