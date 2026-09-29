import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if 'import \'package:url_launcher/url_launcher.dart\';' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:url_launcher/url_launcher.dart';")

search = '''              title: const Text(
                'Upgrade Plan','''

replace = '''            ListTile(
              leading: const Icon(Icons.language, color: AppColors.primary),
              title: const Text('Web Portal', style: TextStyle(color: AppColors.textDark)),
              onTap: () async {
                Navigator.pop(context);
                final url = Uri.parse('https://buildtrack.nurofin.com');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6CF7), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              title: const Text(
                'Upgrade Plan','''

if search in content:
    content = content.replace(search, replace)
    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched homescreen.dart")
else:
    print("Could not find insertion point!")
