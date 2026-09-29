import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace return MaterialApp( with return Consumer<ThemeProvider>(builder: (context, themeProvider, child) { return MaterialApp(
content = content.replace('return MaterialApp(', '''return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(''')

# We need to find the end of MaterialApp and add });
# Since MaterialApp is the only thing returned in build, we can just replace the end of the file.
# Wait, it ends with:
#       },
#     );
#   }
# }

content = content.replace('''        return null;
      },
    );
  }
}''', '''        return null;
      },
    );
      },
    );
  }
}''')

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Wrapped MaterialApp with Consumer")
