import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for flutter_colorpicker
import_stmt = "import 'package:flutter_colorpicker/flutter_colorpicker.dart';\n"
if 'flutter_colorpicker' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_stmt)

# Update _ThemePicker build method
# We want to replace the Wrap with a button that opens a dialog, or just inline the ColorPicker.
# Inline ColorPicker is probably best if it fits. But wait, ColorPicker can be tall. A dialog is standard.

picker_code = '''                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: themeProvider.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.textDark, width: 2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              Color tempColor = themeProvider.primaryColor;
                              return AlertDialog(
                                title: const Text('Pick a color'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: tempColor,
                                    onColorChanged: (color) {
                                      tempColor = color;
                                    },
                                    pickerAreaHeightPercent: 0.8,
                                    enableAlpha: false,
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('Apply'),
                                    onPressed: () {
                                      themeProvider.setTheme(tempColor);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Choose Custom Color'),
                      ),
                    ],
                  ),
                ),'''

# Find the Wrap block and replace it
# It looks like:
#                Padding(
#                  padding: const EdgeInsets.all(16.0),
#                  child: Wrap(
#                    spacing: 12,
# ...
#                  ),
#                ),

content = re.sub(r'Padding\(\s*padding: const EdgeInsets.all\(16\.0\),\s*child: Wrap\(.*?\}\)\.toList\(\),\s*\),\s*\),', picker_code, content, flags=re.DOTALL)

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/profile/profile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated _ThemePicker to use ColorPicker dialog")
