# Modern Form UI Components Guide

This guide shows you how to use the modern form UI components throughout your DuitKita app.

## Components Available

### 1. ModernStepper
Multi-step progress indicator for forms.

```dart
import 'package:duitkita/widgets/modern_stepper.dart';

ModernStepper(
  steps: const ['Step 1', 'Step 2', 'Step 3'],
  currentStep: 0, // 0-based index
  // Optional: customize colors (defaults to app theme)
  activeColor: AppTheme.primary,
  inactiveColor: Colors.grey,
)
```

### 2. ModernTextField
Clean text field with label and light background.

```dart
import 'package:duitkita/widgets/modern_text_field.dart';

ModernTextField(
  controller: _nameController,
  label: 'Full Name',
  hintText: 'Enter your name',
  keyboardType: TextInputType.text,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Name is required';
    return null;
  },
  // Optional: customize colors (defaults to cardBg)
  backgroundColor: AppTheme.cardBg,
  borderColor: AppTheme.cardBg,
)
```

### 3. ModernChipSelector
Pill-shaped option selector.

```dart
String? _selectedOption;

ModernChipSelector(
  options: const ['Option 1', 'Option 2', 'Option 3'],
  selectedOption: _selectedOption,
  onSelected: (option) {
    setState(() {
      _selectedOption = option;
    });
  },
  // Optional: customize colors (defaults to primary/cardBg)
  selectedColor: AppTheme.primary,
  unselectedColor: AppTheme.cardBg,
)
```

### 4. ModernToggleButtons
Segmented control / toggle buttons.

```dart
String? _selectedType;

ModernToggleButtons(
  options: const ['Type A', 'Type B'],
  selectedOption: _selectedType,
  onSelected: (type) {
    setState(() {
      _selectedType = type;
    });
  },
  // Optional: customize colors
  selectedColor: AppTheme.primary,
  unselectedColor: AppTheme.cardBg,
)
```

### 5. ModernUploadButton
Upload button with icon and label.

```dart
ModernUploadButton(
  icon: Icons.camera_alt_outlined,
  label: 'Camera',
  onTap: () => _pickImage(ImageSource.camera),
  // Optional: customize color (defaults to primary)
  color: AppTheme.primary,
)
```

## Example: Create Your Own Multi-Step Form

```dart
import 'package:flutter/material.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/widgets/modern_stepper.dart';
import 'package:duitkita/widgets/modern_text_field.dart';

class MyCustomFormScreen extends StatefulWidget {
  const MyCustomFormScreen({Key? key}) : super(key: key);

  @override
  State<MyCustomFormScreen> createState() => _MyCustomFormScreenState();
}

class _MyCustomFormScreenState extends State<MyCustomFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_currentStep < 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _submitForm() {
    // Submit your form data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Form submitted!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('My Form'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Stepper
          Container(
            color: Colors.white,
            child: ModernStepper(
              steps: const ['Personal Info', 'Contact Info'],
              currentStep: _currentStep,
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),

          // Next Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: AppTheme.cardShadow,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep < 1 ? 'Next' : 'Submit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ModernTextField(
              controller: _nameController,
              label: 'Full Name',
              hintText: 'Enter your name',
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Name is required';
                return null;
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ModernTextField(
              controller: _emailController,
              label: 'Email',
              hintText: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!value!.contains('@')) return 'Invalid email';
                return null;
              },
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}
```

## Color Customization

All components use your app's theme colors by default:
- **Primary Color**: Indigo (#283593) - Used for selected states
- **Card Background**: Light blue (#F8F9FE) - Used for input fields
- **Text Colors**: Defined in AppTheme

You can override colors for any component by passing custom colors:

```dart
ModernTextField(
  // ...
  backgroundColor: Colors.green.shade50,
  borderColor: Colors.green.shade100,
)

ModernChipSelector(
  // ...
  selectedColor: AppTheme.success,
  unselectedColor: AppTheme.cardBg,
)
```

## Where to Use These Components

### ✅ Perfect for:
- User onboarding flows
- Profile completion forms
- Payment verification
- KYC/identity verification
- Multi-step checkouts
- Settings wizards
- Account setup

### 📍 Use in your app:
- ✅ Already implemented: **Settings → KYC Verification**
- Add to: Group creation wizard
- Add to: Payment method setup
- Add to: Member invitation flow
- Add to: Profile completion
- Add to: Bank account verification

## Tips

1. **Keep steps to 3-4 max** - Too many steps can overwhelm users
2. **Use validation** - Always validate before allowing next step
3. **Save progress** - Consider auto-saving form data
4. **Clear labels** - Use descriptive step names
5. **Consistent spacing** - Use `SizedBox(height: 20-24)` between fields

## Need Help?

Check the example implementation in:
- `lib/screens/kyc_verification_screen.dart`
- `lib/widgets/modern_text_field.dart`
- `lib/widgets/modern_stepper.dart`
